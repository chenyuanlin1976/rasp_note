# Signing APKs (app keys and AOSP platform keys)

Every APK must be signed before Android installs it.
The signature identifies the **developer**, not the app's quality: updates must be signed with the same key,
and signature permissions or shared UIDs compare certificates.

## 1. Key files and keystores

| Format | Content | Used by |
| --- | --- | --- |
| `*.x509.pem` | The **certificate** (public key + subject, PEM) | AOSP keys (`platform.x509.pem`), `apksigner --cert` |
| `*.pk8` | The **private key**, PKCS#8, DER, unencrypted | AOSP keys (`platform.pk8`), `apksigner --key` |
| `.p12` / `.pfx` | PKCS#12 keystore: private key + certificate chain, password-protected | Standard format; the `keytool` default since JDK 9 |
| `.jks` / `.keystore` | Java KeyStore (proprietary) holding one or more alias entries | Older `keytool` default; Android Studio, Gradle |

Android Studio and Gradle accept both **JKS and PKCS12** keystores.

The **debug keystore** is created automatically by Android Studio:

| Item | Value |
| --- | --- |
| File | `~/.android/debug.keystore` |
| Store password / key password | `android` / `android` |
| Alias | `androiddebugkey` |

Apps signed with it can't be published on Play. All builds on the same machine share it, but other machines have different ones.

## 2. Create a release key

```shell
keytool -genkeypair -v -keystore release.p12 -storetype PKCS12 \
        -alias release -keyalg RSA -keysize 4096 -validity 10000
keytool -list -v -keystore release.p12          # aliases, SHA-256 fingerprint
```

+ Keep the keystore and its passwords backed up. An app can't be updated without its key, except through key rotation (v3, section 4).
+ With **Play App Signing**, this key is only the **upload key**. Google signs what users install with the app signing key.
+ More `keytool` options: [keytool_cmds.md](keytool_cmds.md).

## 3. Sign and verify with `apksigner`

`apksigner` is in the SDK build-tools (`$ANDROID_HOME/build-tools/<version>/`).
Run **`zipalign` before `apksigner`**: v2+ signatures cover the whole file, so aligning afterwards breaks them.

```shell
zipalign -p -f 4 app-unsigned.apk app-aligned.apk

# with a keystore
apksigner sign --ks release.p12 --ks-key-alias release --out app-signed.apk app-aligned.apk

# with a .pk8 + .x509.pem pair (for example the AOSP platform key)
apksigner sign --key platform.pk8 --cert platform.x509.pem --out app-signed.apk app-aligned.apk

apksigner verify -v --print-certs app-signed.apk   # schemes used, signer certificate digests
zipalign -c -p 4 app-signed.apk                    # still aligned?
```

+ Without `--out`, `apksigner` signs **in place** and overwrites the input.
+ By default, `apksigner` adds v1, v2, and v3 signatures, using the APK's `minSdkVersion` to pick algorithms.
  For `minSdk` 24+, v1 can be dropped with `--v1-signing-enabled false`.
+ Android Studio / Gradle (`signingConfigs { release { ... } }`) runs `zipalign` and signs automatically
  (build outputs: [../App/gradle_build.md](../App/gradle_build.md)). Run `apksigner` by hand only for APKs built elsewhere.
+ `keytool -printcert -jarfile app.apk` reads only the **v1** (JAR) signature. For an APK without v1, it prints "Not a signed jar file". Use `apksigner verify`.
+ `jarsigner` creates only v1 signatures, so don't use it for APKs.

## 4. Signature schemes

| Scheme | Since | What it signs | Note |
| --- | --- | --- | --- |
| v1 (JAR signing) | Android 1.0 | Each ZIP entry (`META-INF/*.SF`, `*.RSA`) | Doesn't protect the ZIP metadata. Needed only for `minSdk` < 24 |
| v2 (APK Signature Scheme v2) | Android 7.0 (API 24) | The whole APK, block-wise | Required for apps targeting Android 11 (API 30)+ |
| v3 | Android 9 (API 28) | Like v2, plus a **key rotation** lineage (`apksigner rotate`) | |
| v3.1 | Android 13 (API 33) | A second v3 block that only API 33+ reads | Lets rotation target newer releases while older ones keep the original key (`--rotation-min-sdk-version`) |
| v4 | Android 11 (API 30) | Separate `app.apk.idsig` file | For ADB incremental install. Needs v2 or v3 as well |

