# Verify which keys an AOSP build is signed with

AOSP signs every APK with one of a few **key classes**: `releasekey` (= testkey), `platform`, `shared`, `media`, `networkstack`, plus `PRESIGNED` for prebuilt APKs.
By default, the classes map to the public **test keys** in `build/target/product/security/`.
Anyone can sign an app with those keys, so a deployed image must use your own keys.

## 1. How a build gets release keys

| Approach | How | Result |
| --- | --- | --- |
| **Re-sign the target files** (recommended by AOSP) | `make dist`, then `sign_target_files_apks` with your key directory | All APKs re-signed, `ro.build.tags=release-keys` |
| Build directly with your keys | `PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/<you>/security/releasekey` | `platform`, `shared`, ... are taken from the same directory; `ro.build.tags=dev-keys` |

```shell
# Generate the keys once (keep them offline / backed up)
subject='/C=TW/O=Example/CN=Example'
mkdir -p ~/.android-certs
for x in releasekey platform shared media networkstack; do
    ./development/tools/make_key ~/.android-certs/$x "$subject"
done

# Re-sign and build images
make dist
sign_target_files_apks -o --default_key_mappings ~/.android-certs \
    out/dist/*-target_files-*.zip signed-target_files.zip
img_from_target_files signed-target_files.zip signed-img.zip
```

+ APKs that need another key, or that should stay as they are: `--extra_apks <name>.apk=<key>` (an empty key means pre-signed).
+ APEX payload keys, the OTA key, and AVB (verified boot) keys are separate from APK signing. See the AOSP page linked under Reference.

## 2. Which key class each APK uses

The target-files zip has `META/apkcerts.txt`, which lists the certificate and private key that the build used for every APK.
This tells you the key class (or `PRESIGNED`) that `sign_target_files_apks` will map:

```shell
unzip -p out/dist/*-target_files-*.zip META/apkcerts.txt | grep -E '"(Settings|SystemUI|framework-res)\.apk"'
```

## 3. Compare an APK's certificate with your key

`apksigner` prints the certificate's SHA-256 digest as lowercase hex.
Hashing the DER form of your `.x509.pem` gives the same string:

```shell
apksigner verify --print-certs out/target/product/<device>/system/priv-app/Settings/Settings.apk | grep SHA-256
openssl x509 -in ~/.android-certs/platform.x509.pem -outform DER | sha256sum
```

On a running device, pull a platform-signed APK and check it in the same way:

```shell
adb pull /system/framework/framework-res.apk
apksigner verify --print-certs framework-res.apk | grep SHA-256
adb shell getprop ro.build.tags            # release-keys (re-signed), dev-keys (own default cert), test-keys (AOSP test keys)
adb shell getprop ro.build.fingerprint     # also ends in release-keys / test-keys
```

## 4. Negative test

Build a small app with `android:sharedUserId="android.uid.system"`, and sign it with the AOSP **test** platform key.

+ On a release-keyed build, the install must fail with `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE`.
+ If it installs, the device still trusts the test platform key.

The same app signed with **your** platform key must install. That also confirms that your key pair (`.pk8` + `.x509.pem`) is the one the build used.

## Related notes

+ [sign_apk.md](sign_apk.md), [keytool_note.md](keytool_note.md), [sharedUserId.md](sharedUserId.md)
+ [AOSP_preinstalled_apps.md](AOSP_preinstalled_apps.md)

## Reference

+ [Sign builds for release (AOSP)](https://source.android.com/docs/core/ota/sign_builds)
+ [Application signing (AOSP)](https://source.android.com/docs/security/features/apksigning)
