# Signature vs. privileged permissions (Android 14, RK3566)

On Android 14 (AOSP, and Rockchip RK3566 BSP builds based on it), **signature** and **privileged** permissions both give system-level access,
but they decide trust differently: by the **signing key** or by the **install location** plus an allowlist.

In the manifest, `signature` is a base `protectionLevel`, and `privileged` is a flag added to it.
The usual combination is `signature|privileged` (the deprecated spelling is `signatureOrSystem`).
It is an **or**: an app gets the permission either through a matching certificate, or as an allowlisted privileged app.
The full list of base types and flags is in [../App/app_permissions.md](../App/app_permissions.md#11-base-types-and-flags).

## 1. Key differences

| Aspect | `signature` | `privileged` flag (`signature\|privileged`) |
| --- | --- | --- |
| Trust basis | The app's **signing certificate** matches the certificate of the app that defines the permission (for framework permissions: the platform key) | The app is preinstalled in a **`priv-app`** directory (`/system/priv-app`, `/system_ext/priv-app`, `/product/priv-app`, `/vendor/priv-app`) **and** listed in a `privapp-permissions` allowlist |
| Where the APK can live | Anywhere: preinstalled on the image or installed in `/data/app`, as long as the key matches | The base APK must be in `priv-app` on a read-only partition. An app in `/system/app` or a plain `/data/app` install gets no privileged grants |
| App updates | An update signed with the same key keeps the grant | An update of a priv-app (installed in `/data/app`) stays privileged, but gets only the privileged permissions that the **preinstalled** version requested and that are allowlisted (section 4.2) |
| Enforcement | `PackageManagerService` / `PermissionManagerService` compare certificates at install | `privapp-permissions-*.xml` in `/<partition>/etc/permissions/`. With `ro.control_privapp_permissions=enforce` (the default on current devices) a missing entry stops the device from booting |

Current releases also have a **signature permission allowlist**:
a platform-signed app that is **not** part of the system image (for example installed in `/data/app`)
must be listed before it is granted platform `signature` permissions. Check the AOSP permissions pages under Reference for the details of your release.

How to add a priv-app and its allowlist with `Android.bp`: [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md#23-privileged-permissions-allowlist).

## 2. Typical use cases on RK3566 products

RK3566 boards often run custom Android 14 images for smart displays, industrial panels, kiosks, and gateways,
where your own system apps talk to the hardware and to OS services.

### 2.1 Signature permissions

+ **Your own app suite:** 2 or more apps signed with your release key share a custom `signature` permission,
  so a background or hardware service accepts bindings only from your apps ([signature_permission.md](signature_permission.md)).
+ **Platform-signed companion apps:** an APK signed with the board's `platform` key gets platform `signature` permissions
  without being in `priv-app`. If it is installed in `/data/app` on a `user` build, check the signature permission allowlist (section 1).
+ **Protected bound services:** only callers with a matching certificate can bind to the service.

### 2.2 Privileged permissions

+ **Kiosk and device control:** a preinstalled launcher, device-owner/MDM, or kiosk app in `priv-app` that reboots the device,
  installs packages silently, or changes system settings (`WRITE_SECURE_SETTINGS`).
+ **Hardware integration:** your system app for the industrial UI, display control, or factory tests,
  built with `privileged: true` in `Android.bp` (`LOCAL_PRIVILEGED_MODULE := true` in `Android.mk`) and a matching `privapp-permissions` entry.
  The hardware itself is reached through a system service or HAL over Binder, not by opening device nodes from the app.
+ **Preconfigured appliances:** OEM components that must work out of the box, without permission prompts, on a locked-down device.

## 3. Where apps live

| Kind | Location | Note |
| --- | --- | --- |
| User-installed app (Play Store, `adb install`, your own installer) | `/data/app/<random>/<package>-<random>/base.apk` | Runtime data in `/data/data/<package>/` (`/data/user/<id>/<package>/`) |
| Privileged system app | `/system/priv-app/`, `/system_ext/priv-app/`, `/product/priv-app/`, `/vendor/priv-app/` | Settings, SystemUI, your kiosk controller |
| Ordinary system app | `/system/app/`, `/system_ext/app/`, `/product/app/`, `/vendor/app/` | Preinstalled tools such as Calculator or DeskClock |

Check an app on the device:

```shell
adb shell pm path com.example.myapp                    # base.apk path(s); 2 lines after an update of a system app
adb shell dumpsys package com.example.myapp | grep -E 'codePath|pkgFlags|privateFlags'
# pkgFlags contains SYSTEM (and UPDATED_SYSTEM_APP after an update); privateFlags contains PRIVILEGED for a priv-app
```

## 4. Updating apps

### 4.1 Rules for every update

1. **Same package name** (`applicationId`, e.g. `com.example.myapp`).
2. **Same signing certificate**, or a valid key rotation proof (APK Signature Scheme v3).
   A system app signed with the platform key can only be updated by an APK signed with the same platform key.
3. **`versionCode` not lower** than the installed one. Downgrades are rejected (except `adb install -d` for debuggable apps or builds).

A user-installed app in `/data/app` is simply replaced by the new version.

A preinstalled app can also be updated, but the system partitions are read-only, so the original APK stays:

1. The update is installed in `/data`, like a user app.
2. `PackageManager` uses the `/data` copy instead of the preinstalled one (the app is flagged `UPDATED_SYSTEM_APP`).
3. **Settings > Apps > Uninstall updates** (or `adb shell pm uninstall com.example.myapp` without `--user`) deletes the `/data` copy,
   and the app falls back to the version on the image.

### 4.2 Privileged apps

An update of a priv-app keeps its privileged status, but it **can't add new privileged permissions**.
It gets only the ones that the preinstalled version requests and that are in the `privapp-permissions` allowlist built into the image.
To add a privileged permission, change the app **and** the allowlist in the image, then ship a new system image (OTA).

## 5. Tips for RK3566 Android 14 builds

+ Test `user` builds early, not only `userdebug`: allowlist or signing problems that `userdebug` tolerates can stop a `user` image from booting.
+ Add each new privileged permission to the app's `privapp-permissions` file in the same change, and declare custom permissions as `signature|privileged`, not `signatureOrSystem`.
+ Ship with your own keys, not the AOSP test keys: [aosp_release_keys.md](aosp_release_keys.md).

## Related notes

+ [../App/app_permissions.md](../App/app_permissions.md): protection levels, flags, and `privapp-permissions`
+ [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md): add a priv-app and its allowlist
+ [signature_permission.md](signature_permission.md): restrict who can bind a service
+ [sign_apk.md](sign_apk.md): what the platform key gives an app
+ [aosp_release_keys.md](aosp_release_keys.md): platform key classes and release signing

## Reference

+ [Permissions overview (AOSP)](https://source.android.com/docs/core/permissions)
+ [Privileged permission allowlisting (AOSP)](https://source.android.com/docs/core/permissions/perms-allowlist)
+ [Permissions on Android (developer.android.com)](https://developer.android.com/guide/topics/permissions/overview)
+ [`<permission>` element, `protectionLevel`](https://developer.android.com/guide/topics/manifest/permission-element)
