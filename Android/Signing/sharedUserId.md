# sharedUserId

`android:sharedUserId` is a `<manifest>` attribute that puts several apps into **one Linux UID**.
By default, every app gets its own UID, which is the base of the Android app sandbox.
Apps that declare the same `sharedUserId` and are signed with the **same certificate set** share one UID.
They can read each other's private files, and, if they also use the same `android:process` name, they can run in the same process.

The attribute is **deprecated since API level 29 (Android 10)**. New apps should not use it.
Platform apps built with AOSP still use the predefined system shared UIDs (section 2).

## 1. Rules

+ All apps in a shared UID must be signed with the same certificates.
  Otherwise the install fails with `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE`.
+ The value is fixed for the app's lifetime on a device.
  An update can't add, remove, or change `sharedUserId`. The install fails, typically with `INSTALL_FAILED_UID_CHANGED`,
  because the app's data directory and its granted permissions belong to the old UID.
+ Permissions are granted per UID, so in practice every app in the group gets the **union** of the group's permissions.
+ Apps with `android:targetSandboxVersion="2"` can't share a UID. Instant apps use this sandbox.

## 2. Platform shared UIDs (AOSP)

Some shared UIDs are defined by the platform. An app can join one only if it is signed with the matching platform key.
The certificates are the AOSP test keys in `build/make/target/product/security/`, or the device maker's release keys.

| `android:sharedUserId` | UID | Certificate (`Android.bp`) | Example |
| --- | --- | --- | --- |
| `android.uid.system` | 1000 (`system`) | `certificate: "platform"` | Settings |
| `android.uid.phone` | 1001 (`radio`) | `certificate: "platform"` | Telephony apps |
| `android.uid.bluetooth` | 1002 (`bluetooth`) | `certificate: "platform"` | Bluetooth app |
| `android.uid.nfc` | 1027 (`nfc`) | `certificate: "platform"` | NFC app |
| `android.uid.se` | 1068 (`secure_element`) | `certificate: "platform"` | SecureElement app |
| `android.uid.shared` | allocated at install | `certificate: "shared"` | Contacts provider |
| `android.media` | allocated at install | `certificate: "media"` | Media apps (older releases) |

```bp
android_app {
    name: "MySystemApp",
    srcs: ["src/**/*.kt"],
    certificate: "platform",     // required for android.uid.system
    platform_apis: true,
    privileged: true,            // installed in /system/priv-app (or system_ext with system_ext_specific: true)
}
```

An app with `android.uid.system` runs as UID 1000 in the SELinux domain `system_app` and has access to almost everything `system_server` owns.
For a new system app, give it **least privilege** instead:
platform-signed or privileged, with only the permissions it needs (`privapp-permissions-*.xml`), and its own UID.
See [../SELinux/SELinux_domains.md](../SELinux/SELinux_domains.md) for `system_app` / `platform_app` / `priv_app`.

## 3. Why it was deprecated

+ **Non-deterministic package manager behavior**: the result depends on install and update order among the members.
  This is the reason the official documentation gives.
+ **No isolation**: if one app in the group is compromised, the attacker gets the private data and the permissions of all of them.
+ **No way out**: because the UID can't change on update (section 1), an app that once shipped with `sharedUserId` was stuck with it.

## 4. Migration: `android:sharedUserMaxSdkVersion` (API 33)

An existing app **can't remove** `sharedUserId`.
Since Android 13, it can stop using it for *new* installs:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    android:sharedUserId="com.example.shared"
    android:sharedUserMaxSdkVersion="32">
    <!-- ... -->
</manifest>
```

+ A **new install** on a device with an SDK level **higher** than the value (here: Android 13+, API 33+)
  behaves as if `sharedUserId` weren't there. The app gets its own UID.
+ An **existing install** that already has the shared UID keeps it on update, so its data is not lost.
+ On devices with SDK ≤ the value, the shared UID is used as before.
+ So the app must work **both** ways: with the shared UID (old installs) and without it (new installs).
  Move the data exchange to the mechanisms in section 5 first, then add the attribute.

## 5. Replacements

Use explicit IPC between apps that each keep their own UID:

| Need | Mechanism | Note |
| --- | --- | --- |
| Share structured data or files | `ContentProvider` with a signature permission, or per-URI grants | [../App/ContentProvider_sharing.md](../App/ContentProvider_sharing.md) |
| Call methods / business logic in the other app | Bound service with AIDL (or `Messenger`) | [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md) |
| Trigger an action or send small data | Explicit `Intent` (activity, service, broadcast with a permission) | |
| Expose hardware or a system service to apps | A system app with a bound service in front of the HAL | [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md) |

### 5.1 Limit access to your own apps: signature permissions

The old trust rule of `sharedUserId` was "same certificate".
A custom permission with `protectionLevel="signature"` gives the same rule, but only for the provider or service that you protect:

```xml
<!-- Declare the permission in BOTH apps, so that install order doesn't matter -->
<permission
    android:name="com.example.appa.permission.ACCESS_DATA"
    android:protectionLevel="signature" />

<uses-permission android:name="com.example.appa.permission.ACCESS_DATA" />
```

+ The system grants it only to apps signed with the **same certificate** as the app that defines it.
  Another app can define the same permission name only if it has the same signer.
+ **Debug builds**: Android Studio signs with the machine's `~/.android/debug.keystore`.
  Two apps built on the same machine therefore match, but apps built on different machines don't.
+ **Release builds** must use the same release key.
  With Play App Signing, Google holds the app signing key, so both apps must use the **same app signing key**
  (Play Console: *Change app signing key → Use the same key as another app in this account*).
+ **Different signers** (Android 12, API 31+): use `protectionLevel="signature|knownSigner"` with `android:knownCerts`,
  which lists the SHA-256 digests of the other signing certificates.
+ On the server side, you can additionally check `Binder.getCallingUid()` / `getCallingPackage()`.

## Related notes

+ [../App/ContentProvider_sharing.md](../App/ContentProvider_sharing.md), [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md)
+ [../SELinux/SELinux_domains.md](../SELinux/SELinux_domains.md), [sign_apk.md](sign_apk.md), [verify_platformKeys.md](verify_platformKeys.md)

## Reference

+ [`<manifest>` element: `sharedUserId`, `sharedUserMaxSdkVersion`](https://developer.android.com/guide/topics/manifest/manifest-element)
+ [Define a custom app permission (`signature`, `knownSigner`)](https://developer.android.com/guide/topics/permissions/defining)
+ [Security tips](https://developer.android.com/privacy-and-security/security-tips)
+ [Sign your app (Play App Signing)](https://developer.android.com/studio/publish/app-signing)
