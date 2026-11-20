# PWM control on RK3566 (Android 14)

Driving a PWM pin on an RK3566 running Android 14 takes two steps:

1. Enable the PWM controller and mux its pin in the **device tree**.
2. Drive the output, either from user space through **`/sys/class/pwm/`** or from a **kernel driver** that owns the channel.

The sysfs interface is fine for bring-up. In a product, a kernel driver (`pwm-leds`, `pwm-fan`, `pwm-backlight`, or a custom one) or a vendor HAL owns the channel, and apps never write sysfs.
The custom kernel driver example is in [../../Linux/Kernel/pwm_consumer_driver.md](../../Linux/Kernel/pwm_consumer_driver.md).

## 1. Check the PWM controllers

On a userdebug/eng build:

```shell
adb root
adb shell
ls -d /sys/bus/platform/devices/*.pwm      # enabled PWM nodes, e.g. fe700020.pwm
ls /sys/class/pwm/                         # pwmchip0, pwmchip1, ...
cat /sys/kernel/debug/pwm                  # requested channels, period, duty, polarity, enabled
```

+ On RK3566 every PWM **channel** is its own device tree node and its own `pwmchipN` with one channel (`npwm` = 1), so the channel index is always `0`.
  For example `fe700020.pwm` is `pwm14` (PWM12–15 are at `fe700000`, `fe700010`, `fe700020`, `fe700030`).
+ The `N` in `pwmchipN` depends on probe order. Find it from the platform device instead of hard-coding it (section 3).
+ `/sys/kernel/debug` is debugfs. Android 12+ doesn't mount it on user builds, and on userdebug you may need `mount -t debugfs debugfs /sys/kernel/debug`.
+ The PWM you want is missing → its node is `status = "disabled"`, or another node (backlight, fan, LED, a GPIO user) uses the pin.
  Check the pin mux in `/sys/kernel/debug/pinctrl/*/pinmux-pins`.

## 2. Enable and mux the PWM in the device tree

In the board `.dts` (in the Rockchip BSP, under `kernel/arch/arm64/boot/dts/rockchip/`):

```dts
&pwm14 {
	status = "okay";
	pinctrl-names = "active";          /* Rockchip BSP; mainline uses "default" */
	pinctrl-0 = <&pwm14m0_pins>;       /* m0/m1/m2: pick the mux that matches your physical pin */
};
```

+ Each PWM can be routed to 1–3 pins (`m0`, `m1`, ...). Look up which mux matches your pin in the RK3566 datasheet or the board schematic.
+ Make sure no other node (backlight, fan, LED, `gpio-hog`, a GPIO user) claims the same PWM or pin.
+ Rebuild and flash with your BSP's flow. The Rockchip SDK packs the DTB into the resource section of `boot.img`. Other setups use `dtbo.img`.

## 3. Quick test through sysfs

Times are in **nanoseconds**. Find the chip directory from the platform device:

```shell
P=/sys/devices/platform/fe700020.pwm/pwm
CHIP=$P/$(ls $P)                    # pwmchipN
echo 0 > $CHIP/export               # creates $CHIP/pwm0/
echo 1000000 > $CHIP/pwm0/period        # 1 ms = 1 kHz
echo 500000  > $CHIP/pwm0/duty_cycle    # 50 %
echo normal  > $CHIP/pwm0/polarity      # or 'inversed'; change it only while disabled
echo 1 > $CHIP/pwm0/enable
cat /sys/kernel/debug/pwm               # confirm the values, then measure with a scope or logic analyzer
echo 0 > $CHIP/pwm0/enable
echo 0 > $CHIP/unexport
```

+ `duty_cycle` must never exceed `period`. When **raising** the period, write `period` first. When **lowering** it below the current duty cycle, write `duty_cycle` first, or the write fails with `EINVAL`.
+ If a kernel driver already holds the channel (`pwm-backlight`, `pwm-fan`, ...), `export` fails with `EBUSY`.
  Then use that driver's interface instead, e.g. `/sys/class/backlight/<name>/brightness`.
+ The settings are lost at reboot.

More on platform devices and the PWM sysfs layout: [../../Linux/HW/sysfs_platform_devices.md](../../Linux/HW/sysfs_platform_devices.md).

## 4. Choose who owns the PWM in a product

