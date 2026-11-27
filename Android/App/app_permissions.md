# Android permissions: overview

In Android, a **permission** controls whether an app may use restricted system APIs, sensitive user data, hardware,
or components exposed by other apps. An app can't freely read contacts, turn on the camera, or bind to another app's service.
A permission must be **declared**, **granted** (at install, at runtime by the user, or because of the app's signature or location in the image),
and **checked** when it is used.

Permissions have 2 sides:

+ **Requesting** a permission (`<uses-permission>`): the app asks for access to a capability or to another app's component.
+ **Defining and enforcing** a permission (`<permission>` + `android:permission`): an app or the platform defines a permission
  to protect its own exported `Service`, `Activity`, `BroadcastReceiver`, or `ContentProvider` from unauthorized callers.

This note is the overview. Details are in the notes linked from each section.

## 1. Protection levels

`android:protectionLevel` says how risky a permission is, and so how it is granted:

| Protection level | How it is granted | Examples |
| --- | --- | --- |
| `normal` | At install, automatically, no prompt | `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `WAKE_LOCK` |
| `dangerous` (runtime) | At runtime: the user accepts a dialog (Android 6, API 23+). Needs `<uses-permission>` **and** a runtime request | `CAMERA`, `ACCESS_FINE_LOCATION`, `RECORD_AUDIO`, `READ_CONTACTS`, `READ_MEDIA_IMAGES` |
| `signature` | At install, only if the requesting app is signed with the **same certificate** as the app that defines the permission | Custom permissions between your own apps; platform permissions for platform-signed apps |
| `signature\|privileged` | Same certificate as the defining app, **or** a privileged app (`/system/priv-app`, `/product/priv-app`, ...) that is listed in a `privapp-permissions` allowlist | `REBOOT`, `SET_TIME_ZONE` (system apps only) |

+ `signature|privileged` is an **or**: a platform-signed app gets it through its signature;
  an app signed with another key gets it only from a privileged location **and** the allowlist.
+ Some permissions aren't granted by either way and need the user to turn them on in Settings
  (special app access, e.g. `SYSTEM_ALERT_WINDOW`, `MANAGE_EXTERNAL_STORAGE`). These carry the `appop` flag (section 1.1).

The full table with more manifest details is in [AndroidManifest.md](AndroidManifest.md#6-permissions).

### 1.1 Base types and flags

A `protectionLevel` is one **base type**, optionally followed by **flags** joined with `|`.
Each flag adds another way to get the permission. The app needs to meet only one of them, which is why `signature|privileged` is an **or**.

The base types are `normal`, `dangerous`, `signature`, and `internal` (Android 12, API 31+).
An `internal` permission is granted only through its flags, for example `internal|role`.

| Flag | Also grants the permission to | Note |
| --- | --- | --- |
| `privileged` | A privileged app listed in a `privapp-permissions` allowlist (section 5) | Old name `system`; `signatureOrSystem` is the deprecated spelling of `signature\|privileged` |
| `knownSigner` | Apps whose certificate digest is in `android:knownCerts` (Android 12+) | [../Signing/signature_permission.md](../Signing/signature_permission.md) |
| `role` | The app that holds a given role (Android 10+), such as the default dialer | |
| `appop` | Apps whose app op is allowed, usually by the user on the special app access screen | `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW` |
| `development` | Any app that requests it, by `adb shell pm grant` | For development and testing |
| `installer` | The system package installer | |
| `preinstalled` | Any app preinstalled on the system image, privileged or not | |
| `pre23` | Apps that target API 22 or lower | Legacy |
| `setup` | The setup wizard | |

The exact level of a framework permission is in `frameworks/base/core/res/AndroidManifest.xml`, or on the device with `adb shell dumpsys package permission <name>`.

## 2. Request a permission

Declare every permission the app needs in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />   <!-- normal -->
<uses-permission android:name="android.permission.CAMERA" />              <!-- dangerous -->
```

+ For a **normal** permission, the `<uses-permission>` entry is enough.
+ For a **dangerous** permission, the app must also request it at runtime and handle a denial:

```kotlin
class CameraActivity : AppCompatActivity() {

    private val requestCamera =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) openCamera() else showCameraUnavailable()
        }

    private fun startCamera() {
        when {
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED -> openCamera()
            shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) -> showRationaleThenRequest()
            else -> requestCamera.launch(Manifest.permission.CAMERA)
        }
    }

    // openCamera(), showCameraUnavailable(), showRationaleThenRequest() are app code
}
```

+ Register the launcher (`registerForActivityResult`) as a field, before the activity is started, not inside a click handler.
+ Since Android 11, if the user denies the same permission twice, the system stops showing the dialog ("don't ask again").
  `launch()` then returns `false` immediately; send the user to **Settings → Apps → [app] → Permissions**.

## 3. Protect an exported component

To restrict which apps can bind to an exported service (e.g. an AIDL service), define a custom permission
and set it on the component with `android:permission`:

```xml
<permission
    android:name="com.example.hw.permission.ACCESS_HW_SERVICE"
    android:protectionLevel="signature" />

<application>
    <service
        android:name=".HardwareControlService"
        android:exported="true"
        android:permission="com.example.hw.permission.ACCESS_HW_SERVICE" />
</application>
```

A caller app must declare `<uses-permission android:name="com.example.hw.permission.ACCESS_HW_SERVICE" />`
and be signed with the same key; otherwise `bindService()` fails with a `SecurityException`.
On Android 11+ it also needs a `<queries>` entry to see the service app.

Which key to sign with, `signature|knownSigner` for callers with other keys, and install-order pitfalls:
[../Signing/signature_permission.md](../Signing/signature_permission.md).

## 4. Check the caller inside a service

A permission on `<service>` is checked once, at bind time. If AIDL methods need different privileges,
check in **each method** (inside the Binder call, not in `onBind()`):

```kotlin
override fun setOutput(value: Int) {
    // Throws SecurityException to the caller if the calling app doesn't hold the permission
    enforceCallingPermission("com.example.hw.permission.CONTROL_HW", "setOutput")
    // ...
}
```

+ `enforceCallingPermission()` throws; `checkCallingPermission()` returns `PERMISSION_GRANTED` or `PERMISSION_DENIED`.
+ Avoid the `...OrSelf...` variants in a Binder method: they also pass when the **service itself** holds the permission,
  so any caller would get through if the service app requests the permission too.
+ To allow only specific developers, compare the caller's signing certificate:
  [../Signing/signature_permission.md](../Signing/signature_permission.md#3-caller-check-inside-the-service).

## 5. Privileged permissions on AOSP (`privapp-permissions`)

A privileged app (`privileged: true` → `/system/priv-app`, `/product/priv-app`, `/system_ext/priv-app`)
that requests a `privileged` permission must be listed in a `privapp-permissions` XML allowlist
on the **same partition** (e.g. `/product/etc/permissions/`):

```xml
<permissions>
    <privapp-permissions package="com.example.myapp">
        <permission name="android.permission.REBOOT" />
    </privapp-permissions>
</permissions>
```

With `ro.control_privapp_permissions=enforce` (the default on current devices), a missing entry stops the device from booting.
How to install the allowlist with `Android.bp`: [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md#23-privileged-permissions-allowlist).

## 6. Debug and troubleshooting

```shell
adb shell dumpsys package com.example.app | grep -A30 "permissions:"   # requested, install and runtime permissions, granted=true/false
adb shell pm grant com.example.app android.permission.CAMERA            # grant a runtime permission (development)
adb shell pm revoke com.example.app android.permission.CAMERA
adb shell pm list permissions -g -d                                     # dangerous permissions by group
```

| Symptom | Check |
| --- | --- |
| `SecurityException: Permission Denial` | `<uses-permission>` missing in the **caller's** manifest; runtime permission not granted yet; `signature` permission with a key mismatch (debug vs. release key); missing `privapp-permissions` entry |
| Dialog no longer appears | The user denied it twice (Android 11+). Send them to Settings; `shouldShowRequestPermissionRationale()` tells you whether to show an explanation first |
| Custom permission not granted although keys match | The caller was installed before the app that defines the permission; see [../Signing/signature_permission.md](../Signing/signature_permission.md#2-signature-permission-what-same-key-means) |
| Device doesn't boot after adding a priv-app | Missing allowlist entry; the boot log names the permissions that are not in the `privapp-permissions` allowlist |

More `pm` and `dumpsys` commands: [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md#2-pm-packages-and-permissions).

## Related notes

+ [AndroidManifest.md](AndroidManifest.md): `<uses-permission>`, `<permission>`, `android:exported`, `<queries>`
+ [../Signing/signature_permission.md](../Signing/signature_permission.md): signature permissions, caller checks, which key to sign with
+ [../Signing/sharedUserId.md](../Signing/sharedUserId.md): `knownSigner`, signature permissions instead of a shared UID
+ [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md): priv-app and the `privapp-permissions` allowlist
+ [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md): protected bound services
+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md): `pm grant`, `dumpsys package`

## Reference

+ [Permissions on Android](https://developer.android.com/guide/topics/permissions/overview)
+ [Request runtime permissions](https://developer.android.com/training/permissions/requesting)
+ [Define a custom app permission](https://developer.android.com/guide/topics/permissions/defining)
+ [`<permission>` element and `protectionLevel`](https://developer.android.com/guide/topics/manifest/permission-element)
+ [Privileged permission allowlisting (AOSP)](https://source.android.com/docs/core/permissions/perms-allowlist)
