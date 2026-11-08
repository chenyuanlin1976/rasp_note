# Preinstalled apps in an AOSP build

This note covers how to add an app to an AOSP system image, where it gets installed, and how to remove an app that the base product already includes.
It applies to a platform build (`lunch` + `m`), not to Android Studio projects.

## 1. Where preinstalled apps live

The build installs each app under `out/target/product/<device>/<partition>/`, then packs that directory into the partition image (`system.img`, `system_ext.img`, `product.img`, `vendor.img`; on newer devices these are inside `super.img`).

| Path on the device | Soong property | Typical use |
| --- | --- | --- |
| `/system/app/<Name>/<Name>.apk` | (none) | Platform apps from AOSP |
| `/system/priv-app/<Name>/<Name>.apk` | `privileged: true` | Platform apps that need privileged permissions (e.g. `SettingsProvider`) |
| `/system_ext/app/`, `/system_ext/priv-app/` | `system_ext_specific: true` | Platform-adjacent apps (e.g. `SystemUI`, `Settings` on current releases) |
| `/product/app/`, `/product/priv-app/` | `product_specific: true` | OEM or product apps (the usual choice for your own apps) |
| `/vendor/app/` | `vendor: true` | Apps tied to the SoC/hardware |

`priv-app` gives the app access to `privileged` permissions (`signature|privileged`), but only the ones listed in a `privapp-permissions` allowlist (section 2.3).
Since Treble, the partitions are updated separately, so put your apps in `/product` or `/system_ext` rather than `/system`.

All preinstalled apps are **system apps**: a factory reset doesn't remove them, and a user can only disable them or remove their updates.

## 2. Add an app

### 2.1 Prebuilt APK: `android_app_import`

Put the APK and an `Android.bp` in a directory such as `vendor/<company>/apps/MyApp/`:

```bp
android_app_import {
    name: "MyApp",
    apk: "MyApp.apk",
    presigned: true,            // keep the APK's own signature
    // certificate: "platform", // or: re-sign it with a key from the build instead of presigned
    product_specific: true,     // install in /product
    privileged: true,           // /product/priv-app; remove for /product/app
    required: ["privapp_allowlist_com.example.myapp.xml"],
}
```

+ Use `presigned: true` for a third-party APK. Its updates (e.g. from Play) must then be signed with the same key.
+ Use `certificate: "platform"` only for your own app that needs the platform signature; see [../Signing/sign_apk.md](../Signing/sign_apk.md).
+ An APK with `presigned: true` must be signed already. The build doesn't check whether the signature fits your device's keys.

### 2.2 App built from source: `android_app`

Put the source and an `Android.bp` in `packages/apps/<Name>/` or `vendor/<company>/apps/<Name>/`.
An example is in [../Build/Android_bp_intro.md](../Build/Android_bp_intro.md) (section 3).
`Android.mk` (`include $(BUILD_PREBUILT)` / `BUILD_PACKAGE`) still works, but new modules should use `Android.bp`.

### 2.3 Privileged permissions allowlist

A privileged app that requests a `privileged` permission needs an allowlist file **on the same partition** as the app.
With `ro.control_privapp_permissions=enforce` (the default on current devices), a missing entry stops the device from booting.

```xml
<!-- vendor/<company>/apps/MyApp/privapp_allowlist_com.example.myapp.xml -->
<permissions>
    <privapp-permissions package="com.example.myapp">
        <permission name="android.permission.REBOOT" />
    </privapp-permissions>
</permissions>
```

```bp
prebuilt_etc {
    name: "privapp_allowlist_com.example.myapp.xml",
    src: "privapp_allowlist_com.example.myapp.xml",
    sub_dir: "permissions",     // -> /product/etc/permissions/
    product_specific: true,     // same partition as the app
}
```

### 2.4 Add the module to the product

A module is only installed if the product asks for it, in the device or product makefile (`device/<vendor>/<board>/<product>.mk`):

```text
PRODUCT_PACKAGES += \
    MyApp
```

`required` modules (here, the allowlist) are pulled in automatically.

## 3. Remove an app from the base product

### 3.1 Find where it comes from

Most AOSP apps are added by the inherited product makefiles (`build/make/target/product/*.mk`, e.g. `handheld_product.mk`), not by your device makefile.

