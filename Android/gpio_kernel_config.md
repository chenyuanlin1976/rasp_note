# Kernel setup for a GPIO in an Android image

This note covers the kernel side of using a GPIO on an Android board: the device tree, the kernel config, and how both get into the image.
The examples use an RK3566 board and a pin used from user space with libgpiod (GPIO4_B2 = `gpiochip4` line 10).

How to use the pin at run time (libgpiod, sysfs, LEDs) is in [gpio_control.md](gpio_control.md).

## 1. What has to change, and where it lives

| Piece | Where | Ends up in |
| --- | --- | --- |
| Pin mux and pull (pinctrl) | Board `.dts` in the kernel tree, e.g. `arch/arm64/boot/dts/rockchip/rk3566-<board>.dts` | The DTB, or a DTBO overlay |
| Pin ownership (a driver, or free for user space) | The same `.dts` | The DTB |
| GPIO drivers and the character device | Kernel config (defconfig or a config fragment) | The kernel image or vendor modules |
| Device permissions for `/dev/gpiochipN` | `ueventd.rc` and SELinux in the device tree (`device/<vendor>/<board>/`) | The vendor partition |

The kernel source is **not** in `device/<vendor>/<board>/kernel-headers/`. That directory, where it exists, only holds UAPI headers for user-space code.
In plain AOSP the kernel is built separately (Kleaf) and the device directory ships prebuilt kernel files.
Vendor SDKs, such as Rockchip's RK3566 Android SDK, keep the kernel source in a `kernel/` directory of the SDK tree.

## 2. Device tree

### 2.1 Mux and pull only (pin used from user space)

User space can only request a line that no kernel driver claims, so the pin is configured with a **pinctrl hog** and nothing else:

```dts
#include <dt-bindings/pinctrl/rockchip.h>

&pinctrl {
    pinctrl-names = "default";
    pinctrl-0 = <&user_gpio_pins>;

    user-gpio {
        user_gpio_pins: user-gpio-pins {
            rockchip,pins = <4 RK_PB2 RK_FUNC_GPIO &pcfg_pull_down>;   /* GPIO4_B2 */
        };
    };
};

&gpio4 {
    /* optional: names shown by gpioinfo; one entry per line, starting at line 0 */
    gpio-line-names = "", "", "", "", "", "", "", "",
                      "", "", "RELAY_EN";                              /* line 10 = B2 */
};
```

Don't put the pin in `gpio-leds`, `gpio-keys`, a `*-gpios` property or a `gpio-hog`: each of those claims the line, and user space then gets `EBUSY`.
The full rules are in [gpio_control.md](gpio_control.md) (section 5.3).

### 2.2 Pin used by a kernel driver

If a driver should own the pin (LED, button, regulator enable), describe it as that driver's node instead:

+ LED: `gpio-leds` ([../Linux/dts_node_leds.md](../Linux/dts_node_leds.md))
+ Button: `gpio-keys` ([input_key_flow.md](input_key_flow.md))
+ Power rail: `regulator-fixed` ([../Linux/dts_node_fixedRegulator.md](../Linux/dts_node_fixedRegulator.md))
+ Fixed level at boot that nobody changes: `gpio-hog` in the GPIO controller node

Syntax and the provider/consumer pattern: [../Linux/dts_conventions.md](../Linux/dts_conventions.md).

## 3. Kernel config

```text
CONFIG_GPIOLIB=y
CONFIG_GPIO_ROCKCHIP=y        # the SoC's GPIO controller driver (older kernels: part of PINCTRL_ROCKCHIP)
CONFIG_PINCTRL_ROCKCHIP=y     # the SoC's pin controller driver
CONFIG_GPIO_CDEV=y            # /dev/gpiochipN
CONFIG_GPIO_CDEV_V1=y         # v1 uAPI, needed by libgpiod v1 (these notes use v1)
# CONFIG_GPIO_SYSFS is not set   # /sys/class/gpio, deprecated; enable only for legacy tools
```

Vendor defconfigs for a supported SoC usually have all of these already. Check the running board before changing anything:

```shell
adb shell "zcat /proc/config.gz | grep -E 'GPIO_(CDEV|SYSFS|ROCKCHIP)'"   # needs CONFIG_IKCONFIG_PROC
```

