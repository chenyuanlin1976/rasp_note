# neverallow errors

A **neverallow** error is an SELinux **build-time** failure. A `neverallow` rule is an assertion:
"no policy may ever grant this".
AOSP ships thousands of them in `system/sepolicy`, and CTS checks them again on the device.
If your `.te` file grants something that a `neverallow` forbids, the policy build stops.

## 1. What the error looks like

```text
libsepol.report_failure: neverallow on line 1093 of system/sepolicy/public/domain.te
  (or line 41023 of policy.conf) violated by allow my_app sysfs_leds:file { write open };
libsepol.check_assertions: 1 neverallow failures occurred
```

+ `violated by allow ...` shows the effective rule that your policy produced.
  It may come from a macro or from an attribute that your type belongs to.
+ The file and line point to the `neverallow`. Read that rule and the comment above it,
  because the comment explains *why* the access is forbidden.

The fix is always to **change the design or narrow the rule**.
Never edit or delete a `neverallow` in `system/sepolicy`: the device would then fail CTS,
and the build may check the rules again anyway.

## 2. Classic case: LED (sysfs) control from an app

Typical story: an app writes to `/sys/class/leds/...`, gets an `avc: denied`,
and someone adds `allow untrusted_app sysfs:file write;` (or a similar rule for `platform_app`).
The build then fails, because app domains may not write generic sysfs or device nodes.

**Correct architecture**:

```text
App --Binder (AIDL)--> LED HAL / system service (own domain) --write--> /sys/class/leds/<led>/brightness
                                                      ^ only this domain may write the specifically-labeled sysfs file
```

### Step 1: Put the hardware access in a service

Define an AIDL interface and implement it in a native service or a vendor HAL
(`@VintfStability`, stable AIDL) that runs in its **own domain**.
The app calls the service; it never touches sysfs.
Examples: [AIDL_ndk_led_sysfs.md](AIDL_ndk_led_sysfs.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md).

### Step 2: Label exactly the files the service needs

sysfs is a pseudo filesystem, so `file_contexts` does **not** label it. Use `genfs_contexts`, with the **real path**
under `/sys/devices/...` (`/sys/class/leds/x` is only a symlink to it):

```shell
adb shell readlink -f /sys/class/leds/my_led     # -> /sys/devices/platform/leds/leds/my_led
```

```text
# vendor/.../sepolicy/vendor/file.te
type sysfs_my_led, sysfs_type, fs_type;

# vendor/.../sepolicy/vendor/genfs_contexts
genfscon sysfs /devices/platform/leds/leds/my_led    u:object_r:sysfs_my_led:s0

# vendor/.../sepolicy/vendor/hal_myled.te   (only the LED service's domain)
allow hal_myled_default sysfs_my_led:dir r_dir_perms;
allow hal_myled_default sysfs_my_led:file rw_file_perms;
```

AOSP already has a public type `sysfs_leds` for LED class nodes. A device-specific type like the one above keeps the grant narrower.

The DAC owner and mode of the sysfs files are set in `ueventd.rc` (see [HAL_sysfsNodes.md](HAL_sysfsNodes.md)).

## 3. Other neverallow rules you will hit

### 3.1 Vendor ↔ system boundary (Treble)

+ **Properties**: vendor code may not set, and often may not read, the platform's internal properties (e.g. `persist.sys.*`).
  Use vendor-prefixed properties (`vendor.`, `persist.vendor.`, `ro.vendor.`)
  and declare them with `vendor_internal_prop(...)` / `vendor_public_prop(...)` plus `property_contexts`.
+ **Files**: vendor domains may not access core `/data` types, such as `app_data_file` or `system_data_file`.
  Keep vendor data in `/data/vendor/...` with your own type.
+ **IPC**: vendor and core processes may not talk over raw sockets or arbitrary Binder.
  Cross-partition calls must go through a declared **stable AIDL HAL** (`hal_client_domain` / `hal_server_domain`).
  `vndbinder` is for vendor ↔ vendor only, and it is deprecated since Android 11.

### 3.2 Apps executing code from writable storage

Apps that target API 29+ may not `execute` files from their own writable data directory (`app_data_file`);
this is the W^X rule.
Native executables must be shipped as libraries in the APK (`nativeLibraryDir`, read-only),
and `su` does not exist on user builds.
Put privileged logic in a service and call it over Binder; don't run helper binaries.

### 3.3 Generic labels and broad grants

Rules on catch-all types (`device`, `block_device`, `sysfs`, `proc`, `default_prop`, `default_service`, `unlabeled`) are blocked for most domains.
So are wide grants such as `allow x domain:process *;` (for example `ptrace` on other domains).
Fix: give the object a **specific label**, and grant only the needed permissions, with `rw_file_perms`-style macros.

### 3.4 Security-critical operations

Only specific domains may do certain things:

+ load policy or change enforcing mode (`kernel:security` → `init` only)
+ load kernel modules
+ use raw block devices (`vold`, `init`, ...)
+ access keystore, keymint, or radio internals

If your rule touches these, the feature belongs in (or behind) the domain that already owns that responsibility.

## Related notes

+ [avc_denied.md](avc_denied.md): runtime denials (the step before a neverallow usually appears)
+ [SELinux_policy.md](SELinux_policy.md), [SELinux_intro.md](SELinux_intro.md)
+ [AIDL_ndk_led_sysfs.md](AIDL_ndk_led_sysfs.md), [HAL_sysfsNodes.md](HAL_sysfsNodes.md)

## Reference

+ [Customizing SELinux: neverallow rules (AOSP)](https://source.android.com/docs/security/features/selinux/customize)
+ [`system/sepolicy` source](https://android.googlesource.com/platform/system/sepolicy/)
