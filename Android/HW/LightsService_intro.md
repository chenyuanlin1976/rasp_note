# LightsService and the Lights HAL on Android 14 (RK3566)

`LightsService` (`com.android.server.lights.LightsService`) is the framework service in `system_server` that drives the device's standard lights.
It sits between the framework clients (display, battery, notifications) and the **Lights AIDL HAL** (`android.hardware.light.ILights/default`).
The HAL writes the kernel's `/sys/class/leds/...` and `/sys/class/backlight/...` nodes.

This note covers the framework side, its pitfalls, and whether a non-LED GPIO should go through it.
For the HAL implementation (`getLights()`, `setLightState()`, sysfs writes, VINTF, SELinux), see [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md).

## 1. The layers

```text
DisplayManagerService     BatteryService     NotificationManagerService     privileged app (LightsManager)
  (backlight fallback)      (battery LED)     (notification/attention LED)    (non-system lights only)
          \                      |                     |                          /
           \--------- LightsManager (local) ----------/      ILightsManager (binder "lights")
                                 |                                     |
                     system_server: LightsService  -- one LightImpl per HwLight --
                                 |
                                 |  Binder: ILights.setLightState(id, HwLightState)
                                 v
                  vendor: Lights HAL (/vendor/bin/hw/, domain hal_light_default)
                                 |
                                 |  write brightness / trigger / delay_on / delay_off
                                 v
        kernel: /sys/class/leds/<name>/        /sys/class/backlight/<name>/
                leds-gpio, leds-pwm, PMIC      pwm-backlight (MIPI-DSI / eDP / LVDS panel)
```

| Layer | What it does |
| --- | --- |
| Framework clients | `BatteryService` sets the battery light, `NotificationManagerService` the notification and attention lights. `DisplayManagerService` uses the backlight light only as a fallback (section 3.3) |
| `LightsService` | At boot it gets the HAL with `waitForDeclaredService("android.hardware.light.ILights/default")`, calls `getLights()`, and wraps each `HwLight` in a `LightImpl` (a `LogicalLight`). It publishes the local service `LightsManager` for other `system_server` services and the binder service `lights` for the `LightsManager` API |
| Lights HAL (vendor) | Maps each light `id` to a sysfs node and converts `HwLightState` (`color`, `flashMode`, `flashOnMs`, `flashOffMs`, `brightnessMode`) into writes |
| Kernel and device tree | The RK3566 `.dts` declares `gpio-leds`, `pwm-leds`, or `pwm-backlight` nodes. The drivers create the sysfs nodes |

+ The AIDL Lights HAL exists since Android 11. If no AIDL HAL is declared in the VINTF manifest, `LightsService` falls back to the deprecated HIDL `android.hardware.light@2.0`. A new Android 14 device should implement the AIDL HAL.
+ `LightsService` keeps 2 lookup tables. `mLightsById` holds every `HwLight` and serves `LightsManager` sessions and `dumpsys lights`.
  `mLightsByType` holds one `LightImpl` per system type, which the system services get with `LightsManager.getLight(LIGHT_ID_*)`.
  If the HAL reports 2 lights of the same system type, the system services use only the first one.
+ The camera flash is not a light here. The Camera HAL controls it.
+ AOSP's `hardware/interfaces/light/aidl/default` only logs. The board's HAL (from the Rockchip SDK or your own) contains the real sysfs code.

## 2. System lights vs. lights that apps can use

`LightType` has a fixed set of values. `LightsService` splits them into 2 groups:

| | System lights | Other lights |
| --- | --- | --- |
| Types | `BACKLIGHT`, `KEYBOARD`, `BUTTONS`, `BATTERY`, `NOTIFICATIONS`, `ATTENTION`, `BLUETOOTH`, `WIFI` (the old HIDL set) | Types added later, such as `MICROPHONE` |
| Who controls them | Framework policy only (battery level, notifications, display) | Privileged apps, through `android.hardware.lights.LightsManager` sessions |
| Listed by `LightsManager.getLights()` | No | Yes |

