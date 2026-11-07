# AndroidManifest.xml

Every Android app (and every library module) has an `AndroidManifest.xml`.
It tells the system and the build tools what the app is, before any of the app's code runs:

+ **Identity**: the application ID (package name) and the version.
+ **Components**: the activities, services, broadcast receivers, and content providers, and which intents they accept.
+ **Permissions**: the permissions the app requests, and the custom permissions it defines to protect its own components.
+ **Requirements**: the hardware and software features it needs, the SDK levels, and the other apps it needs to see.

The package manager reads the manifest at install time. It doesn't run any app code to find components or permissions.

## 1. Where it is, and the merged manifest

In a Gradle project, the manifest is at the root of the module's **source set**, not at the project root:

```text
MyProject/
├── settings.gradle.kts
└── app/
    ├── build.gradle.kts          namespace, applicationId, versionCode, minSdk, targetSdk
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml    main manifest
        │   ├── java/ (or kotlin/)
        │   └── res/
        └── debug/
            └── AndroidManifest.xml    optional: extra entries for the debug build only
```

The APK doesn't contain this file as it is. At build time, the Android Gradle plugin **merges** several manifests into one:

```text
build.gradle.kts values ─┐
build-variant manifests ─┤   (src/debug/, product flavors)
src/main manifest  ──────┼──>  manifest merger  ──>  merged manifest  ──>  binary XML in the APK
library (AAR) manifests ─┘   (dependencies also add permissions and components)
```

+ Values from `build.gradle.kts` replace the ones in the file:
  `applicationId` becomes the `package` attribute of the final manifest, `versionCode` and `versionName` are set on `<manifest>`,
  and `minSdk` and `targetSdk` become `<uses-sdk>`. Don't write them in the source manifest.
+ `namespace` (required since AGP 8) is the package of the generated `R` class.
  Relative component names such as `.MainActivity` resolve against it.
  `applicationId` is the app's identity on the device and on Google Play. The two are often the same, but they don't have to be.
+ Since AGP 8, a `package` attribute in the source manifest is a build error. Use `namespace` instead.
+ Libraries can add permissions you didn't ask for. Check the **Merged Manifest** tab in Android Studio (open `AndroidManifest.xml`, and the tab is at the bottom of the editor).
  To remove one entry, use a merge rule marker in your manifest: `tools:node="remove"`.
+ The manifest can use placeholders such as `${applicationId}`, which the build fills in (section 3).
+ AOSP apps (`android_app` in `Android.bp`) take `AndroidManifest.xml` from the module directory, and there the `package` attribute is still written in the file.
  See [Android_bp_intro.md](Android_bp_intro.md).

Gradle settings: [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md) (section 4). Project layout: [app_project_structure.md](app_project_structure.md).

## 2. Element tree

```text
<manifest>                      xmlns:android, versionCode/versionName (from Gradle)
├── <uses-permission>           permissions the app requests
├── <permission>                custom permissions the app defines
├── <uses-feature>              hardware/software features it needs
├── <uses-sdk>                  minSdk / targetSdk (from Gradle)
├── <queries>                   other apps it needs to see (Android 11+)
└── <application>               app-wide attributes: icon, label, theme, backup, ...
    ├── <activity>              ── <intent-filter> ── <action>, <category>, <data>
    ├── <service>               ── <intent-filter>
    ├── <receiver>              ── <intent-filter>
    ├── <provider>
    ├── <meta-data>             key/value pairs that libraries and the system read
    └── <uses-library>          shared libraries, e.g. org.apache.http.legacy
```

Elements in the `android:` namespace are documented by the platform. `tools:` attributes (`xmlns:tools="http://schemas.android.com/tools"`) only guide the build tools and lint, and are removed from the APK.

## 3. Example

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />            <!-- normal: granted at install -->
    <uses-permission android:name="android.permission.CAMERA" />              <!-- dangerous: also requested at runtime -->

    <!-- The app uses the camera if there is one, but also installs on devices without it -->
    <uses-feature android:name="android.hardware.camera" android:required="false" />

    <!-- Android 11+: other apps this app needs to see -->
    <queries>
        <package android:name="com.example.helper" />
    </queries>

    <application
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:label="@string/app_name"
        android:theme="@style/Theme.MyApplication"
        android:supportsRtl="true"
        android:allowBackup="true"
        android:dataExtractionRules="@xml/data_extraction_rules">

        <!-- Launcher activity: started by the home screen, so it must be exported -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Internal activity: no intent filter, only this app starts it -->
        <activity
            android:name=".SettingsActivity"
            android:exported="false" />

        <!-- Started or bound by this app only -->
        <service
            android:name=".SyncService"
            android:exported="false" />

        <!-- Share files with other apps through content:// URIs -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>

