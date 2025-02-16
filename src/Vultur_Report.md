# Vultur Android Malware

## Introduction

Vultur is an Android banking trojan that emerged in March 2021, distinguishing itself by utilizing screen recording and keylogging to harvest user credentials. Unlike traditional banking malware that employs overlay attacks, Vultur provides attackers with real-time visibility into the victim's device activities.

## Origin and Attribution

Vultur is believed to be associated with the threat actor group behind the Brunhilda dropper framework. This framework has been used to distribute various malware, including Alien and Vultur, through malicious applications hosted on the Google Play Store.

Analysis of both the dropper (Brunhilda) and the subsequent Vultur payloads indicates they are developed and maintained by the same threat actor group.

Their investment in proprietary malware—not simply renting third-party kits—suggests a motivated, organized group with specific targets in the financial sector. The close mimicry of legitimate app interfaces (e.g., the McAfee Security app) further underscores the sophistication of their social engineering tactics.

## Infection Methods

Vultur is primarily distributed via trojanized applications that pose as legitimate utilities, such as fitness trackers or authentication tools. These malicious apps often find their way onto official platforms like the Google Play Store, increasing their reach. Once installed, the app prompts the user to grant Accessibility Service permissions, which are then exploited to facilitate the malware's operations.

### Infection Chain and Dropper Mechanism

Vultur’s infection chain is a multi-step process:

1. **Social Engineering:**  
   Victims receive an SMS alert about an unauthorized transaction, prompting them to call a provided phone number. During the call, they are sent a follow-up SMS with a link to download a supposedly legitimate security app.

2. **Dropper Delivery:**  
   The app—masquerading as the official McAfee Security app—acts as a dropper (Brunhilda) that registers with a command-and-control (C2) server and subsequently decrypts and installs up to three malicious payloads. These payloads work in concert to:
   - Request Accessibility Service privileges.
   - Set up remote control functionalities.
   - Initiate screen recording and keylogging operations.

3. **Modular Payload Execution:**  
   The dropper installs multiple layers of malware:
   - **Payload #1:** Establishes initial registration and gains essential permissions.
   - **Payload #2:** Integrates native libraries for advanced functions (e.g., screen recording using VNC).
   - **Payload #3:** Contains the core backdoor logic and interfaces with the C2 server via both HTTPS and Firebase Cloud Messaging (FCM).