+ The split depends only on the `type` that the HAL reports, not on the caller or on what the LED means.
  In `LightsService.java`, `LightImpl.isSystemLight()` checks whether the type is one of the system light IDs (below `LightsManager.LIGHT_ID_COUNT`).
  The binder service skips those lights in `getLights()` and rejects session requests for them.
+ `MICROPHONE` is a non-system type, even though it is an indicator. The camera and microphone privacy indicators on the screen come from SystemUI, not from `LightsService`.
+ So whether an app can control a board LED is decided in the vendor HAL: the type it gives the LED in `getLights()`.

The `LightsManager` API needs `CONTROL_DEVICE_LIGHTS` (signature|privileged).
A session's request is undone when the session is closed or its process dies.
For the app side, see [gpio_control.md](gpio_control.md#22-lightsmanager-android-12-api-31).

Two classes are called `LightsManager`. Don't mix them up:

| | `android.hardware.lights.LightsManager` | `com.android.server.lights.LightsManager` |
| --- | --- | --- |
| Kind | Public SDK API (Android 12, API 31+) | Internal abstract class, local service in `system_server` |
| Used by | Privileged apps and system apps | `BatteryService`, `NotificationManagerService`, `DisplayManagerService` |
| Reaches `LightsService` through | Binder service `lights` (`ILightsManager`) | A direct Java call (same process) |
| Lights it can control | Only the non-system types | The system types (`getLight(LIGHT_ID_*)`) |
| Model | `openSession()`, `LightsRequest`, `requestLights()`; reverted on close | Set a `LogicalLight`'s state directly; stays until changed |

Neither one talks to the HAL. Only `LightsService` holds the `ILights` binder.

### 2.1 Who wins when several clients want a light

`LightsService` arbitrates only between `LightsManager` sessions.
For system lights there is nothing to arbitrate in the framework, because each type has one owner.

| | System lights | Other lights (sessions) |
| --- | --- | --- |
| Who sets them | One framework service per type: `BatteryService` sets `BATTERY`, `NotificationManagerService` sets `NOTIFICATIONS` and `ATTENTION` | Any number of sessions from privileged apps |
| Several requests at once | Not arbitrated: the owner sets the state directly and it stays until the owner changes it | The highest-priority session that requests the light wins |
| A request ends | Doesn't apply | The light falls back to the next session's request, or turns off if no session requests it |

How sessions are resolved:

+ Each session holds one `LightState` per light `id`. `requestLights(LightsRequest)` sets them. `LightsRequest.Builder.clearLight(light)` removes one light from the session's request.
+ Sessions can have a priority. Newer API levels add `openSession(int priority)`; check the [`LightsManager`](https://developer.android.com/reference/android/hardware/lights/LightsManager) reference for your API level.
+ After every change (a new request, `close()`, or the process dying, which `LightsService` sees as binder death), `LightsService` recomputes every non-system light from all open sessions.
  A light that no session requests is turned off.
+ Only the result goes to the HAL, and only if it differs from the last state sent (section 3.1).

A closed session or a dead process can't keep a light on.
If a session light stays on, a live process still holds an open session, for example a service that never calls `close()`.

Arbitration works per logical light `id`. It doesn't help when the HAL maps several lights to one physical LED (section 3.2).

## 3. Pitfalls

### 3.1 Unchanged requests don't reach the HAL

`LightImpl.setLightLocked()` remembers the last state it sent (color, mode, on/off times, brightness mode).
If a client sends the same state again, `LightsService` doesn't call the HAL.

+ If you change a LED with `echo ... > /sys/class/leds/...` during debugging, the framework doesn't know about it.
  An identical request afterward won't restore the LED; only a different state does.
+ After a HAL restart, the HAL may also be out of sync until the next state change.

### 3.2 Several light types on one physical LED

`LightsService` treats each `HwLight` as independent, and neither system lights nor session arbitration (section 2.1) look past the light `id`.
If the HAL maps more than one type to the same LED (for example `BATTERY` and `NOTIFICATIONS` on one RGB LED, which is common on small boards), **the HAL must arbitrate**.
It keeps the latest state of each logical light and decides which one wins (usually notification over battery).
Without this, the last writer wins, and turning off the notification also turns off the charging indication.

### 3.3 Backlight brightness is 8-bit

+ `DisplayManagerService` first tries `SurfaceControl.setDisplayBrightness()`, which goes through SurfaceFlinger to the Composer HAL.
  Only if the display doesn't support it, it uses the `BACKLIGHT` light from `LightsService`.
+ On the `LightsService` path, the float brightness (`0.0`–`1.0`) is converted to an integer `0..255` and packed into `color` as gray: `0xFF000000 | (b << 16) | (b << 8) | b`.
+ The HAL must scale this to the panel's `max_brightness`.
  With `pwm-backlight`, `max_brightness` comes from the device tree (`brightness-levels`, `num-interpolated-steps`), so it can be `255`, `1023`, or anything else.
+ If the brightness feels wrong (steps, a dark range, or no full brightness), check the HAL's scaling, the DT `brightness-levels` table, and the brightness overlay (`config_screenBrightness*` in the device's framework overlay).

### 3.4 Permissions on the sysfs nodes

The HAL runs as a non-root user in `hal_light_default`. It needs:

+ DAC: `ueventd.rc` entries that give `brightness` (and `trigger`, if it blinks) to the HAL's user.
  `delay_on` / `delay_off` are created only after `trigger=timer`, so `ueventd.rc` doesn't always cover them.
+ SELinux: a `genfscon` label (`sysfs_leds` for LEDs) and `allow` rules for `hal_light_default`.

An `EACCES` or an `avc: denied` in `logcat` means one of these is missing.
The exact rules are in [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#5-init-vintf-ueventd-selinux) and [hw_control_sysfs.md](hw_control_sysfs.md).

## 4. Inspect and test

Debug from the bottom up. First make sure the kernel can switch the LED by writing `/sys/class/leds/<name>/brightness`, and only then look at the HAL and the framework.

| Symptom | Where to look |
| --- | --- |
| Writing `brightness` by hand does nothing | Kernel side: the `.dts` LED node (pin, `GPIO_ACTIVE_*`, pinctrl), the driver (`leds-gpio`, `leds-pwm`), and the board wiring |
| `SecurityException` from `LightsManager` | The caller lacks `CONTROL_DEVICE_LIGHTS` (not a privileged or platform-signed app, or missing from the privapp permission allowlist) |
| A light is missing from `LightsManager.getLights()` | Expected for system types (section 2). Otherwise the HAL doesn't report it: check `dumpsys lights` and the HAL's light table |
| A light is missing from `dumpsys lights` | The HAL didn't report it in `getLights()`, or the HAL wasn't declared or didn't start. `LightsService` reads the light list once when it starts, so a HAL fix needs a reboot |
| `dumpsys lights` shows the new state, but the LED doesn't change | The HAL's sysfs write failed: DAC or SELinux (section 3.4), a wrong node name, or the wrong `id` mapping (section 4.2). Or the write worked, but a kernel trigger from the device tree (`linux,default-trigger`, e.g. `heartbeat`) still drives the LED because the HAL doesn't write `trigger=none`, or the node exists but this board variant has no LED fitted |
| The LED changes, then something else switches it back | Another logical light shares the LED (section 3.2), framework policy owns that system type, or a higher-priority session requests the light (section 2.1) |
| A session light stays on after the app is "done" | The app or one of its services still holds the session open (section 2.1) |

`LightsManager` and `LightsService` work with the logical lights that the HAL reports, never with RK3566 pin names such as `GPIO0_C5`.
The mapping from a light `id` to a sysfs node, and from that node to a pin, lives in the HAL and the device tree.

```shell
# lights reported by the HAL, their types, and the current state
adb shell dumpsys lights

# is the AIDL HAL registered?
adb shell service list | grep -i light

# kernel nodes (userdebug / eng)
adb shell ls -l /sys/class/leds/ /sys/class/backlight/
adb shell ls -lZ /sys/class/leds/*/brightness

# HAL process and its SELinux domain
adb shell ps -AZ | grep -i light
adb logcat -d | grep -iE 'light|avc'
```

### 4.1 Reading `dumpsys lights`

`dumpsys lights` prints `LightsService`'s internal state. The exact format depends on the Android version, but it contains:

+ The HAL that `LightsService` uses (AIDL `ILights` or the HIDL fallback).
+ Every light the HAL reported, system and non-system, with its `id`, `ordinal`, type, and last state.
+ The open `LightsManager` sessions with their requests.

It doesn't mark which lights `LightsManager.getLights()` hides. Work that out from the type (section 2), or compare with what `getLights()` returns in a test app.

Example from an RK3566 board:

```text
LightsById:
  Light id=0 ordinal=0 color=ff666666, type=0
  Light id=1 ordinal=0 color=00000000, type=3
```

| Field | Meaning |
| --- | --- |
| `id` | Chosen by the HAL in `getLights()`. It is not a sysfs path or a pin; the HAL maps it to a node (section 4.2) |
| `ordinal` | Index among the lights of the same type |
| `color` | Last state sent to the HAL, as ARGB `0xAARRGGBB`. `00000000` is off. For `BACKLIGHT`, each RGB byte holds the brightness `0..255` (section 3.3): `ff666666` is `0x66` = 102, about 40 % |
| `type` | The `LightType` number ([table](../HAL/AIDL_HAL_lights.md#2-discovery-getlights)): here `0` = `BACKLIGHT`, `3` = `BATTERY` |

+ This board reports only a backlight and a battery LED. There is no `NOTIFICATIONS` light, so the notification LED can't work ([notification_led.md](notification_led.md#2-why-the-led-stays-off)).
  Both are system types, so `LightsManager.getLights()` returns an empty list.
+ The `BACKLIGHT` color changes only when `DisplayManagerService` uses the `LightsService` path (section 3.3). If the display uses Composer brightness, the value stays the same while the brightness slider moves.
+ `LightType` is a fixed AOSP enum. A vendor can't add its own types; it only chooses the `id`s and which types to report.

### 4.2 From a light `id` to its sysfs node

Neither `dumpsys lights` nor `LightsService` knows the sysfs path. The mapping is in the HAL's board table ([../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#21-the-board-table)).

1. **Find the HAL and its table.** List the candidate nodes and the HAL process on the target:

   ```shell
   adb shell ls -l /sys/class/leds/ /sys/class/backlight/
   adb shell ps -A | grep -i light
   adb shell ls /vendor/bin/hw | grep -i light
   ```

   In the BSP source, search the HAL for its table, for example `grep -rn "LightType::\|/sys/class/leds\|/sys/class/backlight" device/ hardware/ vendor/`.
   The location depends on the BSP. Match the node names with the LED `label`s in the board's `.dts` under `arch/arm64/boot/dts/rockchip/`.

2. **Confirm on the target.** Change a light from the framework, then compare `dumpsys lights` with the nodes. The light whose `color` changes together with one node's `brightness` is the match.

   | Light | How to change it |
   | --- | --- |
   | `BATTERY` | Plug or unplug the charger, or fake it with `dumpsys battery` (below) |
   | `BACKLIGHT` | The brightness slider, or `adb shell settings put system screen_brightness 50` with auto-brightness off |
   | `NOTIFICATIONS` | See [notification_led.md](notification_led.md#3-test) |

   ```shell
   # fake a low battery on AC power, then restore the real values
   adb shell dumpsys battery set ac 1
   adb shell dumpsys battery set level 10
   adb shell dumpsys lights
   adb shell 'for d in /sys/class/leds/*; do echo "$d brightness=$(cat $d/brightness) trigger=$(grep -o "\[[^]]*\]" $d/trigger)"; done'
   adb shell dumpsys battery reset
   ```

   The active trigger is the one in `[...]`. Anything other than `[none]` means the kernel, not only the HAL, changes that LED.

3. **Check the HAL's log.** If the HAL logs its writes or errors, `adb logcat | grep -iE 'light|avc'` shows which node it opened and whether the write failed.

| Compare | Shows |
| --- | --- |
| `dumpsys lights` vs. the HAL's light table | Whether `LightsService` got every light from the HAL |
| `dumpsys lights` vs. `LightsManager.getLights()` in the app | Which lights are system types (listed by `dumpsys` only) |
| Sessions in `dumpsys lights` before and after the app's request | Whether the request reached `LightsService`, and which session wins (section 2.1) |
| Last state in `dumpsys lights` vs. the sysfs node | Whether the HAL's write worked (section 3.4) |

## 5. Can a non-LED GPIO go through LightsService?

Technically yes.
Declare the pin in the device tree as a `gpio-leds` node, so it appears as `/sys/class/leds/<label>/brightness` (`0` / `1`).
Then let the Lights HAL report it as a `HwLight`, and switch it by changing that light's state.
But for anything other than an indicator, this is a workaround.

| Problem | Why |
| --- | --- |
| You don't control system lights | If the pin is reported as `NOTIFICATIONS` or `ATTENTION`, framework policy switches it, not your code ([notification_led.md](notification_led.md#4-driving-a-non-led-gpio-from-notifications)) |
| Limited, fixed types | There is no OEM-defined `LightType`. A privileged app can use only the non-system types through `LightsManager`, and the state is reverted when the session closes |
| Wrong semantics | The state is a color with blink times. A relay, fan, buzzer, or enable pin has none of these |
| Coupling | Battery, notification, or display policy changes can toggle unrelated hardware, and the state cache (section 3.1) hides out-of-band changes |

Better options:

| The GPIO ... | Use |
| --- | --- |
| Is a status or indicator LED | `gpio-leds` + the Lights HAL if the meaning is standard, otherwise a vendor LED HAL: [Led_control.md](Led_control.md) |
| Switches power to a device | `regulator-fixed` / `regulator-gpio` or a power-sequence node in the device tree, so the kernel driver handles it: [../../Linux/DeviceTree/dts_node_regulator_fixed.md](../../Linux/DeviceTree/dts_node_regulator_fixed.md) |
| Is general I/O for a product feature (relay, fan, reset line) | A vendor AIDL HAL with libgpiod, called through Binder by a system app or service: [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md) |
| Only needs a quick hardware check | `adb root` + `gpioset` / `gpioget` (if libgpiod tools are in the build): [libgpiod_android.md](libgpiod_android.md) |

Going through `LightsService` makes sense only when the GPIO really is an on/off indicator that should follow a standard Android event (battery, notification), and you don't want to add a new HAL.
To choose between `gpio-leds` and a plain GPIO in the device tree, see [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md).

## Related notes

+ [Led_control.md](Led_control.md): choosing between the Lights HAL, a vendor LED HAL, and sysfs; blinking in the kernel
+ [gpio_control.md](gpio_control.md): RK3566 GPIO numbering, notification LED and `LightsManager` from an app
+ [notification_led.md](notification_led.md): how `NotificationManagerService` drives the notification LED, and why it stays off
+ [battery_led.md](battery_led.md): how `BatteryService` drives the battery LED (states, overlay colors, red + green LED example)
+ [LightsService_platform_app.md](LightsService_platform_app.md): what a platform-signed app can do with lights, and a custom binder service in `system_server`
+ [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md): implementing the Lights HAL for RK3566 (C++ NDK example, VINTF, SELinux)
+ [../HAL/HAL_sysfsNodes.md](../HAL/HAL_sysfsNodes.md): how a Lights HAL wraps sysfs
+ [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md), [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md), [hw_control_sysfs.md](hw_control_sysfs.md)
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)

## Reference

+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [`LightsManager`](https://developer.android.com/reference/android/hardware/lights/LightsManager)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
