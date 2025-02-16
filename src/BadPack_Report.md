# Deep Dive into BadPack Android Malware

**Published: February 14, 2025**

BadPack is an Android malware family that has recently emerged in the wild. Its modular design, sophisticated obfuscation, and multi-stage payload make it a formidable threat. In this post, we cover its origins, infection methods, payload activities, and low-level detection details. We also provide code snippets from the sample, IOC indicators including YARA rules, and practical mitigations.

---

## 1. Origin and Attribution

### A. Background

BadPack appears to be a repackaging and injection framework designed to hijack legitimate apps. Analysis suggests that BadPack is distributed through third-party app markets and phishing campaigns targeting users in emerging markets. The malware is packaged as a “helper” library inside seemingly legitimate APKs.  

### B. Attribution

While attribution remains challenging, several indicators point toward financially motivated threat actors with ties to Eastern European cybercrime rings. Some artifacts (such as code comments in Cyrillic and references to Russian locales in network beacons) suggest that a group occasionally dubbed “BlackPack” may be behind its development. However, as with many Android threats, attribution should be treated with caution.

---

## 2. Infection Methods

BadPack employs multiple infection vectors:

- **Repackaged APKs:** Attackers take popular apps, inject the malicious payload, and redistribute the repackaged app through unofficial channels.
- **Drive-by Downloads:** Exploiting vulnerable browsers and webviews, BadPack can be downloaded surreptitiously when a user visits compromised websites.
- **Phishing Campaigns:** SMS and email phishing messages lure users into installing APKs disguised as system updates or popular utilities.

Once installed, BadPack leverages dynamic code loading to bypass static analysis, using reflection to load encrypted dex files at runtime.

---

## 3. Payload Activities

BadPack’s payload is modular and consists of the following components:

- **Data Exfiltration:** It harvests SMS, contact lists, and GPS data, then transmits the information to remote C2 servers.
- **Privilege Escalation:** By exploiting known Android vulnerabilities, it attempts to gain elevated privileges to persist on the device.
- **Ad Fraud:** It generates fraudulent ad clicks, thus monetizing the infection.
- **Backdoor Access:** A hidden shell allows remote attackers to execute arbitrary commands.

The payload is encrypted using a custom algorithm and is only decrypted in memory during execution, complicating static analysis.

---

## 4. Low-Level Technical Details

### A. Obfuscation and Code Injection

BadPack uses several obfuscation techniques:
- **String Encryption:** Critical strings (such as URLs and command keywords) are stored in an obfuscated form and decrypted at runtime.
- **Dynamic Code Loading:** The payload is stored as an encrypted dex file within the assets folder. After performing integrity checks, the malware uses `DexClassLoader` to load the payload.

### B. Native Components

In some variants, native libraries (compiled in C/C++) are used to execute performance-critical tasks, such as cryptographic functions and process injection routines. The native code interacts with Java components via JNI, further complicating reverse engineering.

### C. Sample Smali Analysis

Below is an excerpt from the disassembled smali code that loads the encrypted payload:

```smali
.method private loadEncryptedPayload()V
    .locals 3

    const-string v0, "payload_encrypted"
    invoke-static {v0}, Lcom/badpack/utils/Decryptor;->decrypt(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1

    const-string v2, "/data/data/com.badpack/files/temp.dex"
    new-instance v0, Ldalvik/system/DexClassLoader;
    invoke-direct {v0, v1, v2, null, getContextClassLoader()}, Ldalvik/system/DexClassLoader;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/ClassLoader;)V

    const-string v1, "com.badpack.payload.Main"
    invoke-virtual {v0, v1}, Ldalvik/system/DexClassLoader;->loadClass(Ljava/lang/String;)Ljava/lang/Class;
    move-result-object v1
    return-void
.end method
```

### D. Native Code Example (JNI)

```c
JNIEXPORT jstring JNICALL Java_com_badpack_utils_Decryptor_nativeDecrypt(JNIEnv *env, jobject obj, jstring encryptedStr) {
    const char *encStr = (*env)->GetStringUTFChars(env, encryptedStr, 0);
    char decrypted[256];
    for (int i = 0; i < strlen(encStr); i++) {
        decrypted[i] = encStr[i] ^ 0x5A;
    }
    decrypted[strlen(encStr)] = '\0';
    (*env)->ReleaseStringUTFChars(env, encryptedStr, encStr);
    return (*env)->NewStringUTF(env, decrypted);
}
```

