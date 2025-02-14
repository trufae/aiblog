# Deep Dive into SparkCat

## The OCR-Powered Android Malware

SparkCat is a sophisticated Android malware campaign—now also affecting iOS—that uses optical character recognition (OCR) techniques to steal sensitive cryptocurrency wallet recovery phrases. In this post, we explore its origins, infection methods, payload activities, and the technical details crucial for detection and analysis, tailored for reverse engineers.

---

## Overview and Origin

**SparkCat** was first identified by cybersecurity researchers in early 2024 and has since been found infiltrating both Google Play and Apple’s App Store. Initially, it emerged within seemingly legitimate apps—ranging from food delivery and AI-powered messaging platforms to crypto-related utilities—often hiding within third-party software development kits (SDKs) disguised as analytics modules. Its ability to bypass traditional store vetting procedures suggests either a deliberate supply chain compromise or collusion with malicious developers.

The malware has been active since March 2024, as evidenced by timestamps in configuration files hosted on GitLab repositories. Notably, artifacts in the iOS version (e.g., directory names such as “qiongwu” and “quiwengjing”) hint at a developer with Chinese language proficiency, though attribution remains inconclusive.

---

## Infection Methods

SparkCat leverages a multi-pronged infection strategy:

1. **Malicious SDK Integration:**  
   - **Android:** The malware is embedded as a Java-based component—often referred to as “Spark”—within trojanized apps. Once the app launches, the malicious SDK initializes in the overridden `onCreate` method of the application class, downloading a configuration file from a GitLab URL. This file is Base64-decoded and decrypted using AES-128 in CBC mode before the malware sets its command-and-control (C2) endpoints.  
   - **iOS:** A similar framework, obfuscated with tools like HikariLLVM, is integrated into apps under aliases such as “GZIP” or “googleappsdk.”  

2. **Permission Abuse & Triggered Execution:**  
   SparkCat requests seemingly benign permissions—such as access to the photo gallery—during legitimate user interactions (e.g., when initiating a support chat). Once granted, it scans stored images for text resembling crypto wallet recovery phrases (mnemonics).

3. **Distribution Channels:**  
   - **Official App Stores:** Infected apps have been distributed via Google Play and, notably, the Apple App Store—the first known instance of an OCR-based stealer on iOS.
   - **Third-Party Sources:** Telemetry indicates that additional infected samples are spread through unofficial channels.

---


## Payload Activities and Low-Level Technical Details

### OCR-Based Data Exfiltration

At its core, SparkCat exploits the Google ML Kit's OCR library to process images stored in the device’s gallery:

