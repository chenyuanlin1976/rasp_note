# Native daemons on Android

A native daemon is a long-running background process written in C, C++, or Rust. It runs **outside ART** (no Java runtime).
`init` starts it from an `.rc` file, gives it a UID/GID and capabilities, and runs it in its own SELinux domain.
Other processes reach it through Binder (AIDL), or occasionally a socket or system properties.

Examples in AOSP: `servicemanager`, `surfaceflinger`, `logd`, `vold`, `netd`, `installd`, and the vendor HAL processes in `/vendor/bin/hw/`.
(Binder itself is a kernel driver, not a daemon; see [Binder_intro.md](Binder_intro.md).)

## 1. Where it lives

| Partition | Path | For |
| --- | --- | --- |
| `system` | `/system/bin/`, `.rc` in `/system/etc/init/` | Platform daemons from AOSP |
| `system_ext` / `product` | `/system_ext/bin/`, `/product/bin/` | Device-specific platform additions |
| `vendor` | `/vendor/bin/`, HALs in `/vendor/bin/hw/`, `.rc` in `/vendor/etc/init/` | Anything that touches device-specific hardware |

Hardware access belongs on **vendor**. A vendor daemon that the framework calls must be a stable AIDL HAL
([AIDL_HAL_impl.md](AIDL_HAL_impl.md)).

## 2. Started by `init`

```bp
cc_binary {
    name: "mydaemon",
    vendor: true,
    srcs: ["mydaemon.cpp"],
    shared_libs: ["libbase", "liblog"],
    init_rc: ["mydaemon.rc"],          // installed to /vendor/etc/init/
}
```

```text
# mydaemon.rc
service mydaemon /vendor/bin/mydaemon
    class main
    user system                     # not root: pick the least privileged user
    group system
    capabilities NET_ADMIN          # only if needed; avoids running as root for one privilege
    task_profiles ServiceCapacityLow
    # oneshot                       # run once instead of being restarted
    # disabled                      # don't start with its class; start explicitly
    # socket mydaemon stream 0660 system system   # creates /dev/socket/mydaemon

on property:vendor.mydaemon.enable=1
    start mydaemon
```

+ When a service exits, `init` **restarts** it, unless it is `oneshot`.
  A `critical` service that crashes more than 4 times in 4 minutes reboots the device into the bootloader.
+ `start` / `stop` / `restart <service>` in `.rc` actions, or the property `ctl.start` (only for domains that are allowed to set it).
+ Status: `adb shell getprop init.svc.mydaemon` → `running`, `stopped`, `restarting`.
+ Lazy AIDL HALs use `interface aidl <instance>` + `disabled` + `oneshot`, so `init` starts them on the first lookup;
  see [ServiceManager_ndk.md](ServiceManager_ndk.md).

## 3. Privileges: UID, capabilities, SELinux

A daemon is limited in 2 independent ways:

+ **DAC**: its `user`/`group` must be allowed by the file modes of what it opens.
  Device-node permissions come from `ueventd.rc`, and sysfs attributes from `ueventd.rc` or `chown`/`chmod` in an `.rc` action.
+ **SELinux**: its domain (from `init_daemon_domain()` and the `file_contexts` label of the executable) must be allowed by the policy.

Running as `root` helps with the first only. Root doesn't bypass SELinux, so it adds risk without solving denials.
Policy: [SELinux_policy.md](SELinux_policy.md#5-complete-example-a-vendor-daemon). Sysfs and GPIO examples: [hw_control_sysfs.md](hw_control_sysfs.md).

## 4. Talking to a daemon

| Caller | Mechanism |
| --- | --- |
| Framework / system app → vendor daemon | Stable AIDL HAL on `/dev/binder` ([AIDL_HAL_impl.md](AIDL_HAL_impl.md)) |
| 3rd-party app | Never directly. Through a system app's bound service ([AIDL_3rdParty_app.md](AIDL_3rdParty_app.md)) |
| Vendor process → vendor daemon | Stable AIDL on `/dev/binder` (vndbinder is deprecated since Android 11) |
| Simple commands, same partition | A UNIX socket from the `socket` option, or a `vendor.*` property the daemon watches |

**JNI isn't used to reach a daemon.** JNI calls native code inside the **same** process.
A daemon is a separate process, so the caller uses Binder (AIDL), and the daemon runs its C++ directly:

```text
App / system app process --(Binder, AIDL)--> native daemon process --(open/write)--> /dev/... or /sys/...
```

When JNI is the right tool and when it isn't: [JNI_intro.md](JNI_intro.md#5-jni-vs-aidl), [HAL_libgpiod.md](HAL_libgpiod.md#2-do-i-need-jni-native-aidl-hal-vs-jni).

## 5. Debug

```shell
adb shell ps -AZ | grep mydaemon              # running? which domain and user?
adb shell getprop init.svc.mydaemon
adb logcat -s mydaemon                        # its LOG_TAG
adb logcat -b all | grep -E 'init:.*mydaemon|avc: denied.*mydaemon'
adb shell dmesg | grep -i mydaemon            # init messages also go to the kernel log (root)
```

## Related notes

+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md), [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md), [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md), [Led_control.md](Led_control.md)
+ [SELinux_policy.md](SELinux_policy.md), [hw_control_sysfs.md](hw_control_sysfs.md), [ServiceManager_ndk.md](ServiceManager_ndk.md)
+ [JNI_intro.md](JNI_intro.md), [HAL_libgpiod.md](HAL_libgpiod.md), [Binder_intro.md](Binder_intro.md)

## Reference

+ [Android init language (system/core/init/README.md)](https://android.googlesource.com/platform/system/core/+/main/init/README.md)
+ [SELinux for Android (AOSP)](https://source.android.com/docs/security/features/selinux)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