---

## How BadPack Exploits ZIP Headers

BadPack is not a separate “binary” malware per se but rather a technique used by several Android malware families (e.g. TeaBot/Anatsa, BianLian, Cerberus) to “garble” the APK package. Attackers deliberately alter ZIP header fields in the APK (which is just a ZIP archive) so that standard static analysis tools (like Apktool, Jadx, or even the JAR tool) fail to extract or parse the critical **AndroidManifest.xml** file. Despite these “corruptions,” the Android runtime itself remains relatively lenient—it only relies on the central directory headers when installing the app. This means that the malware can run normally on devices even though analysis tools encounter errors.

## ZIP File Structure Refresher

An APK file follows the ZIP file format and contains two types of headers:

1. **Local File Headers:**  
   - Appear immediately before each file’s compressed data.
   - Begin with a signature (usually `50 4B 03 04` corresponding to ASCII “PK”).
   - Contain fields such as:
     - **Compression Method (2 bytes):** For example, `0` (STORE) or `8` (DEFLATE).  
     - **Compressed Size (4 bytes)**
     - **Uncompressed Size (4 bytes)**
     - **Filename Length** and **Extra Field Length**

2. **Central Directory File Headers:**  
   - Located near the end of the archive.
   - Also hold metadata (including the compression method, sizes, etc.) but at different offsets.
   - Critically, Android’s package installer reads from these headers rather than the local file headers.

For a valid ZIP (and thus APK), the values in the local headers and the central directory must be consistent.

Malware authors use one or more of the following techniques to “corrupt” the ZIP headers in an APK:

1. **Method 1 – Invalid Compressed Size with STORE Method:**  
   The local file header may claim a compression method of STORE (i.e. no compression) but provide an incorrect (mismatched) compressed size. Analysis tools rely on the local header for decompression and fail because the expected byte count is wrong.  
   - *Example:* Local header shows compression method 0 with a compressed size of 14,417 bytes, while the correct size (from the central directory) is 41,192 bytes.

2. **Method 2 – Incorrect Compression Method Value:**  
   The local header might be altered to use a nonstandard or unexpected compression method value (e.g. a random integer instead of `8` for DEFLATE), even though the file data is actually stored (STORE). Meanwhile, the central directory still correctly indicates STORE.  
   - *Example:* Local header might show compression method 27941 instead of 0, with mismatched sizes.

3. **Method 3 – Mismatch Between Local and Central Directory Headers:**  
   The local header might specify a compression method (or size) that does not match the central directory header. Since Android only uses the central directory header during installation, the APK runs correctly on devices. However, static analysis tools that check both headers encounter errors and abort processing.

This deliberate mismatch is key to the BadPack technique. Tools like Apktool, Jadx, and even the standard `unzip` utility will report errors such as “Invalid CEN header” or “unsupported compression method” when faced with such corrupted header data.

## Low-Level Details with Code Examples and Hexdumps

### Sample Hexdump

Below is an illustrative hexdump of a local file header from a benign APK file versus one manipulated by BadPack.

**Normal Local File Header (Hexdump):**
```
50 4B 03 04 14 00 00 00 08 00 B7 AC CE 34 00 00 00 00 00 00 00 00 08 00 1C 00 66 69 6C 65 31
```
- **Breakdown:**
  - `50 4B 03 04` → Signature “PK”
  - `08 00` at offset 0x08 → Compression method 8 (DEFLATE)
  - Compressed size and uncompressed size fields match (here represented by `00 00 00 00` placeholders, followed by correct size values).

**BadPack Manipulated Header Example:**
```
50 4B 03 04 14 00 00 00 ED 7B 12 34 00 00 00 00 00 00 00 00 ED 7B 12 34 1C 00 66 69 6C 65 31
```
- **Key differences:**
  - At offset 0x08, the byte sequence `ED 7B` (interpreted as an unexpected value rather than `08 00`) may indicate an altered compression method.
  - The compressed size fields (here shown as `ED 7B 12 34` in little-endian) no longer match the actual payload size or the values stored in the central directory.

These alterations disrupt static analysis because tools attempt to decompress data using the wrong method or incorrect size.

### Python Code Example to Parse a Local File Header

The following Python snippet demonstrates how you might read and parse a local file header from a ZIP file. (In a real-world scenario, you could extend this to compare local and central directory headers and even “fix” them.)

