# keytool commands

`keytool` (part of the JDK) manages Java keystores: private keys with their certificates (`PrivateKeyEntry`),
and trusted certificates (`trustedCertEntry`).
For Android, you mainly use it to create the app signing key and to read certificate fingerprints.
Signing itself is done by `apksigner`; see [sign_apk.md](sign_apk.md).

| Command | Older alias | Purpose |
| --- | --- | --- |
| `-genkeypair` | `-genkey` | New key pair + self-signed certificate |
| `-list` | | List entries; `-v` shows details, `-rfc` shows PEM |
| `-exportcert` | `-export` | Write a certificate to a file |
| `-importcert` | `-import` | Add a trusted certificate (or a CA reply) |
| `-importkeystore` | | Copy or convert keystores (JKS ↔ PKCS12) |
| `-printcert` | | Show a certificate file, a signed JAR / v1 APK, or a TLS server certificate |
| `-delete`, `-changealias`, `-storepasswd`, `-keypasswd` | | Maintenance |

All examples were run with OpenJDK 21. Since JDK 9, the default keystore type is **PKCS12**.

## 1. Create a key

```shell
keytool -genkeypair -v \
    -keystore release.p12 -storetype PKCS12 \
    -alias release \
    -keyalg RSA -keysize 3072 -validity 10000 \
    -dname "CN=Example, O=Example, C=TW"
```

+ Without `-dname`, keytool asks for the name fields interactively.
  Without `-storepass` / `-keypass`, it asks for passwords, which is better than putting them on the command line, where they end up in the shell history.
+ For a PKCS12 keystore, the key password is the store password.

## 2. Inspect

```shell
keytool -list -keystore release.p12                       # aliases, entry type, SHA-256 fingerprint
keytool -list -v -keystore release.p12 -alias release     # full certificate details
keytool -printcert -file cert.pem                         # a certificate file (PEM or DER)
keytool -printcert -jarfile app.apk                       # v1 (JAR) signature only; use "apksigner verify" for APKs
keytool -printcert -sslserver example.com:443             # certificate chain of a TLS server
```

Which fingerprint services ask for:

| Service | Fingerprint |
| --- | --- |
| Google Maps / Google Cloud API key restriction | SHA-1 |
| Firebase app registration | SHA-1 and/or SHA-256 |
| Android App Links (`assetlinks.json`) | SHA-256 |

With **Play App Signing**, users get the APK signed with Google's **app signing key**, not your upload key.
Register the app signing key's fingerprints (Play Console → *App integrity*) as well as your upload or debug key's.

## 3. Export and import certificates

```shell
keytool -exportcert -rfc -alias release -keystore release.p12 -file release.pem   # -rfc: PEM, otherwise DER

keytool -importcert -noprompt -alias partner -file partner.pem \
    -keystore truststore.p12 -storetype PKCS12                                     # trusted certificate entry

keytool -list -cacerts                                    # the JDK's own CA truststore (default password: changeit)
```

## 4. Convert and maintain keystores

```shell
# JKS -> PKCS12 (keytool warns that JKS is proprietary and suggests this)
keytool -importkeystore -srckeystore old.jks -destkeystore new.p12 -deststoretype PKCS12

# PKCS12 -> JKS, only if an old tool requires JKS
keytool -importkeystore -srckeystore new.p12 -destkeystore old.jks -deststoretype JKS

keytool -changealias -alias app -destalias release -keystore release.p12
keytool -storepasswd -keystore release.p12                # new store password (min. 6 characters)
keytool -keypasswd -alias release -keystore old.jks       # JKS only; on PKCS12: "-keypasswd commands not supported"
keytool -delete -alias partner -keystore truststore.p12

keytool -certreq -alias release -keystore release.p12 -file release.csr   # CSR for a CA-signed certificate
```

Converting AOSP `.pk8` + `.x509.pem` keys into a keystore needs `openssl` first; see [sign_apk.md](sign_apk.md#5-sign-an-app-with-the-aosp-platform-key).

## Related notes

+ [sign_apk.md](sign_apk.md), [verify_platformKeys.md](verify_platformKeys.md), [../Linux/openssl_note.md](../Linux/openssl_note.md)

## Reference

+ [keytool (JDK 21 docs)](https://docs.oracle.com/en/java/javase/21/docs/specs/man/keytool.html)
+ [Sign your app](https://developer.android.com/studio/publish/app-signing)