| The PWM drives ... | Use | Interface for user space |
| --- | --- | --- |
| A dimmable LED | `pwm-leds` (`leds-pwm`) | `/sys/class/leds/<name>/brightness`, Lights HAL ([Led_control.md](Led_control.md)) |
| A fan | `pwm-fan` | hwmon, thermal framework |
| An LCD backlight | `pwm-backlight` | `/sys/class/backlight/<name>/`, framework brightness |
| A buzzer | `pwm-beeper` | input event `EV_SND` |
| Something else (motor, custom signal) | A custom kernel driver ([../../Linux/Kernel/pwm_consumer_driver.md](../../Linux/Kernel/pwm_consumer_driver.md)) or a vendor HAL writing `/sys/class/pwm` | A vendor AIDL HAL |

A standard kernel driver is preferred: the kernel owns the channel, applies the right state at boot and suspend, and Android's existing services use it.

## 5. Android 14: permissions for a vendor HAL

`adb root` works at once, but a normal process can't write the PWM files: they are owned by root, and SELinux labels them as generic `sysfs`.
Apps never get direct access (`neverallow` rules forbid it).
The working design is the same as for GPIO ([hw_control_sysfs.md](hw_control_sysfs.md)):

1. A **native vendor daemon or AIDL HAL** (`vendor.<company>.hardware.pwm`, in `/vendor/bin/hw/`) writes the PWM files.
2. Apps call it through Binder. A third-party app goes through a system app (bound service).

### 5.1 Ownership (DAC) with `ueventd.rc`

`pwmchipN` changes between boots, so use the platform path with a wildcard. ueventd applies the rules when the devices appear, including `pwm0` after `export`:

```text
# vendor ueventd.rc: <sysfs device path pattern> <attribute> <mode> <user> <group>
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*        export      0220  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*        unexport    0220  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   period      0660  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   duty_cycle  0660  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   polarity    0660  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   enable      0660  system  system
```

The daemon (`user system`) then exports the channel itself at startup.

### 5.2 SELinux

sysfs files are labeled with `genfs_contexts`, using the real `/sys/devices/...` path. The label covers the whole subtree:

```text
# vendor/file.te
type sysfs_pwm, sysfs_type, fs_type;

# vendor/genfs_contexts
genfscon sysfs /devices/platform/fe700020.pwm   u:object_r:sysfs_pwm:s0

# vendor/hal_pwm_default.te
allow hal_pwm_default sysfs_pwm:dir r_dir_perms;
allow hal_pwm_default sysfs_pwm:file rw_file_perms;
```

+ Give the daemon a specific type like this. A broad rule on `sysfs` fails `neverallow` checks or opens far too much.
+ Open the files through `/sys/devices/platform/...`. Going through the `/sys/class/pwm` symlinks also needs `lnk_file` access to the generic `sysfs` type.
+ Check with `adb shell ls -lZ /sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0/` and look for denials with `adb logcat | grep avc` ([../SELinux/avc_denied.md](../SELinux/avc_denied.md)).

### 5.3 The API

Expose intent, not file writes, e.g. `setOutput(int periodNs, int dutyPercent)` and `disable()`.
The HAL validates the values, writes `period`/`duty_cycle`/`enable` in the right order, and is the only writer.
Making it a stable vendor HAL (VINTF manifest, `@VintfStability`): [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md).

## Related notes

+ [../../Linux/Kernel/pwm_consumer_driver.md](../../Linux/Kernel/pwm_consumer_driver.md): custom kernel driver using the PWM consumer API
+ [../../Linux/HW/sysfs_platform_devices.md](../../Linux/HW/sysfs_platform_devices.md): platform devices, PWM sysfs on RK3566
+ [hw_control_sysfs.md](hw_control_sysfs.md): sysfs hardware access from a vendor daemon (GPIO example)
+ [Led_control.md](Led_control.md), [gpio_control.md](gpio_control.md), [../HAL/HAL_sysfsNodes.md](../HAL/HAL_sysfsNodes.md)
+ [../../Linux/DeviceTree/dts_provider_consumer.md](../../Linux/DeviceTree/dts_provider_consumer.md): `#pwm-cells`, `pwms`, `pwm-names`

## Reference

+ [Pulse Width Modulation (PWM) interface (kernel docs)](https://docs.kernel.org/driver-api/pwm.html)
+ [Implementing SELinux: genfs_contexts (AOSP)](https://source.android.com/docs/security/features/selinux/implement)
+ [AIDL for HALs (AOSP)](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ Rockchip RK3566 datasheet and the Rockchip Android SDK documentation (vendor docs)
