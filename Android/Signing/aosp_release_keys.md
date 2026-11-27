# AOSP platform keys and release signing (Android 14, RK3566)

An Android 14 AOSP build (including Rockchip RK3566 BSP builds) signs its APKs with a few **key classes**.
By default they map to the public **test keys** in `build/make/target/product/security/`.
Anyone can sign an app with those keys, so a product image must be re-signed with your own keys.
Image verification (AVB), APEX, and OTA keys are separate from the APK keys (section 2).

How to check which keys a build or device uses: [verify_platformKeys.md](verify_platformKeys.md).

## 1. APK key classes

A module chooses its key with `certificate: "<name>"` in `Android.bp` (`LOCAL_CERTIFICATE := <name>` in `Android.mk`).
A module without it gets the default key (`testkey`, or `PRODUCT_DEFAULT_DEV_CERTIFICATE`).
The set of keys changes between releases; list `build/make/target/product/security/*.x509.pem` in your tree to see yours.

| Key class | Purpose | Example modules |
| --- | --- | --- |
| `testkey` (mapped to `releasekey`) | Default key for modules without a `certificate`. `sign_target_files_apks -o` also uses it as the OTA key | Ordinary system APKs |
| `platform` | Core OS key. Grants platform `signature` permissions, and is required for `android.uid.system` | `framework-res`, Settings, SystemUI, SettingsProvider, DocumentsUI, your RK3566 hardware control app |
| `media` | Media and download providers | MediaProvider, DownloadProvider |
| `shared` | Apps of the `android.uid.shared` group (contacts and related apps) | ContactsProvider, Launcher3 |
| `networkstack` | Network stack module, updatable independently of the platform | NetworkStack, CaptivePortalLogin, Tethering |
| `bluetooth` | Bluetooth module app (Android 13+) | Bluetooth |
| `sdk_sandbox` | Privacy Sandbox SDK runtime (Android 13+) | SdkSandbox |

