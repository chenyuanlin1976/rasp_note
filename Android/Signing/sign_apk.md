# Signing APKs (app keys and AOSP platform keys)

Every APK must be signed before Android installs it. The signer uses a **private key**; the matching **certificate**
(public key + subject) is stored in the APK, so the device can check 2 things:

+ **Authenticity**: who signed the app. Updates must be signed with the same key (or a rotated key, section 4),
  otherwise the install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Signature permissions and shared UIDs also compare certificates.
+ **Integrity**: the content hasn't changed since signing. Changing one byte breaks the signature.

The signature identifies the **developer**, not the app's quality. The certificate is normally self-signed; no CA is involved.

Which key to use:

| Key | Used for | Note |
| --- | --- | --- |
| Debug key | Local development (`debug` build type) | Created automatically (section 1). Never for release |
| Release / upload key | Distributing to users or app stores | Your own key, kept secret. With Play App Signing, it is the upload key (section 2) |
| AOSP platform key (`platform`, `shared`, `media`, ...) | System apps on your own AOSP build | Gives signature permissions on images signed with that key (section 5). Use only when the app needs them |

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
+ **Never commit** the keystore or its passwords to git. Keep them in CI secrets, a vault, or `~/.gradle/gradle.properties`.
+ With **Play App Signing**, this key is only the **upload key**. Google signs what users install with the app signing key.
  A lost upload key can be reset through Play Console support; a lost app signing key without Play App Signing can't be recovered.
+ More `keytool` options (inspect, convert JKS → PKCS12): [keytool_cmds.md](keytool_cmds.md).

Release signing in Gradle, with the secrets read from Gradle properties (for example `~/.gradle/gradle.properties`, outside the repo,
or `-P...` / `ORG_GRADLE_PROJECT_...` environment variables in CI):

```kotlin
// app/build.gradle.kts
android {
    signingConfigs {
        create("release") {
            storeFile = file(providers.gradleProperty("RELEASE_STORE_FILE").get())
            storePassword = providers.gradleProperty("RELEASE_STORE_PASSWORD").get()
            keyAlias = providers.gradleProperty("RELEASE_KEY_ALIAS").get()
            keyPassword = providers.gradleProperty("RELEASE_KEY_PASSWORD").get()
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

`.get()` fails with a clear message if a property is missing, instead of signing with an empty password.
Because `signingConfigs` is evaluated when the project is configured, this also stops debug builds on machines without the properties.
If that is a problem, use `.orNull` and set `signingConfig` only when all 4 values are present.
`./gradlew assembleRelease` (APK) or `./gradlew bundleRelease` (AAB) then produces a signed output.

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

An app needs the platform key only for identity tied to the platform signature of **that** ROM:

| Need | Platform key? |
| --- | --- |
| `android:sharedUserId="android.uid.system"` | **Yes.** Otherwise the install fails with `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE` ([sharedUserId.md](sharedUserId.md)) |
| A framework permission with `protectionLevel="signature"` (defined by `android`) | **Yes** |
| A framework permission with `signature\|privileged` | **No**, if the app is in `priv-app` and the permission is allowlisted ([../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md)) |
| A custom `signature` permission defined by a platform-signed app | Yes for the caller, unless the service uses `knownSigner` or a caller check ([signature_permission.md](signature_permission.md)) |
| Hidden APIs (`platform_apis: true` in the AOSP tree) | Usually built with `certificate: "platform"`. Platform-signed apps are exempt from the non-SDK interface restrictions |
| GPIO, PWM, sysfs, `/dev` nodes | **No.** DAC + SELinux decide; use a daemon or HAL ([../HW/hw_control_sysfs.md](../HW/hw_control_sysfs.md)) |
| Wi-Fi MAC, build version | **No** for `Build.*`; the factory MAC needs `LOCAL_MAC_ADDRESS` ([../Debug/mac_address.md](../Debug/mac_address.md)) |
| A normal or third-party app | **No.** Don't ship it with the platform key |

The platform key is a **framework** identity: the package manager and `system_server` compare it with the certificate of `framework-res.apk`.
It doesn't change what the kernel enforces:

| | Platform-signed app | App signed with any other key |
| --- | --- | --- |
| Linux UID | Its own app UID; `system` (1000) only with `sharedUserId="android.uid.system"`. Never `root` (0) | Its own app UID |
| SELinux domain | `platform_app` (`system_app` with the system UID) ([../SELinux/SELinux_domains.md](../SELinux/SELinux_domains.md)) | `untrusted_app`, or `priv_app` if it is a privileged app |
| Signature permissions | Those defined by `android` and by other platform-signed apps | Only those defined by apps signed with the same key |
| sysfs, `/dev`, SELinux rules | Still enforced. Signing never bypasses DAC or SELinux | Same |
| Install and update | Only on builds signed with the same platform key. On another ROM (other OEM key, or AOSP test keys) signature permissions aren't granted and `sharedUserId="android.uid.system"` fails to install | Any build. Updates must use the same key as the installed version |

+ Your board's BSP may still use the public AOSP test keys. Then the "platform key" is known to everyone, and any app signed with it gets platform privileges.
  Build a product with your own keys ([verify_platformKeys.md](verify_platformKeys.md)).
+ For hardware control on a board such as RK3566, don't put the hardware access into a platform-signed app.
  Put it in a HAL or daemon with its own SELinux domain, and let the app call it through Binder ([../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md)).

Check what a given app actually needs:

```shell
aapt2 dump xmltree app.apk --file AndroidManifest.xml | grep -iE "sharedUserId|permission"   # what it declares and requests
adb shell dumpsys package com.example.myapp | grep -E "granted=false"                       # signature permissions not granted
adb logcat | grep -iE "PackageManager|INSTALL_FAILED|Permission Denial"                     # install or call failures
```

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

+ [keytool_cmds.md](keytool_cmds.md), [verify_platformKeys.md](verify_platformKeys.md), [../../Linux/Network/openssl_note.md](../../Linux/Network/openssl_note.md)
+ [sharedUserId.md](sharedUserId.md): platform shared UIDs and signature permissions
+ [signature_permission.md](signature_permission.md): which key to sign a service and its callers with
+ [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md), [../App/gradle_build.md](../App/gradle_build.md), [../App/Groovy_kotlin_DSL.md](../App/Groovy_kotlin_DSL.md)
+ [keystore_intro.md](keystore_intro.md): the runtime Android Keystore, a different topic

## Reference

+ [apksigner](https://developer.android.com/tools/apksigner), [zipalign](https://developer.android.com/tools/zipalign)
+ [Sign your app (Play App Signing, upload key)](https://developer.android.com/studio/publish/app-signing)
+ [Application signing and schemes (AOSP)](https://source.android.com/docs/security/features/apksigning)
+ [Sign builds for release (AOSP)](https://source.android.com/docs/core/ota/sign_builds)
