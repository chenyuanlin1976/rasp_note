# GPIO and LED control on an RK3566 Android board

This note collects practical recipes for an RK3566 board running Android: which interface to use, how to read the board's GPIO state, and how to fix common errors.
The examples use real output from this board.

## 1. Which interface?

| Goal | Use | Who can use it |
| --- | --- | --- |
| A notification LED on a phone | `NotificationChannel.enableLights()` (section 2.1) | Any app (the OS decides) |
| Mic-mute, keyboard, or controller lights | `LightsManager` (Android 12+, section 2.2) | System/privileged apps (`CONTROL_DEVICE_LIGHTS`) |
| An LED on your board | DT **`gpio-leds`** → `/sys/class/leds/<name>/` (section 4) | root / a daemon / a HAL |
| A plain GPIO (relay, enable, signal) | **`/dev/gpiochipN` + libgpiod** (section 5.1) | root / a daemon / a HAL |
| The same, on old setups | `/sys/class/gpio` export (section 5.2), deprecated | root |
| A product feature that apps use | A **vendor AIDL HAL** behind a system app ([AIDL_HAL_gpio.md](AIDL_HAL_gpio.md), [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)) | Apps, through Binder |

Normal apps can never touch `/sys/class/*` or `/dev/gpiochip*` directly. The reasons are in [hw_control_sysfs.md](hw_control_sysfs.md) and [JNI_C_code.md](JNI_C_code.md).

## 2. Public Android light APIs

### 2.1 Notification LED (API 26+)

You don't turn the LED on yourself. You ask for it on a notification channel, and the system blinks it while the notification is shown (usually only with the screen off):

```kotlin
val channel = NotificationChannel("alerts", "Alerts", NotificationManager.IMPORTANCE_DEFAULT).apply {
    enableLights(true)
    lightColor = Color.RED
}
getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
// ...then post notifications on this channel
```

Most current phones have no notification LED (they use an always-on display), and the system can ignore the request.

### 2.2 `LightsManager` (Android 12, API 31+)

This is for **device lights** that the system exposes, such as a microphone-mute LED or input-device lights (keyboard backlight, game controller player LEDs).
It needs `android.permission.CONTROL_DEVICE_LIGHTS`, which is a **signature|privileged** permission, so Play Store apps can't use it.

```kotlin
val lightsManager = getSystemService(LightsManager::class.java)
val light = lightsManager.lights.firstOrNull() ?: return

lightsManager.openSession().use { session ->            // lights revert when the session is closed
    val request = LightsRequest.Builder()
        .addLight(light, LightState.Builder().setColor(Color.GREEN).build())
        .build()
    session.requestLights(request)
    // keep the session open as long as the light should stay in this state
}
```

These APIs don't give access to arbitrary board LEDs or GPIOs. For those, see sections 4–5.

## 3. Read the board's GPIO state

### 3.1 Numbering on RK3566

+ 5 banks, `GPIO0`…`GPIO4` → `gpiochip0`…`gpiochip4`, 32 lines each (A0–D7).
+ **Offset in the bank** = group × 8 + n (A=0, B=1, C=2, D=3).
  For example, `GPIO4_B2` → offset 10, and `GPIO2_C0` → offset 16.
+ **Global (sysfs) number** = chip **base** + offset. On this board the bases are 0, 32, 64, 96, 128.
  So `GPIO4_B2` = 128 + 10 = **138**, and `GPIO2_C0` = 64 + 16 = **80**.
  Always read the bases from the dump below (or `cat /sys/class/gpio/gpiochip*/base`).
  Newer kernels may assign different bases.
+ In the device tree: `<&gpio4 RK_PB2 GPIO_ACTIVE_HIGH>` (`RK_PB2` = 10).

### 3.2 Who owns which pin: `/sys/kernel/debug/gpio`

```shell
adb root
adb shell cat /sys/kernel/debug/gpio        # debugfs: userdebug/eng builds
```

Output on this board:

```text
gpiochip0: GPIOs 0-31, parent: platform/fdd60000.gpio, gpio0:
 gpio-0   (                    |watchdog            ) out hi
 gpio-5   (                    |vcc5v0-otg-regulator) out lo
 gpio-6   (                    |vcc5v0-host-regulato) out hi
 gpio-8   (                    |irblaster           ) out lo
 gpio-13  (                    |GTP_INT_IRQ         ) in  hi
 gpio-14  (                    |GTP_RST_PORT        ) out hi
 gpio-16  (                    |bt_default_wake     ) out lo
 gpio-18  (                    |gpio-regulator      ) out lo
 gpio-21  (                    |vcc3v3-lcd1-n       ) out lo
 gpio-23  (                    |vcc3v3-lcd0-n       ) out lo
 gpio-28  (                    |wifi-en             ) out hi

gpiochip1: GPIOs 32-63, parent: platform/fe740000.gpio, gpio1:
 gpio-37  (                    |work                ) out hi
 gpio-38  (                    |i2s-lrck            ) in  hi

gpiochip2: GPIOs 64-95, parent: platform/fe750000.gpio, gpio2:
 gpio-77  (                    |bt_default_rts      ) out hi
 gpio-79  (                    |bt_default_reset    ) out lo
 gpio-80  (                    |bt_default_wake_host) in  lo IRQ

gpiochip3: GPIOs 96-127, parent: platform/fe760000.gpio, gpio3:
 gpio-119 (                    |reset               ) out hi ACTIVE LOW
 gpio-122 (                    |dvb-en              ) out hi
 gpio-123 (                    |dvb-rf              ) out hi

gpiochip4: GPIOs 128-159, parent: platform/fe770000.gpio, gpio4:
 gpio-146 (                    |sysfs               ) out hi
 gpio-148 (                    |ir-blaster-pw       ) out hi
```