A key does **not** give an app a shared UID by itself. The app must also declare `android:sharedUserId`,
and then the key must match the one of that shared UID ([sharedUserId.md](sharedUserId.md#2-platform-shared-uids-aosp)).
What a platform-signed app may do is in [sign_apk.md](sign_apk.md#5-sign-an-app-with-the-aosp-platform-key).

| | `platform` | `media`, `shared`, `networkstack`, `bluetooth`, `sdk_sandbox` | `testkey` / `releasekey` |
| --- | --- | --- | --- |
| Goal | System-level access to OS APIs | **Least privilege**: each subsystem gets its own key, not the platform key | Default key, OTA key |
| Risk if the private key leaks | **Highest**: anyone can sign apps with platform permissions, or as `android.uid.system` | Limited to that subsystem's permissions and data | With the public test keys: anyone can sign apps and OTA packages your device accepts |

## 2. Other device keys

+ **AVB (Android Verified Boot 2.0) keys** sign the `vbmeta` image, which holds the hashes of `boot`, `system`, `vendor`, and the other partitions.
  The bootloader checks them at boot. Set your own with `BOARD_AVB_KEY_PATH` / `BOARD_AVB_ALGORITHM`
  (the default is the AVB test key in `external/avb/test/data/`), or re-sign with the `--avb_*` options of `sign_target_files_apks`.
  The old `verity` key belongs to AVB 1.0 and is not used on current builds.
+ **APEX keys**: each APEX module (ART runtime, Conscrypt, time zone data, ...) has a payload key and a container certificate,
  so it can be updated independently (`--extra_apex_payload_key`).
+ **OTA key**: `releasekey` after `sign_target_files_apks -o`; its certificate goes into `otacerts.zip` on the device.

## 3. Re-sign a build with your own keys

Generate your keys once, sign a `target-files` package with `sign_target_files_apks`, and build the images from the signed package.
This is the method that AOSP recommends; building directly with `PRODUCT_DEFAULT_DEV_CERTIFICATE` is compared in [verify_platformKeys.md](verify_platformKeys.md#1-how-a-build-gets-release-keys).

### 3.1 Create a private key directory

Keep the keys **outside** the source tree. Don't commit them, and don't put them in `build/make/target/product/security/`.

```shell
mkdir -p ~/.android-certs/rk3566
chmod 700 ~/.android-certs/rk3566
ls -ld ~/.android-certs/rk3566          # drwx------
```

### 3.2 Generate the key pairs

Run `make_key` from the source root for every key class that your tree uses (section 1).
It asks for a password; an empty one leaves the key unencrypted.

```shell
subject='/C=TW/ST=Miaoli/L=Zhunan/O=YourCompany/OU=Embedded/CN=RK3566'
for k in releasekey platform shared media networkstack bluetooth sdk_sandbox; do
    ./development/tools/make_key ~/.android-certs/rk3566/$k "$subject"
done
ls ~/.android-certs/rk3566/             # a .pk8 and a .x509.pem for each key
```

Back up the directory offline. Without the same keys, you can't ship updates to devices already in the field.

### 3.3 Build the target-files package

```shell
source build/envsetup.sh
lunch <your_rk3566_lunch_target>
m dist
ls out/dist/*-target_files-*.zip
```

### 3.4 Sign APKs, APEXes, and the OTA key

`--default_key_mappings` maps every AOSP test key to the file of the same name in your directory (`testkey` → `releasekey`).
`-o` (`--replace_ota_keys`) also replaces the OTA verification key.

```shell
sign_target_files_apks -o \
    --default_key_mappings ~/.android-certs/rk3566 \
    out/dist/*-target_files-*.zip \
    signed-target_files.zip

unzip -p signed-target_files.zip SYSTEM/build.prop | grep ro.build.tags    # release-keys
```

+ Custom AVB keys: add the `--avb_vbmeta_key`, `--avb_system_key`, ... options.
+ APEX modules: `--extra_apex_payload_key <name>.apex=<key>.pem`, and their container keys with `--extra_apks`.
+ APKs with a key that `--default_key_mappings` doesn't cover: `--extra_apks <name>.apk=<key>`.

### 3.5 Build the images and flash

```shell
img_from_target_files signed-target_files.zip signed-img.zip
```

Rockchip SDKs usually pack the partition images into `update.img` with their own scripts (for example `mkimage.sh` / `build.sh` in the SDK).
Feed them the signed images; check your BSP for the exact steps. After flashing:

```shell
adb shell getprop ro.build.tags          # release-keys, not test-keys
adb shell getprop ro.build.fingerprint   # ends in release-keys
```

The negative test in [verify_platformKeys.md](verify_platformKeys.md#4-negative-test) confirms that the device no longer trusts the test platform key.

## 4. Notes

+ **`PRESIGNED` APKs:** a prebuilt with `presigned: true` (`LOCAL_CERTIFICATE := PRESIGNED`) keeps its signature;
  `sign_target_files_apks` doesn't re-sign it. Check `META/apkcerts.txt` for such APKs from the Rockchip tree.
+ **Signature permissions on `user` builds:** after re-signing, your own apps that rely on platform `signature` permissions
  must be signed with the **new** platform key, and listed in the signature permission allowlist if they are installed in `/data/app`
  ([signature_vs_privileged.md](signature_vs_privileged.md#1-key-differences)).
+ **Encrypted keys:** with password-protected keys, `sign_target_files_apks` asks for the passwords,
  or reads them from the file in `ANDROID_PW_FILE`.

## Related notes

+ [verify_platformKeys.md](verify_platformKeys.md): check which keys a build or device uses
+ [sign_apk.md](sign_apk.md): sign an APK, what the platform key gives an app
+ [sharedUserId.md](sharedUserId.md): platform shared UIDs and their keys
+ [signature_vs_privileged.md](signature_vs_privileged.md): signature vs. privileged permissions
+ [keytool_cmds.md](keytool_cmds.md)

## Reference

+ [Sign builds for release (AOSP)](https://source.android.com/docs/core/ota/sign_builds)
+ [Application signing (AOSP)](https://source.android.com/docs/security/features/apksigning)
+ [Android Verified Boot (AOSP)](https://source.android.com/docs/security/features/verifiedboot)