This multi-layered design complicates analysis by fragmenting malicious functionality across separate components.  
 [oai_citation_attribution:1‡threatfabric.com](https://www.threatfabric.com/blogs/vultur-v-for-vnc)


## Payload Activities

Upon successful installation and activation, Vultur performs several malicious activities:

- **Screen Recording via VNC**: The malware uses a VNC (Virtual Network Computing) implementation to capture the device's screen in real-time, allowing attackers to observe user interactions with banking and financial applications.
- **Keylogging**: By abusing Accessibility Services, Vultur logs keystrokes to capture sensitive information such as usernames and passwords.
- **Preventing Uninstallation**: The malware interferes with user attempts to uninstall it by automatically navigating away from the application settings page whenever the user tries to access it.

These capabilities enable attackers to harvest personally identifiable information (PII), including banking credentials and access tokens, facilitating unauthorized access to victims' financial accounts.

## Technical Analysis

Vultur's architecture is modular, often involving multiple stages to achieve full infection:

1. **Dropper Application**: The initial app, disguised as a legitimate utility, contains an encrypted payload within its assets.
2. **Payload Decryption and Execution**: Upon execution, the dropper decrypts and installs the malicious payload, which then requests Accessibility Service permissions from the user.
3. **Establishing Persistence**: With the granted permissions, the malware hides its icon and begins its malicious activities, such as screen recording and keylogging.

### Screen Recording and Remote Control via VNC

Vultur leverages native code to initiate a VNC service that streams the device’s screen. The following pseudocode illustrates how the malware might wrap a native function call:
 
```java
public static void startVnc(FileDescriptor fd, VncSessionConfig config, Runnable callback,
                            int arg13, int arg14, int arg15) {
    // Retrieve the VNC password and port from the configuration
    String password = config.getPw();
    int port = config.getVncPort();
    
    // Log the initiation of the VNC service
    System.out.println("VNC: Starting VNC service...");
    
    // Call the native method to start the VNC server
    int exitCode = nativeStartVnc(fd, arg13, arg14, arg15, password, port);
    
    // Log the exit code from the native function
    System.out.println("VNC: Exit code = " + exitCode);
    
    // Invoke the callback once the service is started
    callback.run();
}
```

### Remote VNC control

The malware employs native libraries (e.g., `libavnc.so`) to handle VNC functionalities, interfacing with the main application through wrapper classes. This approach complicates analysis and detection efforts.

For instance, the following code snippet demonstrates how Vultur starts its VNC server:

```java
public class VNCService extends Service {
    static {
        System.loadLibrary("avnc");
    }

    private native void nstart_vnc();

    @Override
    public void onCreate() {
        super.onCreate();
        new Thread(() -> nstart_vnc()).start();
    }
}
```

In this snippet, the `nstart_vnc` native method is invoked within a new thread to initiate the VNC server, enabling screen recording capabilities.

### Keylogging via Accessibility Services

Vultur abuses Android’s Accessibility Services to monitor and record keystrokes from targeted applications. A simplified version of the keylogging function resembles the following:

```java
public static void keylog(AccessibilityEvent event) {
    // Determine the source package; default to "Unknown" if null
    String pkg = event.getPackageName() == null ? "Unknown" : event.getPackageName().toString();
    // Check if this package is already being monitored
    if (KeyloggerManager.isPackageKeylogged(pkg)) {
        return;
    }
    try {
        String data = event.getText().toString();
        if (!data.isEmpty()) {
            // Append captured data to the keylogger buffer
            KeyloggerManager.appendLog(pkg + " | " + data);
        }
    } catch (Exception e) {
        // Exception handling (logging, etc.)
    }
}
```

## Detection and Analysis

Detecting Vultur in the wild requires a multi-pronged approach:

- Static Analysis:
  - Examine APK/DEX files for obfuscated strings, unusual native libraries (e.g., libavnc.so), and modified AndroidManifest.xml entries (such as masquerading as legitimate apps).
  - Apply YARA rules (as shown above) to identify unique byte patterns in the dropper.

- Dynamic Analysis:
  - Monitor for anomalous behaviors such as unexpected SMS handling, overlay window creation via the SYSTEM_ALERT_WINDOW permission, and uncharacteristic accessibility events.
  - Observe network traffic for encrypted C2 communications that utilize AES and Base64 encoding.

- Behavioral Indicators:
  - Abnormal power management usage (e.g., excessive wake locks) and unauthorized installation requests.
  - Unexpected file operations, including hidden file deletions after payload decryption.

Reverse engineers should focus on extracting native libraries and debugging the decryption routines to uncover the dynamic key generation mechanisms employed by the malware.

Detecting and analyzing Vultur requires a comprehensive approach:

- **Behavioral Analysis**: Monitoring for unusual behaviors, such as unauthorized screen recording or excessive use of Accessibility Services, can indicate the presence of Vultur.
- **Static Analysis**: Examining the application's code for references to suspicious native libraries (e.g., `libavnc.so`) or obfuscated payloads can aid in identification.
- **Network Traffic Monitoring**: Observing network communications for connections to known command-and-control (C2) servers associated with Vultur can provide further evidence of infection.



Reverse engineers should pay particular attention to the decryption routines used to unpack the payload, as well as the methods employed to abuse Accessibility Services for keylogging and preventing uninstallation.

### Decryption and Obfuscation Techniques

A key anti-analysis feature of Vultur is its use of native code for decrypting embedded payloads. For instance, the dropper extracts a substring from an embedded Base64 string to derive an AES key (typically using AES/ECB/PKCS5Padding) which is then used to decrypt a hidden APK stored in the assets folder. This obfuscation—coupled with spreading malicious code across multiple payloads—makes static analysis and automated detection significantly more challenging. Analysts have successfully developed YARA rules targeting unique hex patterns within the dropper’s binary to flag such samples:

```yara
rule brunhilda_dropper {
    meta:
        description = "Detects Brunhilda dropper samples linked to Vultur"
    strings:
        $zip_head = "PK" at 0
        $manifest = "AndroidManifest.xml"
        $hex_pattern = {63 59 5C 28 4B 5F}
    condition:
        $zip_head at 0 and $manifest and 2 of ($hex_pattern)
}
```

## Conclusion

Vultur represents a significant evolution in Android banking malware, leveraging screen recording and keylogging to effectively harvest sensitive user information. Its association with the Brunhilda dropper framework and distribution through seemingly legitimate applications underscore the importance of vigilant app vetting and user awareness. Advanced detection and analysis techniques are essential to identify and mitigate the threats posed by Vultur.

### Mitigation

- **User Awareness**: Only download apps from official sources (e.g., Google Play Store) and be wary of SMS prompts or phone calls urging immediate action.
- **Device Security**: Ensure that Google Play Protect is enabled, maintain up-to-date OS and app versions, and consider using reputable mobile security solutions.
- **For Security Teams**: Implement YARA rules and behavioral monitoring to detect anomalous activities associated with Vultur, and perform regular static and dynamic analyses of suspicious APKs.

### Indicators of Compromise (IOCs)

- Sample Hashes:
  - Downloader APK (SHA-256): 00a733c78f1b4d4f54cf06a0ea8cc33604512d6032ef4ef9114c89c700bfafcf
  - Vultur Malware APK (SHA-256): 1b290349c8ada90705f7e1f6aee3cc2c8fecd02163c490af37cf59a29ed24a23

- C2 Domains:
  - privacyandroidapp.club
  - letsbeapornostar.club

## References

- ThreatFabric. "Vultur, with a V for VNC." [https://www.threatfabric.com/blogs/vultur-v-for-vnc](https://www.threatfabric.com/blogs/vultur-v-for-vnc)
- NCC Group. "Android Malware Vultur Expands Its Wingspan." [https://www.nccgroup.com/us/research-blog/android-malware-vultur-expands-its-wingspan/](https://www.nccgroup.com/us/research-blog/android-malware-vultur-expands-its-wingspan/)
- Cyble. "Vultur Banking Trojan Spreading Via Fake Google Play Store App." [https://cyble.com/blog/vultur-banking-trojan-spreading-via-fake-google-play-store-app/](https://cyble.com/blog/vultur-banking-trojan-spreading-via-fake-google-play-store-app/)