</manifest>
```

## 4. App components

| Component | Element | Started by | Must be declared? |
| --- | --- | --- | --- |
| Activity (a screen) | `<activity>` | `startActivity()`, the launcher, other apps | Yes. An undeclared activity throws `ActivityNotFoundException` |
| Service (background work, or an API for other apps) | `<service>` | `startService()`, `startForegroundService()`, `bindService()` | Yes |
| Broadcast receiver | `<receiver>` | Broadcast intents | No. It can also be registered at runtime with `registerReceiver()` |
| Content provider (shared data) | `<provider>` | `ContentResolver` calls on its `authorities` URI | Yes |

+ Since Android 8 (API 26), receivers declared in the manifest no longer get most **implicit** broadcasts.
  Register at runtime for those, or send an explicit broadcast.
+ Apps that target Android 14 (API 34) must pass `RECEIVER_EXPORTED` or `RECEIVER_NOT_EXPORTED` when they register a receiver at runtime for broadcasts other than system broadcasts.
+ Bound services and providers between apps: [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md), [ContentProvider_sharing.md](ContentProvider_sharing.md).

## 5. Intent filters and `android:exported`

An **intent filter** says which implicit intents a component accepts.
It matches 3 things: `<action>`, `<category>`, and `<data>` (scheme, host, path, MIME type).
`MAIN` + `LAUNCHER` puts an activity in the app drawer.

`android:exported` says whether **other apps** can start the component:

+ For apps that target **Android 12 (API 31) or higher**, every activity, service, and receiver that has an intent filter must set `android:exported` explicitly.
  Otherwise the build reports a manifest merger error, and the install fails with `INSTALL_PARSE_FAILED_MANIFEST_MALFORMED`.
+ Without an intent filter, the default is `false`.
+ An intent filter isn't a security boundary.
  An exported component can be started with an **explicit** intent, whatever its filter says.
  Protect exported components with `android:permission` (section 6), and set `exported="false"` for everything that is internal.

## 6. Permissions

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />

<!-- A custom permission that only apps signed with the same key can hold -->
<permission
    android:name="com.example.app.permission.BIND_SERVICE"
    android:protectionLevel="signature" />
```

| Protection level | Granted | Examples |
| --- | --- | --- |
| `normal` | At install, automatically | `INTERNET`, `VIBRATE` |
| `dangerous` | At runtime: the user must accept a dialog (Android 6, API 23+). Declare it here **and** call `requestPermissions()` | `CAMERA`, `ACCESS_FINE_LOCATION` |
| `signature` | At install, if the app is signed with the same certificate as the app that defines the permission | Custom permissions between your own apps |
| `signature\|privileged` | Same signature, or a privileged system app allowlisted in `privapp-permissions-*.xml` | `REBOOT`, `SET_TIME_ZONE` (system apps only) |

+ `maxSdkVersion` requests a permission only on older releases, where it is still needed.
+ Declaring a permission in the manifest doesn't grant a `dangerous` one. The runtime request is still needed.
+ Custom permissions to protect a service or provider: [sharedUserId.md](sharedUserId.md#51-limit-access-to-your-own-apps-signature-permissions),
  [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md).

## 7. Features and SDK levels

+ `<uses-feature>` declares hardware or software the app uses (`android.hardware.camera`, `android.hardware.bluetooth_le`, ...).
  Google Play hides the app from devices that don't have a feature marked `android:required="true"` (the default).
  The package manager itself doesn't check it at install time.
+ Some permissions **imply** a required feature: `CAMERA` implies `android.hardware.camera`.
  Add `<uses-feature ... android:required="false" />` if the app should also install on devices without one,
  and check at runtime with `PackageManager.hasSystemFeature()`.
  The features a device has: `adb shell pm list features`.
+ `minSdk` is the lowest Android version the app installs on.
  `targetSdk` is the version the app was tested against: the system turns on the behavior changes of each newer release only for apps that target it.
  Both are set in Gradle (section 1).

## 8. Package visibility: `<queries>` (Android 11+)

Apps that target Android 11 (API 30) or higher only see a filtered list of other installed apps.
`getPackageInfo()`, `queryIntentActivities()`, and `bindService()` to an app it can't see behave as if that app weren't installed.
Declare the apps or intents the app needs to see:

```xml
<queries>
    <package android:name="com.example.helper" />                 <!-- one specific app -->
    <intent>
        <action android:name="android.intent.action.SEND" />      <!-- any app that handles this intent -->
        <data android:mimeType="image/*" />
    </intent>
</queries>
```

`QUERY_ALL_PACKAGES` sees every app, but Google Play only allows it for a few kinds of apps.

## 9. Inspect the manifest

```shell
# Built APK (SDK build-tools / cmdline-tools)
aapt2 dump badging app.apk                                    # package, version, SDK levels, permissions, launcher activity
aapt2 dump xmltree app.apk --file AndroidManifest.xml         # the whole binary manifest as a tree
apkanalyzer manifest print app.apk                            # decoded XML

# Installed app
adb shell dumpsys package com.example.app                     # versions, granted permissions, components, intent filters
adb shell pm dump com.example.app | grep -A3 'android.intent.action.MAIN'
```

More `aapt2` commands: [aapt_note.md](aapt_note.md). `dumpsys` and `pm`: [adb_shell_cmds.md](adb_shell_cmds.md).

## Related notes

+ [app_project_structure.md](app_project_structure.md), [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md), [Android_bp_intro.md](Android_bp_intro.md), [jar_aar_intro.md](jar_aar_intro.md)
+ [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md), [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md), [ContentProvider_sharing.md](ContentProvider_sharing.md)
+ [sharedUserId.md](sharedUserId.md), [sign_apk.md](sign_apk.md), [aapt_note.md](aapt_note.md), [adb_shell_cmds.md](adb_shell_cmds.md)

## Reference

+ [App manifest overview](https://developer.android.com/guide/topics/manifest/manifest-intro)
+ [Merge multiple manifest files](https://developer.android.com/build/manage-manifests)
+ [Configure the app module: namespace and application ID](https://developer.android.com/build/configure-app-module)
+ [Intents and intent filters](https://developer.android.com/guide/components/intents-filters)
+ [`<activity>` element, including `android:exported`](https://developer.android.com/guide/topics/manifest/activity-element)
+ [Permissions on Android](https://developer.android.com/guide/topics/permissions/overview)
+ [`<uses-feature>` element](https://developer.android.com/guide/topics/manifest/uses-feature-element)
+ [Package visibility](https://developer.android.com/training/package-visibility)
