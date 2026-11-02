# aapt / aapt2 - Android Asset Packaging Tool

Both tools ship in the Android SDK under `build-tools/<version>/`.
**aapt** is the legacy tool; **aapt2** is its replacement, so prefer aapt2 when it is available.

## 1. Quick reference: what do I want to know?

| Goal | aapt2 (preferred) | aapt (legacy) |
| --- | --- | --- |
| Package name | `aapt2 dump packagename xxx.apk` | `aapt dump badging xxx.apk \| grep "package:"` |
| Version, SDK versions, launcher activity (summary) | `aapt2 dump badging xxx.apk` | `aapt dump badging xxx.apk` |
| Min / target SDK | `aapt2 dump badging xxx.apk \| grep -E "sdkVersion\|targetSdkVersion"` | same command with `aapt` |
| Permissions | `aapt2 dump permissions xxx.apk` | `aapt dump permissions xxx.apk` |
| Manifest as a tree | `aapt2 dump xmltree xxx.apk --file AndroidManifest.xml` | `aapt dump xmltree xxx.apk AndroidManifest.xml` |
| Resource string pool | `aapt2 dump strings xxx.apk` | (not covered here) |
| List archive contents | (no `list` subcommand; use `unzip -l xxx.apk`) | `aapt list xxx.apk` |

## 2. Subcommands explained

+ **badging**: prints information extracted from the APK's manifest (package name, version, SDK versions, permissions, launchable activity, and so on). It is the best single command for a quick overview.
+ **packagename**: prints the APK's package name (aapt2 only).
+ **permissions**: prints the permissions requested in the manifest.
+ **xmltree**: prints a compiled XML file inside the APK as a tree. `AndroidManifest.xml` is the usual target.
+ **strings**: prints the contents of the APK's resource table string pool (aapt2 only).
+ **list**: lists the contents of a Zip-compatible archive (aapt only). Add `-a` to also print manifest and resource info.

## 3. Syntax differences

+ aapt: `aapt <command> [options] <file.apk> [files...]`. The file inside the APK is a **positional** argument.
+ aapt2: `aapt2 [compile|link|dump|diff|optimize|convert|version] [options] files`. For `dump xmltree`, the file inside the APK is passed with `--file`.

## 4. Alternative: min SDK with aapt only

`aapt list -a xxx.apk | grep minSdkVersion` also works, but it dumps the whole archive listing plus manifest and resource info before filtering.
`dump badging` (section 1) is cleaner.

## Reference

[aapt2 documentation](https://developer.android.com/tools/aapt2)