For maximum compatibility, sign with all needed schemes. `apksigner` does this by default.

## 5. Sign an app with the AOSP platform key

Apps built **in the AOSP tree** are signed by the build: `certificate: "platform"` in `Android.bp`
(`LOCAL_CERTIFICATE := platform` in `Android.mk`). Nothing manual is needed.

For an app built **in Android Studio** that must run with `android.uid.system` or needs signature permissions
on your own board, sign it with that board's `platform.pk8` + `platform.x509.pem`.
The signature alone doesn't give the system UID: the manifest must also declare `android:sharedUserId="android.uid.system"`
(see [sharedUserId.md](sharedUserId.md)). An APK signed this way only works on builds that use the same platform key.

```shell
# Option A: sign the finished APK directly
apksigner sign --key platform.pk8 --cert platform.x509.pem --out app-platform.apk app.apk

# Option B: build a keystore that Gradle / Android Studio can use
openssl pkcs8 -inform DER -in platform.pk8 -nocrypt -out platform.key.pem
openssl pkcs12 -export -in platform.x509.pem -inkey platform.key.pem \
        -name platform -out platform.p12          # prompts for the export (store) password
rm platform.key.pem                              # don't leave the unencrypted key around
keytool -list -keystore platform.p12             # alias "platform"
```

```kotlin
// app/build.gradle.kts
android {
    signingConfigs {
        create("platform") {
            storeFile = file("../keys/platform.p12")
            storePassword = System.getenv("PLATFORM_STORE_PASS")
            keyAlias = "platform"
            keyPassword = System.getenv("PLATFORM_STORE_PASS")   // PKCS12: same as the store password
        }
    }
    buildTypes { getByName("debug") { signingConfig = signingConfigs.getByName("platform") } }
}
```

+ If an old JDK can't read the `.p12` that OpenSSL 3 creates, add `-legacy` to `openssl pkcs12 -export`.
+ AOSP's own tool also works: `java -Djava.library.path=out/host/linux-x86/lib64 -jar out/host/linux-x86/framework/signapk.jar platform.x509.pem platform.pk8 in.apk out.apk`.
+ The keys in `build/target/product/security/` are the public **test keys**. Anyone can sign apps with them.
  A product must be built with its own keys (`development/tools/make_key`, then release-sign the build).
  Check which keys a build uses with [verify_platformKeys.md](verify_platformKeys.md).

## 6. Check that a private key matches a certificate

Compare the public keys. This works for RSA and EC keys:

```shell
openssl pkey -inform DER -in platform.pk8 -pubout | openssl sha256     # private key (.pk8 is DER)
openssl x509 -in platform.x509.pem -pubkey -noout | openssl sha256     # certificate
```

The key pair matches if the 2 hashes are equal.

## Related notes

+ [keytool_cmds.md](keytool_cmds.md), [verify_platformKeys.md](verify_platformKeys.md), [../../Linux/openssl_note.md](../../Linux/openssl_note.md)
+ [sharedUserId.md](sharedUserId.md): platform shared UIDs and signature permissions
+ [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md), [../App/gradle_build.md](../App/gradle_build.md), [../App/Groovy_kotlin_DSL.md](../App/Groovy_kotlin_DSL.md)
+ [keystore_intro.md](keystore_intro.md): the runtime Android Keystore, a different topic

## Reference

+ [apksigner](https://developer.android.com/tools/apksigner), [zipalign](https://developer.android.com/tools/zipalign)
+ [Sign your app (Play App Signing, upload key)](https://developer.android.com/studio/publish/app-signing)
+ [Application signing and schemes (AOSP)](https://source.android.com/docs/security/features/apksigning)
+ [Sign builds for release (AOSP)](https://source.android.com/docs/core/ota/sign_builds)
