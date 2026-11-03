# LED control on Android: on, off, blink

This note is about the **design**: which interface to use for an LED, who writes the sysfs files, and why blinking belongs in the kernel.
The details are in other notes:

| Topic | Note |
| --- | --- |
| LED class attributes and triggers (`brightness`, `trigger`, `delay_on`, ...) | [../Linux/sysfs_leds.md](../Linux/sysfs_leds.md) |
| Board LEDs on RK3566 (`gpio-leds`), notification LED, `LightsManager` | [gpio_control.md](gpio_control.md) |
| Complete C++ (NDK) AIDL service that writes `/sys/class/leds` | [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md) |
| Turning it into a stable vendor HAL (VINTF, SELinux) | [AIDL_HAL_impl.md](AIDL_HAL_impl.md) |
| Permissions on sysfs files (`ueventd.rc`, `genfs_contexts`) | [hw_control_sysfs.md](hw_control_sysfs.md) |

## 1. Choose the interface

| The LED is ... | Use | Who drives it |
| --- | --- | --- |
| A standard light: backlight, battery, notification, attention, mic-mute, ... | The AOSP **Lights HAL** (`android.hardware.light`, AIDL `ILights`, Android 11+) | The framework (`LightsService`, notifications, battery, `LightsManager`) |
| A product-specific indicator (status, recording, RF on, ...) | A **vendor AIDL HAL** (`vendor.<company>.hardware.led`) | A system app or service, through Binder |
| Only for bring-up / debugging | `adb shell` + `echo` into sysfs (userdebug, `adb root`) | You |

In both product cases, the code that writes `/sys/class/leds/...` is a **native vendor process** with its own SELinux domain.
Apps, and Java/Kotlin code in general, only send requests through Binder.

### 1.1 The standard Lights HAL

```java
// hardware/interfaces/light/aidl/android/hardware/light/ILights.aidl (AOSP)
@VintfStability
interface ILights {
    void setLightState(in int id, in HwLightState state);   // color (ARGB), flashMode, flashOnMs, flashOffMs, brightnessMode
    HwLight[] getLights();                                   // id, ordinal, LightType (BACKLIGHT, BATTERY, NOTIFICATIONS, ...)
}
```

+ A device implements `ILights` in `/vendor/bin/hw/` and maps each `HwLight` to a `/sys/class/leds/<name>` directory.
  AOSP's `hardware/interfaces/light/aidl/default` is a Rust example that only logs and stores the state (no hardware access), so it is a template, not a driver.
+ `FlashMode.TIMED` with `flashOnMs` / `flashOffMs` is naturally implemented with the kernel `timer` trigger (section 3).
+ `HwLightState.color` is ARGB. A single-color LED uses a brightness value derived from it, and an on/off LED is on for any non-zero color.
+ AOSP policy already has the domain `hal_light_default`, the attribute `hal_light`, and the type `sysfs_leds` (for `/sys/class/leds`).

Use this whenever the LED has one of the standard meanings. Then nothing above the HAL needs custom code.

## 2. On and off

The sequence each implementation performs (`LED=/sys/class/leds/<name>`):

| Action | Writes | Notes |
| --- | --- | --- |
| On | `none` → `trigger`, then `max_brightness` → `brightness` | Read `max_brightness`: `1` for a GPIO LED, often `255` for PWM. Larger values are clamped |
| Off | `0` → `brightness` | Writing `0` also removes any active trigger |
| Blink | `timer` → `trigger`, then `delay_on`, `delay_off` (ms) | `delay_on` / `delay_off` appear only **after** `trigger=timer` |
| Heartbeat / pattern | `heartbeat` or `pattern` → `trigger` | Needs `CONFIG_LEDS_TRIGGER_*` in the kernel |

Bring-up test on a userdebug build:

```shell
adb root
adb shell 'LED=/sys/class/leds/sys_led_r; cat $LED/max_brightness $LED/trigger'
adb shell 'LED=/sys/class/leds/sys_led_r; echo none > $LED/trigger; cat $LED/max_brightness > $LED/brightness'   # on
adb shell 'echo 0 > /sys/class/leds/sys_led_r/brightness'                                                      # off
adb shell 'LED=/sys/class/leds/sys_led_r; echo timer > $LED/trigger; echo 500 > $LED/delay_on; echo 500 > $LED/delay_off'
```

The state is lost at reboot. Set a boot default in the device tree (`default-state`, `linux,default-trigger`)
or in an `on boot` block of a vendor `.rc` file.

## 3. Blink in the kernel, not with an app timer