- **Dynamic OCR Model Loading:** Based on the device’s language settings, SparkCat downloads OCR models trained to recognize scripts in Latin, Chinese, Korean, and Japanese. This allows the malware to accurately extract recovery phrases across multiple languages.
- **Keyword Filtering:** Once text is extracted, it is filtered against a list of keywords (e.g., “Mnemonic,” “助记词,” “ニーモニック”) that are dynamically fetched from the C2 server. Only images matching these criteria are exfiltrated.
   [oai_citation_attribution:4‡securityaffairs.com](https://securityaffairs.com/173873/malware/sparkcat-campaign-target-crypto-wallets.html)

---

### Communication and Encryption

The exfiltrated data is sent to attacker-controlled servers using a multi-layered encryption process:

- **Dual Communication Channels:**
  - **HTTP-Based Channel:** SparkCat uses POST requests to communicate with an HTTP endpoint. Data is encrypted with AES-256 in CBC mode using hardcoded keys, and server responses are decrypted with AES-128 in CBC mode.
  - **Custom Rust-Based Protocol:** A native Rust library—rare in mobile malware—is employed to handle a secondary channel. This library obscures its functions through non-standard calling conventions and minimal symbol information, making static analysis challenging. Before sending data, the library:
    - Generates a 32-byte key for an AES-GCM-SIV cipher.
    - Compresses data using ZSTD.
    - Encrypts the compressed payload with the generated key.
    - Sends the AES key (RSA-encrypted using a hardcoded public key) alongside the payload over TCP.

  This multi-tiered approach not only hides the malicious traffic but also complicates reverse engineering efforts.
   [oai_citation_attribution:5‡kaspersky.com](https://www.kaspersky.com/about/press-releases/kaspersky-discovers-new-crypto-stealing-trojan-in-appstore-and-google-play)

---

## Payload Activities and Low-Level Technical Details

SparkCat employs several obfuscation techniques to hinder analysis:

- **Configuration File Decryption:** The initial configuration file is obfuscated—Base64-encoded and then decrypted via AES-128 in CBC mode.
- **XOR Decryption of Embedded Payloads:** Subsequent payloads stored in the app's assets are decrypted using a simple XOR cipher with a 16-byte key.
- **Dynamic Code Loading:** On Android, the decrypted payload is loaded in a separate thread using reflection, making static detection more difficult.

Additionally, SparkCat's filtering of OCR results involves multiple processing steps:
- **Processor Modules:** Classes such as `KeywordsProcessor`, `DictProcessor`, and `WordNumProcessor` filter recognized text based on parameters like minimum/maximum letter count and dictionary matches. These thresholds are configurable via JSON objects received from the C2.
   [oai_citation_attribution:6‡securelist.com](https://securelist.com/sparkcat-stealer-in-app-store-and-google-play/115385/)


### OCR-Based Data Exfiltration

At its core, SparkCat exploits the Google ML Kit's OCR library to process images stored in the device’s gallery:

- **Dynamic OCR Model Loading:** Based on the device’s language settings, SparkCat downloads OCR models trained to recognize scripts in Latin, Chinese, Korean, and Japanese. This allows the malware to accurately extract recovery phrases across multiple languages.  
- **Keyword Filtering:** Once text is extracted, it is filtered against a list of keywords (e.g., “Mnemonic,” “助记词,” “ニーモニック”) that are dynamically fetched from the C2 server. Only images matching these criteria are exfiltrated.

### Communication and Encryption

The exfiltrated data is sent to attacker-controlled servers using a multi-layered encryption process:
- **Dual Communication Channels:**  
  - **HTTP-Based Channel:** SparkCat uses POST requests to communicate with an HTTP endpoint. Data is encrypted with AES-256 in CBC mode using hardcoded keys, and server responses are decrypted with AES-128 in CBC mode.
  - **Custom Rust-Based Protocol:** A native Rust library—rare in mobile malware—is employed to handle a secondary channel. This library obscures its functions through non-standard calling conventions and minimal symbol information, making static analysis challenging. Before sending data, the library:
    - Generates a 32-byte key for an AES-GCM-SIV cipher.
    - Compresses data using ZSTD.
    - Encrypts the compressed payload with the generated key.
    - Sends the AES key (RSA-encrypted using a hardcoded public key) alongside the payload over TCP.

---

## Code Examples and Analysis

### 1. Configuration File Retrieval and Decryption

```java
String downloadConfig(String url) {
    String base64Config = httpGet(url);
    return decryptConfig(base64Config, "hardcodedAESKey", "fixedIV");
}

String decryptConfig(String base64Config, String key, String iv) {
    byte[] encodedBytes = Base64.decode(base64Config, Base64.DEFAULT);
    byte[] decryptedBytes = AES128CBCDecrypt(encodedBytes, key.getBytes(), iv.getBytes());
    return new String(decryptedBytes, StandardCharsets.UTF_8);
}
```

### 2. Initializing the Google ML Kit OCR Module

```java
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;

TextRecognizer recognizer = TextRecognition.getClient();

void processImage(Bitmap bitmap) {
    InputImage image = InputImage.fromBitmap(bitmap, 0);
    recognizer.process(image)
        .addOnSuccessListener(visionText -> {
            String extractedText = visionText.getText();
            if (matchesKeywords(extractedText)) {
                exfiltrateData(bitmap, extractedText);
            }
        })
        .addOnFailureListener(e -> { });
}
```

---

## Detection and Reverse Engineering Considerations

For reverse engineers, several low-level details are essential when analyzing SparkCat:

For reverse engineers, several low-level details are essential when analyzing SparkCat:

- **Static Analysis Challenges:**
  - **Obfuscation:** Hardcoded encryption keys, obfuscated strings, and non-standard calling conventions in Rust libraries require dynamic analysis (e.g., using Frida) to reconstruct execution flows.
  - **Configuration Artifacts:** Look for embedded GitLab URLs and Base64-encoded JSON configurations within the application binary.

- **Dynamic Analysis:**
  - **Permission Triggers:** SparkCat typically activates its payload when the user engages with support features (triggering gallery access). Monitoring these UI events can help isolate the malware’s execution path.
  - **Network Traffic:** Analyze outbound encrypted traffic patterns—especially POST requests to specific endpoints (e.g., `/api/e/d/u` and custom paths for Rust-based communication). Decrypting these streams (if keys are recovered) can reveal exfiltrated data.

- **Memory Forensics:**
  - **Payload Decryption:** In-memory analysis may uncover decrypted strings and configuration parameters, providing insights into keyword lists and C2 communication protocols.
  - **Code Injection and Reflection:** Monitoring runtime behavior with dynamic instrumentation tools can reveal reflective calls and dynamic code loading mechanisms.

---

## Attribution and Threat Actor Profile

While definitive attribution remains challenging, several indicators suggest a possible origin:

- **Language Clues:** Comments in the code and directory paths (e.g., “qiongwu” and “quiwengjing”) indicate fluency in Chinese.
- **Technical Sophistication:** The use of Rust for C2 communication—a language uncommon in mobile app development—hints at a team with advanced programming skills and a focus on evasion.
- **Geographic Targeting:** The malware’s keyword lists include languages used primarily in Europe and Asia, and infected apps have been distributed in regions such as the UAE, Indonesia, and Kazakhstan.

Despite these clues, the researchers caution that there is insufficient evidence to definitively attribute SparkCat to a known cybercrime gang or nation-state actor.
 [oai_citation_attribution:9‡theverge.com](https://www.theverge.com/news/606649/ios-iphone-app-store-malicious-apps-malware-crypto-password-screenshot-reader-found)

---

## Conclusion

SparkCat represents a new era of mobile malware that blends traditional social engineering with advanced technical obfuscation and encryption techniques. Its use of OCR to steal cryptocurrency wallet recovery phrases makes it particularly dangerous in today’s digital economy. Reverse engineers and security professionals must leverage both static and dynamic analysis tools to uncover its layers of encryption, obfuscation, and stealth communication.

**Key takeaways:**

- **Infection Vector:** Malicious SDKs embedded in apps from official and third-party stores.
- **Payload:** OCR-based extraction of crypto wallet recovery phrases using Google ML Kit.
- **Encryption:** Multi-layered encryption with AES-128, AES-256, and a custom Rust-based communication module.
- **Attribution:** Possible Chinese origin, though attribution remains inconclusive.
- **Detection:** Requires dynamic analysis, network traffic decryption, and memory forensics to fully understand its behavior.

Staying vigilant, maintaining updated security software, and scrutinizing app permissions remain critical to defending against such sophisticated threats.

---

## References

-  [oai_citation_attribution:10‡cincodias.elpais.com](https://cincodias.elpais.com/smartlife/smartphones/2025-02-06/borra-estas-aplicaciones-en-tu-iphone-o-android-esconden-un-peligroso-malware.html)
-  [oai_citation_attribution:11‡kaspersky.com](https://www.kaspersky.com/about/press-releases/kaspersky-discovers-new-crypto-stealing-trojan-in-appstore-and-google-play)
-  [oai_citation_attribution:12‡securelist.com](https://securelist.com/sparkcat-stealer-in-app-store-and-google-play/115385/)
-  [oai_citation_attribution:13‡securityaffairs.com](https://securityaffairs.com/173873/malware/sparkcat-campaign-target-crypto-wallets.html)
-  [oai_citation_attribution:14‡theverge.com](https://www.theverge.com/news/606649/ios-iphone-app-store-malicious-apps-malware-crypto-password-screenshot-reader-found)
-  [oai_citation_attribution:15‡thehackernews.com](https://thehackernews.com/2025/02/sparkcat-malware-uses-ocr-to-extract.html)

