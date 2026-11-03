# Hardware control through sysfs on Android (GPIO example)

This note covers controlling a GPIO through the **legacy sysfs interface** (`/sys/class/gpio/`) on an Android 14 board.
It explains why this is hard, how to make it work on a board you build yourself, and why `/dev/gpiochipN` is the better choice.

## 1. First check: does the interface exist?

sysfs GPIO has been **deprecated since Linux 4.8**.
Many Android kernels, including GKI configurations, are built **without `CONFIG_GPIO_SYSFS`**.

```shell
adb shell ls /sys/class/gpio          # "No such file or directory" -> not built into this kernel
adb shell zcat /proc/config.gz | grep GPIO_SYSFS   # if /proc/config.gz is enabled
```

If the interface is missing, use the character device (`/dev/gpiochipN`) with libgpiod instead.
See [HAL_libgpiod.md](HAL_libgpiod.md), [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md), and [../Linux/libgpiod_sysfs_cmp.md](../Linux/libgpiod_sysfs_cmp.md).

## 2. Why an app can't use it

Even where `/sys/class/gpio` exists, a normal app (`untrusted_app`) is blocked twice:

+ **DAC**: `export`, `direction`, and `value` are owned by `root` (mode `0200`/`0644`), and the app's UID (`u0_aNNN`) can't write them.
+ **SELinux**: the files carry a sysfs label (generic `sysfs`, or a specific type that the device assigns).
  App domains aren't allowed to write it, and AOSP `neverallow` rules forbid granting app domains access to generic sysfs.
  Adding such a rule breaks the build or fails CTS (see [neverallow_error.md](neverallow_error.md)).

**Platform signing doesn't help.** A platform-signed app gets signature permissions and a `platform_app`/`system_app` domain.
It still runs as an app domain, under the same `neverallow` rules.
And native daemons aren't "signed with the platform key" at all: their identity is their **UID/GID**, set in the `.rc` file,
plus their **SELinux domain**.

## 3. The working design: a privileged native daemon

```text
App --Binder (AIDL)--> GPIO daemon / HAL (own UID + SELinux domain) --write--> /sys/class/gpio/gpioN/value
```

1. A native daemon (preferably a vendor AIDL HAL) owns the pin. It runs as `user system` (or a dedicated user) and in its own domain.
2. It exports the pin and sets the direction once at startup, then writes `value` when a request arrives.
3. It exposes an **AIDL** interface. Apps use it through a system app or service
   (see [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md) and [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md)).

### 3.1 Ownership and permissions (DAC)

`/sys/class/gpio/gpioN/` doesn't exist until the pin is exported, and sysfs permissions reset at every boot.
The simplest setup is to let **init export the pin at boot** and hand the files to the daemon's user:

```text
# vendor init .rc
on boot
    write /sys/class/gpio/export 157
    write /sys/class/gpio/gpio157/direction low      # output, initially low
    chown system system /sys/class/gpio/gpio157/value
    chmod 0660 /sys/class/gpio/gpio157/value
```

The `export` write creates the directory synchronously, so the following lines can use it.
After that, the daemon (`user system`) only writes `value`; it doesn't need root.

If pins are exported later, at runtime, `ueventd.rc` can set attribute permissions when the new device appears:

```text
# vendor ueventd.rc: <sysfs device path pattern> <attribute> <mode> <user> <group>
/sys/devices/platform/fe770000.gpio/gpiochip4/gpio/gpio*   value   0660  system  system
```

Check the result on a userdebug build with `adb shell ls -lZ /sys/class/gpio/gpio157/`.

### 3.2 SELinux

sysfs files are labeled with **`genfs_contexts`**, not `file_contexts`.
Use the **real** path under `/sys/devices/...`, because `/sys/class/gpio/gpioN` is a symlink:

```shell
adb shell readlink -f /sys/class/gpio/gpio157     # e.g. /sys/devices/platform/fe770000.gpio/gpiochip4/gpio/gpio157
```

```text
# vendor/file.te
type sysfs_gpio_ctl, sysfs_type, fs_type;

# vendor/genfs_contexts
genfscon sysfs /devices/platform/fe770000.gpio/gpiochip4/gpio   u:object_r:sysfs_gpio_ctl:s0

# vendor/gpio_daemon.te   (domain from init_daemon_domain; see SELinux_policy.md)
allow gpio_daemon sysfs_gpio_ctl:dir r_dir_perms;
allow gpio_daemon sysfs_gpio_ctl:file rw_file_perms;
```

If `init` writes `export`, it also needs `allow init sysfs_gpio_ctl:file w_file_perms;`,
or the label of `/sys/class/gpio/export` (often a generic `sysfs` type).
Check denials with `adb logcat | grep avc` (see [avc_denied.md](avc_denied.md)).

## 4. Verify

```shell
adb shell ps -AZ | grep gpio_daemon            # running in its own domain?
adb shell cat /sys/class/gpio/gpio157/value    # (userdebug, as root)
adb logcat | grep 'avc: denied'
```

Then call the AIDL method from a client and measure the pin with a multimeter or oscilloscope.

## 5. Recommendation

For new work, use **`/dev/gpiochipN` + libgpiod** in the daemon instead of sysfs:

+ It works when `CONFIG_GPIO_SYSFS` is off.
+ Its permissions are a single `ueventd.rc` line for `/dev/gpiochip*`.
+ The labels are a plain `file_contexts` entry.
+ Line ownership is released automatically if the daemon crashes.

The full example is in [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md).

## Related notes

+ [HAL_sysfsNodes.md](HAL_sysfsNodes.md), [HAL_libgpiod.md](HAL_libgpiod.md), [JNI_C_code.md](JNI_C_code.md)
+ [SELinux_policy.md](SELinux_policy.md), [neverallow_error.md](neverallow_error.md), [gpio_control.md](gpio_control.md)
+ [../Linux/libgpiod_sysfs_cmp.md](../Linux/libgpiod_sysfs_cmp.md), [../Linux/sysfs_intro.md](../Linux/sysfs_intro.md)

## Reference

+ [Sysfs GPIO interface, obsolete (kernel docs)](https://docs.kernel.org/userspace-api/gpio/sysfs.html)
+ [SELinux: labeling sysfs with genfs_contexts (AOSP)](https://source.android.com/docs/security/features/selinux/implement)