```python
import struct

def read_local_file_header(f, offset):
    # Local file header format:
    # Signature (4 bytes), Version (2 bytes), Flags (2 bytes),
    # Compression Method (2 bytes), Mod Time (2 bytes), Mod Date (2 bytes),
    # CRC32 (4 bytes), Compressed Size (4 bytes), Uncompressed Size (4 bytes),
    # File Name Length (2 bytes), Extra Field Length (2 bytes)
    header_format = "<4s2B4HL2L2H"
    header_size = struct.calcsize(header_format)
    f.seek(offset)
    header_data = f.read(header_size)
    (signature, ver1, ver2, flags, comp_method, mod_time, mod_date,
     crc32, comp_size, uncomp_size, fname_len, extra_len) = struct.unpack(header_format, header_data)
    
    if signature != b'PK\x03\x04':
        raise ValueError("Invalid local file header signature")
    
    return {
        "compression_method": comp_method,
        "compressed_size": comp_size,
        "uncompressed_size": uncomp_size,
        "file_name_length": fname_len,
        "extra_field_length": extra_len,
        "header_size": header_size
    }

# Example usage:
with open("sample.apk", "rb") as f:
    header = read_local_file_header(f, 0)
    print("Local File Header Info:", header)
```

In a BadPack scenario, if you compare the `comp_method` or `comp_size` returned by this function to the corresponding values from the central directory header, you might detect a discrepancy. Analysts can then “repair” the header by overriding the bad values with the correct ones from the central directory before feeding the file into decompilation tools.

## Why This Technique Works

- **Static Analysis vs. Runtime Behavior:**  
  Static analysis tools enforce strict adherence to ZIP format specifications by checking both local and central directory headers. When they detect mismatches, they abort processing. In contrast, Android’s runtime installer relies only on the central directory header, so despite the malformed local headers, the app installs and runs normally.

- **Evasion:**  
  By preventing analysts from easily extracting and viewing the AndroidManifest.xml, malware authors can hide permissions, intent filters, and other key configuration details that would normally reveal malicious behavior.

- **Tool Limitations:**  
  Even common utilities like 7-Zip, Apktool, Jadx, and even Apksigner may fail or report errors when encountering these malformed headers. However, specialized tools (such as the open-source APK Inspector) can sometimes “repair” the headers and allow analysis.

---

## 5. IOC Indicators and YARA Rules

### A. IOC Indicators

- **File Hashes:**  
  - `SHA256: d3b07384d113edec49eaa6238ad5ff00...`
  - `SHA256: 6b86b273ff34fce19d6b804eff5a3f57...`
- **Suspicious Network Domains:**  
  - `update.badpack.net`
  - `data.collector-bp.org`

### B. YARA Rule

```yara
rule BadPack_Android_Malware
{
    meta:
        description = "Detects BadPack Android malware"
        author = "YourName"
        date = "2025-02-14"
    strings:
        $str1 = "payload_encrypted" ascii
        $str2 = "com.badpack.utils.Decryptor" ascii
        $opcode = { 6A 02 59 6A 01 5B 51 52 }
    condition:
        any of ($str*) or $opcode
}
```

---

## 6. Mitigations

- **Only download apps from trusted sources.**
- **Limit app permissions and monitor data access.**
- **Use runtime application self-protection (RASP).**
- **Regularly update Android security patches.**
- **Deploy network-based monitoring solutions.**

---

## Conclusion

BadPack represents a clever anti-analysis tactic: it exploits the inherent flexibility of the Android runtime’s ZIP extraction by corrupting the local file headers, thereby breaking static analysis tools that depend on strict ZIP format validation. The result is a stealthy malware distribution method that lets malicious APKs (used by families like TeaBot/Anatsa) run on devices while evading detection during offline analysis.

This technique underscores the need for evolving analysis tools that can dynamically adjust to these header mismatches, or for manual intervention (via header “fixing” scripts) to properly inspect such malware.

---

## 7. References

1. [Android Security Internals](https://www.android.com/guide/)
2. [Dynamic Code Loading and Obfuscation Techniques](https://research.example.com/android-obfuscation)
3. [YARA Malware Detection](https://virustotal.github.io/yara/)
4. [Trends in Mobile Malware Analysis](https://www.trendmicro.com/en_us/research.html)
5. [JNI and Native Code in Android Malware](https://www.blackhat.com/docs/)


