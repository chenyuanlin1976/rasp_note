# Restrict who can bind a service: signature permissions and caller checks

An Android `Service` is private unless it is exported. `android:exported` defaults to `false` for a component without an intent filter,
and since Android 12 (targetSdk 31+) a component with an intent filter must set it explicitly; set it explicitly anyway.
If other apps must bind to it, restrict the callers with:

+ a custom **permission** on the service (`signature`, `signature|knownSigner`, or `normal` + a check), enforced by the system at bind time;
+ a **caller check** inside each AIDL method (UID → signing certificate digest);
+ on your own AOSP image, **SELinux** for the layer behind the service (system app → HAL), never for `untrusted_app`.

Which key signs the service and its callers decides which of these works. This note covers that choice.
The basic manifest for a protected bound service is in [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md);
the PWM service used as the example here is in [../HW/pwm_control.md](../HW/pwm_control.md).

## 1. Choose the approach

| Callers | Approach | Note |
| --- | --- | --- |
| Only your own app | `android:exported="false"` | No other app can bind at all |
| Your apps, all signed with the **same key** | `protectionLevel="signature"` | Enforced by the system at bind time (section 2) |
| Apps with **different keys** whose certificates you know, Android 12+ | `protectionLevel="signature\|knownSigner"` + `android:knownCerts` | Still enforced by the system ([sharedUserId.md](sharedUserId.md#51-limit-access-to-your-own-apps-signature-permissions)) |
| Apps with different keys on older releases, or rules per method | `normal` permission (or none) + caller check in every method (section 3) | Compare the **certificate digest**, not only the package name |
| Service in your AOSP image, HAL behind it | Any of the above + SELinux for the system app's domain | [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md) |

Don't rely on the **package name** alone: any app can use any package name that isn't installed yet.
The signing certificate is what identifies the developer.

## 2. Signature permission: what "same key" means

The service app defines the permission and protects the service with it (names from [../HW/pwm_control.md](../HW/pwm_control.md)):

```xml
<!-- service app: com.example.pwm -->
<permission
    android:name="com.example.permission.CONTROL_PWM"
    android:protectionLevel="signature" />

<application>
    <service
        android:name=".PwmControlService"
        android:exported="true"
        android:permission="com.example.permission.CONTROL_PWM" />
</application>
```

```xml
<!-- caller app -->
<uses-permission android:name="com.example.permission.CONTROL_PWM" />
<queries>
    <package android:name="com.example.pwm" />
</queries>
```

The system grants a `signature` permission at install time if the caller's **signing certificate** equals the certificate
of the app that **defines** the permission. Any key works: your own release key or an AOSP platform key. Only "the same" matters.
If the permission isn't granted, `bindService()` fails with a `SecurityException`.

| Service signed with | Caller must be signed with | Typical use |
| --- | --- | --- |
| Your own key (`.p12` / `.jks`) | The same key | Companion apps, partner apps you sign yourself |
| AOSP platform key (`certificate: "platform"`) | The same platform key | Other apps built into the same image |

Things that catch developers out:

+ **Debug vs. release**: a caller run from Android Studio is signed with `~/.android/debug.keystore`, not your release key, so it doesn't get the permission.
+ **Install order**: if the caller is installed before the defining app, the permission doesn't exist yet at the caller's install,
  and depending on the release it may stay ungranted until the caller is reinstalled.
  Declare the same `<permission>` in both apps (allowed because they have the same signer) so the order doesn't matter.
+ **Duplicate definitions**: since Android 5.0, installing an app that defines a permission already defined by an app with a **different** key
  fails with `INSTALL_FAILED_DUPLICATE_PERMISSION`.
+ **Key rotation** (APK Signature Scheme v3, Android 9+): an app signed with a rotated key still matches apps signed with its older key
  if the signing lineage allows it. See [sign_apk.md](sign_apk.md#4-signature-schemes).

Check which certificate signed an APK; two APKs match if the digests are equal:

```shell
apksigner verify --print-certs app.apk | grep 'SHA-256'     # "Signer #1 certificate SHA-256 digest: ..."
```

## 3. Caller check inside the service

Check the caller in **each AIDL method**, not in `onBind()`:

+ `onBind()` runs on the service's main thread, not inside a Binder call, so `Binder.getCallingUid()` there returns the service's own UID.
+ The system caches the returned `IBinder` and hands it to later clients binding with an equivalent `Intent` without calling `onBind()` again.

`PackageManager.hasSigningCertificate(uid, ...)` (API 28+) compares the caller's certificate with a SHA-256 digest directly.
A caller that binds to your service is automatically visible to it, so package visibility doesn't block this lookup.

```kotlin
package com.example.pwm

import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Binder
import android.os.IBinder

class PwmControlService : Service() {

    // SHA-256 digests of the allowed signing certificates (apksigner verify --print-certs), no colons.
    private val allowedCerts: List<ByteArray> = listOf(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ).map { hex -> hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray() }

    private fun enforceAllowedCaller() {
        val uid = Binder.getCallingUid()          // read before any clearCallingIdentity()
        val allowed = allowedCerts.any { cert ->
            packageManager.hasSigningCertificate(uid, cert, PackageManager.CERT_INPUT_SHA256)
        }
        if (!allowed) throw SecurityException("UID $uid may not control PWM")   // delivered to the caller
    }

    private val binder = object : IPwmControl.Stub() {
        override fun setDutyPercent(percent: Int) {
            enforceAllowedCaller()
            // ... call the HAL as in pwm_control.md
        }

        override fun getDutyPercent(): Int {
            enforceAllowedCaller()
            return 0   // ... read from the HAL
        }
    }

    override fun onBind(intent: Intent): IBinder = binder
}
```

+ To also pin the package name, compare `packageManager.getPackagesForUid(uid)` with an allowlist **in addition to** the certificate.
+ For permission-based checks per method, use `enforceCallingPermission(permission, message)`.
+ `hasSigningCertificate()` also accepts certificates from the app's rotation lineage (past keys).

## 4. Which key for an AOSP preinstalled service

An app built in the AOSP tree is signed by the build. Pick the key with `certificate` in `Android.bp`:

| `certificate` | When | Callers with a `signature` permission |
| --- | --- | --- |
| `"platform"` | The service needs platform signature permissions, `android.uid.system`, or hidden APIs (`platform_apis: true`), e.g. to reach a HAL | Only apps signed with the same platform key, i.e. apps in your image |
| Your own app key | External apps (signed with that key) must bind through a `signature` permission | Apps signed with that key |
| Default (`testkey`) | Bring-up only | Public test key: anyone can sign with it. Never ship it |

```bp
android_app_certificate {
    name: "com.example.pwm.certificate",
    certificate: "keys/pwm",          // keys/pwm.x509.pem + keys/pwm.pk8, relative to this directory
}

android_app {
    name: "PwmControlService",
    srcs: ["src/**/*.kt", "src/**/*.aidl"],
    certificate: "platform",          // or ":com.example.pwm.certificate"
    platform_apis: true,
    privileged: true,                 // /system/priv-app (or system_ext with system_ext_specific: true)
}
```

+ A platform-signed service can still serve apps signed with **other** keys:
  use `signature|knownSigner` with their certificate digests (Android 12+), or a `normal` permission plus the check in section 3
  (as in [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md#63-implementation-in-the-system-app)).
+ **Never give a partner your platform key** to make a `signature` permission work.
  An app signed with it gets every platform signature permission and can join `android.uid.system`.
+ When the image is release-signed with `sign_target_files_apks`, map your custom key too (`-k` / `--extra_apks`);
  see [verify_platformKeys.md](verify_platformKeys.md).
+ An update of the preinstalled app (OTA or `adb install`) must be signed with the same key as the installed version.

## 5. Don't sign one APK with 2 keys

`apksigner` can add several signers (`--next-signer`), but this doesn't combine their privileges:

+ With several signers, Android compares the **whole set** of certificates.
  An APK signed with {own key, platform key} matches neither an app signed with only your key nor the platform (`android`, signed with only the platform key).
  So it gets neither your `signature` permissions nor the platform's, and can't join `android.uid.system`.
+ APK Signature Scheme v3 doesn't support multiple signers, so such an APK carries only v1/v2 signatures and can't use key rotation.

Pick one key per APK with section 4. To accept callers with several keys, put the flexibility on the **service** side
(`knownSigner` or the certificate allowlist), not into the callers' signatures.

## Related notes

+ [sign_apk.md](sign_apk.md): keys, `apksigner`, signature schemes, platform key
+ [sharedUserId.md](sharedUserId.md): signature permissions instead of a shared UID, `knownSigner`
+ [verify_platformKeys.md](verify_platformKeys.md): release keys for an AOSP image
+ [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md)
+ [../HW/pwm_control.md](../HW/pwm_control.md): the PWM system app used as the example
+ [../App/AndroidManifest.md](../App/AndroidManifest.md): protection levels
+ [../App/app_permissions.md](../App/app_permissions.md): permissions overview, runtime requests, troubleshooting

## Reference

+ [Define a custom app permission (`signature`, `knownSigner`)](https://developer.android.com/guide/topics/permissions/defining)
+ [Bound services overview](https://developer.android.com/develop/background-work/services/bound-services)
+ [`PackageManager.hasSigningCertificate()`](https://developer.android.com/reference/android/content/pm/PackageManager#hasSigningCertificate(int,%20byte[],%20int))
+ [Package visibility](https://developer.android.com/training/package-visibility)
+ [Application signing (AOSP)](https://source.android.com/docs/security/features/apksigning)