```shell
grep -rn --include=*.mk "UnwantedApp" build/make/target/product device/ vendor/
grep -A8 '"UnwantedApp"' out/target/product/<device>/module-info.json     # module path and install path (after a build)
```

Another module can also pull it in through `required` (`LOCAL_REQUIRED_MODULES` in `Android.mk`).

### 3.2 Remove it

| Situation | What to do |
| --- | --- |
| Listed in your own makefiles | Delete it from `PRODUCT_PACKAGES` |
| Your app replaces it (e.g. your launcher replaces `Launcher3`) | Add `overrides: ["Launcher3"]` to your app's module, so the build installs yours instead |
| Inherited from an AOSP makefile you don't want to edit | Inherit a smaller base product, or use `overrides` from one of your modules |

Avoid editing files under `build/make/target/product/` directly; the change is lost on the next AOSP update.

### 3.3 Preinstalled-packages allowlist (per user type)

Since Android 11, `/system/etc/sysconfig/preinstalled-packages-*.xml` files decide **which user types** (full user, profile, guest, ...) get each system app.
They don't add or remove the APK itself, so editing them is not a way to remove an app from the image.

```xml
<install-in-user-type package="com.example.myapp">
    <install-in user-type="FULL" />
    <install-in user-type="PROFILE" />
</install-in-user-type>
```

### 3.4 Rebuild

You don't need `m clobber`. Current builds delete installed files of modules that are no longer in the product.
If an old APK still shows up in `out/target/product/<device>/`, run `m installclean`, which is much faster than a full clean.

```shell
m                                                                   # or: m installclean && m
ls out/target/product/<device>/product/priv-app/                     # check before flashing
```

## 4. Verify on the device

```shell
adb shell pm list packages -s | grep myapp          # -s: system packages only
adb shell pm path com.example.myapp                 # /product/priv-app/MyApp/MyApp.apk
adb shell dumpsys package com.example.myapp | grep -E "codePath|flags|privateFlags"   # PRIVILEGED in privateFlags
adb shell dumpsys package com.example.myapp | grep -A20 "install permissions"          # granted privileged permissions
```

## 5. Comments

+ **Pick the partition on purpose.** `/product` for OEM apps, `/system_ext` for apps tied to the platform build, `/vendor` only for hardware-specific apps. Avoid `/system` for your own apps.
+ **Use `priv-app` only when needed.** Most apps work fine in `app/`. A privileged app needs an allowlist that must be kept in sync with its manifest, or the device won't boot.
+ **Signing decides updates.** A preinstalled app can be updated from `/data/app` only with an APK signed by the same key. Choose between `presigned` and `certificate` with that in mind.
+ **For quick tests, skip the full build.** On a `userdebug` build, `adb root && adb remount`, push the APK into `/product/priv-app/MyApp/` and reboot. Do it properly in the build afterwards. (With verified boot, `adb remount` may first need `adb disable-verity` and a reboot.)
+ **"Removing" on a running device is not removing.** `pm uninstall --user 0 <pkg>` only hides the app for user 0; the APK stays in the image, and a factory reset brings it back.

## Related notes

+ [../Build/Android_bp_intro.md](../Build/Android_bp_intro.md): `android_app`, partition properties
+ [../Build/AOSP_build.md](../Build/AOSP_build.md), [../Build/AOSP_build_system.md](../Build/AOSP_build_system.md), [../Build/AOSP_envsetup_cmds.md](../Build/AOSP_envsetup_cmds.md)
+ [../Signing/sign_apk.md](../Signing/sign_apk.md), [../Signing/verify_platformKeys.md](../Signing/verify_platformKeys.md): app and platform keys
+ [../App/AndroidManifest.md](../App/AndroidManifest.md): `signature|privileged` permissions
+ [../Signing/sharedUserId.md](../Signing/sharedUserId.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md): a privileged system app that exposes a service

## Reference

+ [Privileged permission allowlisting (source.android.com)](https://source.android.com/docs/core/permissions/perms-allowlist)
+ [Product partitions (source.android.com)](https://source.android.com/docs/core/architecture/partitions/product-partitions)
+ [Soong build system (source.android.com)](https://source.android.com/docs/setup/build)