How to read it:

+ Each listed line is **requested**. The name after `|` is the **consumer**: a driver/DT node (`wifi-en`, `dvb-rf`), or `sysfs` for a line exported through `/sys/class/gpio`.
  Here, gpio-146 = `GPIO4_C2` was exported by hand.
+ The first column (empty here) shows the line *name* from `gpio-line-names`.
+ `out hi`/`in lo` show the direction and the current level. `IRQ` means it's used as an interrupt. `ACTIVE LOW` means the polarity is inverted.
+ **Lines that aren't listed are free.** Only those can be exported or requested from user space.

With libgpiod tools on the device, `gpioinfo gpiochip2` shows the same information per line.

## 4. LEDs: use the LED class

On this board, some outputs are declared as LEDs in `rk3566-evb2-lp4x-v10-390k.dtsi`:

```dts
&leds {
    dvb_rf: dvb-rf {
        gpios = <&gpio3 RK_PD3 GPIO_ACTIVE_HIGH>;       /* gpio3 base 96 + 27 = gpio-123 */
        default-state = "on";
    };

    ir_blaster_pw: ir-blaster-pw {
        gpios = <&gpio4 RK_PC4 GPIO_ACTIVE_HIGH>;       /* gpio4 base 128 + 20 = gpio-148 */
        default-state = "on";
    };
};
```

Because there's no `label`, the node names become the LED names (`/sys/class/leds/dvb-rf`). They match the consumers in the dump above.
Control them through the LED class, not through GPIO numbers:

```shell
# dvb-rf = LED1_G_OSM (green), ir-blaster-pw = LED1_B_OSM (blue)
adb shell "echo 0 > /sys/class/leds/dvb-rf/brightness"           # green off
adb shell "echo 1 > /sys/class/leds/dvb-rf/brightness"           # green on
adb shell "echo 0 > /sys/class/leds/ir-blaster-pw/brightness"    # blue off
adb shell "echo 1 > /sys/class/leds/ir-blaster-pw/brightness"    # blue on
adb shell "echo heartbeat > /sys/class/leds/dvb-rf/trigger"      # blink in the kernel, no process needed
```

These pins are **owned by `leds-gpio`**, so exporting 123 or 148 through sysfs fails with `EBUSY`. That is expected.
More on the LED class: [../Linux/sysfs_led_class.md](../Linux/sysfs_led_class.md) and [../Linux/dts_node_led_vs_gpio.md](../Linux/dts_node_led_vs_gpio.md).

### RGB LEDs

Three on/off GPIOs give only 7 colors plus off.
For mixing and dimming, the channels must be on **PWM** outputs: `pwm-leds`, or the multicolor drivers
(`leds-pwm-multicolor`, `leds-group-multicolor`, depending on the kernel version).
These give one `/sys/class/leds/<name>/` with `multi_intensity` + `brightness`.
Raw `/sys/class/pwm/pwmchipN/` also works for experiments.

## 5. Plain GPIOs (not LEDs)

### 5.1 Recommended: character device + libgpiod

```shell
adb root
adb shell gpiodetect                      # tools must be built for Android: see libgpiod_android.md
adb shell gpioinfo gpiochip4
adb shell gpioset --mode=signal gpiochip4 10=1 &     # GPIO4_B2 high; v1 needs --mode=signal to KEEP driving it
```

There's no global numbering: a global number like 80 becomes **chip + offset**: 80 − 64 = `gpiochip2` line 16.
A plain v1 `gpioset gpiochip4 10=1` (without `--mode`) releases the line when it exits, so the level isn't guaranteed afterwards.
Building and using the tools on Android is covered in [libgpiod_android.md](libgpiod_android.md), and the tools in general in [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md).

### 5.2 Legacy: `/sys/class/gpio` export

This board's kernel has it enabled. Check yours:

```shell
adb shell "zcat /proc/config.gz | grep GPIO_SYSFS"   # CONFIG_GPIO_SYSFS=y on this board (needs CONFIG_IKCONFIG_PROC)
adb shell ls /sys/class/gpio                         # no such directory -> not built in
```