| | Kernel trigger (`timer`, `heartbeat`, `pattern`) | Timer in Java/Kotlin (`Handler`, coroutine) |
| --- | --- | --- |
| Who toggles the LED | A kernel timer, or the LED controller itself if the driver supports hardware blinking | The app process, through 2 Binder calls per period |
| Power | Minimal: no user-space process wakes up | The app process wakes up for every edge, which blocks deep sleep |
| Timing | Stable; unaffected by GC, UI load, or app state | Jitter from GC pauses, main-thread load, and scheduling |
| Doze / background limits | Not affected; keeps running even if user space crashes | Timers are delayed while dozing, and a cached or frozen process stops completely |
| Interface | One call: `blink(onMs, offMs)` | A stream of `on()` / `off()` calls |

So the interface should send **configuration** (mode, on/off times), and the HAL writes the trigger once.
A user-space loop is needed only for a sequence that no kernel trigger can express. Even then, the loop belongs in the native HAL, not in the app.

## 4. A custom vendor LED interface

Make the methods semantic, and use constants or enums instead of magic numbers:

```java
// vendor/example/hardware/led/aidl/vendor/example/hardware/led/LedMode.aidl
package vendor.example.hardware.led;

@VintfStability
@Backing(type="int")
enum LedMode { OFF, ON, BLINK }
```

```java
// vendor/example/hardware/led/aidl/vendor/example/hardware/led/IStatusLed.aidl
package vendor.example.hardware.led;

import vendor.example.hardware.led.LedMode;

@VintfStability
interface IStatusLed {
    /** onMs/offMs are used only for LedMode.BLINK. Fails with EX_ILLEGAL_ARGUMENT if they are <= 0. */
    void setMode(LedMode mode, int onMs, int offMs);
    LedMode getMode();
}
```

+ Package `vendor.<company>.hardware.*`; `android.hardware.*` is reserved for Google.
  With `stability: "vintf"`, a frozen version, an NDK-backend service in `/vendor/bin/hw/`, a VINTF manifest entry, and SELinux:
  see [AIDL_HAL_impl.md](AIDL_HAL_impl.md).
  The write logic is the same as in [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md) (which uses an unstable `com.example.led` interface for a prototype).
+ Several LEDs: either one instance per LED (`.../IStatusLed/red`, `.../IStatusLed/green`) or an `int ledId` parameter plus `getLeds()`, like `ILights`.

## 5. Why the app can't write sysfs itself

`File("/sys/class/leds/<name>/brightness").writeText("1")` compiles, but it fails on a product device:

+ **DAC**: LED attributes are owned by `root` (mode `0644`), and apps run as `u0_aNNN`.
+ **SELinux**: app domains have no access to sysfs device attributes, and `neverallow` rules forbid adding it.
  See [neverallow_error.md](neverallow_error.md).
+ Doing the file I/O in a Java system service (`system_server`) is also wrong for vendor hardware.
  Treble keeps vendor-specific sysfs paths out of the system image; put them in a vendor HAL.
+ `su` on a rooted device is acceptable only for personal experiments.

What the HAL process needs instead:

```text
# vendor ueventd.rc: give the attributes to the HAL's user
/sys/devices/platform/leds/leds/*   brightness   0664  system  system
/sys/devices/platform/leds/leds/*   trigger      0664  system  system

# vendor genfs_contexts: label the real path (adb shell readlink -f /sys/class/leds/<name>)
genfscon sysfs /devices/platform/leds/leds    u:object_r:sysfs_leds:s0

# vendor/hal_led_default.te: the custom HAL's domain (hal_attribute(led), see AIDL_HAL_impl.md)
allow hal_led_default sysfs_leds:dir r_dir_perms;
allow hal_led_default sysfs_leds:lnk_file read;
allow hal_led_default sysfs_leds:file rw_file_perms;
```

`delay_on` / `delay_off` are created when the trigger changes, so `ueventd.rc` doesn't cover them on all kernels.
If the HAL can't write them, run it as the owner of the files, or set them up in the `.rc` file after the trigger is selected.
Check this on the target with `ls -lZ` after `trigger=timer`.

## Related notes

+ [../Linux/sysfs_leds.md](../Linux/sysfs_leds.md), [../Linux/dts_node_leds.md](../Linux/dts_node_leds.md)
+ [gpio_control.md](gpio_control.md), [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md)
+ [hw_control_sysfs.md](hw_control_sysfs.md), [HAL_sysfsNodes.md](HAL_sysfsNodes.md), [neverallow_error.md](neverallow_error.md)
+ [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md): exposing the LED to 3rd-party apps through a system app

## Reference

+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [`LightsManager`](https://developer.android.com/reference/android/hardware/lights/LightsManager)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