To change a value, edit the defconfig (or the vendor's config fragment) and regenerate it with `make savedefconfig`; see [../Linux/kernel_build.md](../Linux/kernel_build.md).
On **GKI** kernels (Android 12+ with kernel 5.10+), the core kernel config is fixed by Google.
Vendors can only add drivers as modules, so a change to a built-in option like `GPIO_SYSFS` may not be possible.

## 4. Build and flash

The kernel and the DTB are not built by `m` alone in every setup:

| Setup | How the kernel is built | Where the DTB goes |
| --- | --- | --- |
| Plain AOSP with GKI | Separately with Kleaf (`tools/bazel run ... dist`); the results are copied into `device/<vendor>/<board>/` as prebuilts | `vendor_boot.img` (DTB), `dtbo.img` (overlays) |
| Vendor SDK (e.g. Rockchip) | The SDK's build script builds U-Boot, the kernel and Android together | Depends on the SDK version (`boot.img`, `resource.img` or `vendor_boot.img`); see the SDK docs |

After building, the Android part is the usual flow ([AOSP_build.md](AOSP_build.md)):

```shell
source build/envsetup.sh
lunch <product>-<release>-userdebug      # older releases: <product>-userdebug
m
```

For DT or kernel-only changes you usually need to flash only the partition that holds them, not the whole image.
Rockchip boards are often flashed with Rockchip's own tools rather than `fastboot`, so check the board's documentation.

```shell
adb reboot bootloader
fastboot flash vendor_boot out/target/product/<device>/vendor_boot.img   # if the DTB is there
fastboot reboot
```

## 5. Verify on the board

```shell
adb shell ls /proc/device-tree/pinctrl/user-gpio                      # the new node is in the live tree
adb shell cat /sys/kernel/debug/pinctrl/*/pinmux-pins | grep gpio4    # mux of the pin (debugfs, adb root)
adb shell cat /sys/kernel/debug/gpio                                  # who owns each line
adb shell gpioinfo gpiochip4                                          # line 10 "RELAY_EN" unused -> free for user space
```

`gpioinfo` must be built for Android first; see [libgpiod_android.md](libgpiod_android.md).

## 6. Comments

+ **Check before you build.** On most vendor kernels the GPIO driver and the character device are already enabled, so only the device tree changes. The first step should be `zcat /proc/config.gz` and `gpioinfo`, not a defconfig edit.
+ **Decide who owns the pin first.** If a kernel driver fits (LED, button, regulator), use it: you get the standard sysfs/input interfaces and Android frameworks for free. Use libgpiod only for plain signals with no matching driver.
+ **Prefer an overlay for board variants.** On Android, a `dtbo` overlay lets one base DTB serve several board revisions; see [../Linux/dts_intro.md](../Linux/dts_intro.md) (section 6).
+ **Keep iterations short.** Rebuild only the DTB (`make rockchip/<board>.dtb`) and flash only the partition that holds it. A full `m` is needed only when the Android side changes.
+ **The kernel is only half the work.** An app can't open `/dev/gpiochipN`. A product also needs a `ueventd.rc` entry, SELinux rules, and usually a vendor AIDL HAL ([AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md), [HAL_libgpiod.md](HAL_libgpiod.md)).

## Related notes

+ [gpio_control.md](gpio_control.md): using GPIOs and LEDs at run time
+ [libgpiod_android.md](libgpiod_android.md), [HAL_libgpiod.md](HAL_libgpiod.md), [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md)
+ [AOSP_build.md](AOSP_build.md), [Bazel_intro.md](Bazel_intro.md): building AOSP and the kernel (Kleaf)
+ [../Linux/kernel_build.md](../Linux/kernel_build.md), [../Linux/dts_intro.md](../Linux/dts_intro.md), [../Linux/dts_conventions.md](../Linux/dts_conventions.md)

## Reference

+ [Building kernels (source.android.com)](https://source.android.com/docs/setup/build/building-kernels)
+ [Implement DTOs (source.android.com)](https://source.android.com/docs/core/architecture/dto/implement)
+ [Generic Kernel Image (source.android.com)](https://source.android.com/docs/core/architecture/kernel/generic-kernel-image)
+ [GPIO character device uAPI (kernel docs)](https://docs.kernel.org/userspace-api/gpio/chardev.html)
+ [Rockchip pinctrl binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/pinctrl/rockchip,pinctrl.yaml)