```shell
adb root
adb shell "echo 138 > /sys/class/gpio/export"                 # GPIO4_B2
adb shell "echo low > /sys/class/gpio/gpio138/direction"      # output, starting LOW ("high" = output, starting HIGH)
adb shell "echo 1 > /sys/class/gpio/gpio138/value"
adb shell "cat /sys/class/gpio/gpio138/value"
adb shell "echo 138 > /sys/class/gpio/unexport"               # release when done
```

The export stays until `unexport` or a reboot, even if the process that created it exits.
That's one reason this interface is deprecated; see [../Linux/libgpiod_sysfs_cmp.md](../Linux/libgpiod_sysfs_cmp.md).

### 5.3 Device-tree requirements for a free pin

For user space to request a pin, **no kernel consumer may own it**:

+ **Don't** put it in `gpio-leds`, `gpio-keys`, `regulator-fixed`, or any `*-gpios` property. Each of those **claims** the line.
+ **Don't** use a `gpio-hog` either. A hog claims the line in the kernel and sets its direction and level, so user space can't request it.
+ **Do** set the mux and pull with a **pinctrl hog** in the pin controller.
  This only configures the pin, it doesn't claim it.
  (Rockchip's GPIO driver also switches the mux to GPIO on request, but the pull/drive settings come only from pinctrl.)

```dts
&pinctrl {
    pinctrl-names = "default";
    pinctrl-0 = <&user_gpio_pins>;

    user-gpio {
        user_gpio_pins: user-gpio-pins {
            rockchip,pins = <4 RK_PB2 RK_FUNC_GPIO &pcfg_pull_down>;   /* GPIO4_B2 */
        };
    };
};
```

Optionally, add `gpio-line-names` to `&gpio4` so that `gpioinfo`, `gpiofind` (v1), and the v2 tools can use a name.
The full example is in [../Linux/dts_node_led_vs_gpio.md](../Linux/dts_node_led_vs_gpio.md#2-as-a-plain-gpio).

### 5.4 Common errors

| Error | Meaning | Fix |
| --- | --- | --- |
| `write error: Device or resource busy` (`EBUSY`) on export/request | A driver or another process owns the line. Example: **gpio-80** is held by `bt_default_wake_host` in the dump above | Pick a free pin, or remove the consumer from the DT |
| `write error: Invalid argument` (`EINVAL`) on export | No GPIO chip has that **number** (wrong base), or the line is reserved | Check bases with `cat /sys/kernel/debug/gpio` / `gpiochip*/base` |
| `No such file or directory` | `/sys/class/gpio` isn't built (`CONFIG_GPIO_SYSFS` off), or the pin isn't exported yet | Use `/dev/gpiochipN`, or export first |
| `Permission denied` | Not root, or SELinux denies the `shell` domain | `adb root` (userdebug); for services, see [hw_control_sysfs.md](hw_control_sysfs.md) |
| Exports fine, but the pin doesn't change | The mux belongs to another function, or the wrong pin | Check `/sys/kernel/debug/pinctrl/*/pinmux-pins` and the schematic |

On Rockchip, requesting a pin as GPIO can **silently take it from** a peripheral (UART, I2C) that uses it through pinctrl.
Check `pinmux-pins` before using a pin that the schematic assigns to something else.

## 6. In a product

Shell commands and `adb root` are for bring-up only. In a product:

+ **LEDs**: declare them as `gpio-leds`/`pwm-leds`. The Lights HAL or a vendor service writes `/sys/class/leds/...`
  ([AIDL_ndk_led_sysfs.md](AIDL_ndk_led_sysfs.md)).
+ **Other GPIOs**: a vendor AIDL HAL owns the lines through libgpiod
  ([AIDL_HAL_gpio.md](AIDL_HAL_gpio.md), [HAL_libgpiod.md](HAL_libgpiod.md)).
+ **Apps**: call a system app's bound service ([AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)).

## Related notes

+ [hw_control_sysfs.md](hw_control_sysfs.md), [HAL_libgpiod.md](HAL_libgpiod.md), [libgpiod_android.md](libgpiod_android.md)
+ [Led_control.md](Led_control.md)
+ [gpio_kernel_config.md](gpio_kernel_config.md): device tree, kernel config and build for a GPIO
+ [input_key_flow.md](input_key_flow.md): buttons as `gpio-keys` input devices, from the kernel to an app
+ [../Linux/libgpiod_sysfs_cmp.md](../Linux/libgpiod_sysfs_cmp.md), [../Linux/dts_node_led_vs_gpio.md](../Linux/dts_node_led_vs_gpio.md)

## Reference

+ [LightsManager (Android API)](https://developer.android.com/reference/android/hardware/lights/LightsManager)
+ [Sysfs GPIO interface, obsolete (kernel docs)](https://docs.kernel.org/userspace-api/gpio/sysfs.html)
+ [GPIO character device uAPI (kernel docs)](https://docs.kernel.org/userspace-api/gpio/chardev.html)
