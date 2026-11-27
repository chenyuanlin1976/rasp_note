# From a physical button to an Android KeyEvent

This note follows one key press from a physical button to an app's `onKeyDown()`, using a green button on an RK3566 board as the example.
The path goes through a kernel input driver, a key layout (`.kl`) file, and the input pipeline in `system_server`.

## 1. Overview

```text
 [Green button] --GPIO edge/IRQ--> gpio-keys driver --> input core --> /dev/input/eventN
                                   (linux,code = KEY_GREEN = 399)        EV_KEY 399 1/0 + EV_SYN
                                                                              |
 ------------------------------ user space (system_server, inputflinger) -----|------------
                                                                              v
 EventHub         reads eventN, loads the .kl file for the device: scancode 399 -> PROG_GREEN
 InputReader      KeyboardInputMapper -> NotifyKeyArgs(AKEYCODE_PROG_GREEN = 184)
 InputDispatcher  -> PhoneWindowManager.interceptKeyBeforeQueueing()     (power/volume/wake)
                  -> PhoneWindowManager.interceptKeyBeforeDispatching()  (home, global keys)
                  -> InputChannel (socket) to the focused window
 App              ViewRootImpl -> Activity.dispatchKeyEvent -> onKeyDown(KEYCODE_PROG_GREEN)
```

Two different numbers identify the key:

| | Linux scancode | Android keycode |
| --- | --- | --- |
| Defined in | `include/uapi/linux/input-event-codes.h` | `KeyEvent.java`, `android/keycodes.h` |
| Example | `KEY_GREEN` = 0x18f = 399 | `KEYCODE_PROG_GREEN` = 184 |
| Set by | Device tree (`linux,code`) or the driver | The key layout (`.kl`) file |

The `.kl` file connects them.

The key changes form at three boundaries:

| Boundary | Input | Output | Controlled by |
| --- | --- | --- | --- |
| Hardware → kernel | GPIO edge, (row, col), ADC level | Linux scancode (`EV_KEY` code) | `.dts`/`.dtsi` + kernel input driver |
| Kernel → InputReader | Linux scancode | Android keycode + policy flags | `.kl` file |
| InputReader → app | Android keycode + meta state | `KeyEvent`, Unicode character | `.kcm` file, `PhoneWindowManager`, IME, app |

## 2. Kernel side

### 2.1 Device tree (gpio-keys)

The button is on `GPIO0_B4` (`gpiochip0`, offset 1*8 + 4 = 12), active low with a pull-up.

```dts
#include <dt-bindings/input/input.h>
#include <dt-bindings/pinctrl/rockchip.h>

/ {
    green_keys: gpio-keys-green {
        compatible = "gpio-keys";
        label = "green-key";              /* input device name, used for the .kl file name */
        pinctrl-names = "default";
        pinctrl-0 = <&green_key_pin>;

        button-green {
            label = "Green";
            linux,code = <KEY_GREEN>;     /* 399 */
            gpios = <&gpio0 RK_PB4 GPIO_ACTIVE_LOW>;
            debounce-interval = <20>;     /* ms */
            wakeup-source;                /* optional: wake from suspend */
        };
    };
};

&pinctrl {
    green-key {
        green_key_pin: green-key-pin {
            rockchip,pins = <0 RK_PB4 RK_FUNC_GPIO &pcfg_pull_up>;
        };
    };
};
```

The `gpio-keys` driver requests the GPIO and its IRQ, then debounces the input.
On each change it calls `input_report_key(dev, KEY_GREEN, 1 or 0)` and `input_sync()`.
The evdev handler exposes the device as `/dev/input/eventN`.

`gpio-keys` claims the line, so libgpiod can no longer request it (see [gpio_control.md](gpio_control.md)).
Other button sources work the same way through a different driver: `adc-keys` (resistor ladder on a SARADC channel), a matrix keypad (section 2.2), a PMIC power key, or an I2C/USB HID keyboard.
All of them end in `EV_KEY <code>` events.

Where the nodes go: the SoC `.dtsi` defines the controllers (`gpio0`..`gpio4`, `saradc`). The board `.dts` (or a board `.dtsi` shared by several variants) adds the button nodes, enables the controllers, and overrides properties through `&label { ... };`.

### 2.2 Matrix keypads

A keypad with rows and columns uses `gpio-matrix-keypad` (`CONFIG_KEYBOARD_MATRIX`).
The driver drives one column at a time and reads the rows.
`linux,keymap` lists one `MATRIX_KEY(row, col, code)` entry per key; the macro comes from `<dt-bindings/input/input.h>`.
In this example, all four pins are on `GPIO3_A0`..`GPIO3_A3` (`gpiochip3`, offsets 0–3).

```dts
#include <dt-bindings/input/input.h>
#include <dt-bindings/pinctrl/rockchip.h>

/ {
    matrix-keypad {
        compatible = "gpio-matrix-keypad";
        row-gpios = <&gpio3 RK_PA0 GPIO_ACTIVE_HIGH>,
                    <&gpio3 RK_PA1 GPIO_ACTIVE_HIGH>;
        col-gpios = <&gpio3 RK_PA2 GPIO_ACTIVE_HIGH>,
                    <&gpio3 RK_PA3 GPIO_ACTIVE_HIGH>;
        linux,keymap = <
            MATRIX_KEY(0, 0, KEY_1)
            MATRIX_KEY(0, 1, KEY_2)
            MATRIX_KEY(1, 0, KEY_3)
            MATRIX_KEY(1, 1, KEY_ENTER)
        >;
        debounce-delay-ms = <10>;
        col-scan-delay-us = <10>;
    };
};
```

The row pins need pull resistors (pinctrl or external) so they read a defined level when no key is pressed.
From this point on, the keypad is just another input device: check its name with `getevent -i`, then write a `.kl` file for it the same way as for `gpio-keys`.

### 2.3 Check the kernel events

Each `/dev/input/eventN` read returns `struct input_event` records: `type` (`EV_KEY`, `EV_SYN`, ...), `code` (the scancode), and `value` (`1` press, `0` release, `2` kernel autorepeat).
Android turns off kernel autorepeat when EventHub opens the device, and InputDispatcher generates repeats itself, so a `value` of `2` normally doesn't reach Android.

```shell
adb shell getevent -i     # lists devices: name "green-key", bus/vendor/product/version
adb shell getevent -lt    # press the button:
# [   123.456789] /dev/input/event3: EV_KEY  KEY_GREEN  DOWN
# [   123.456789] /dev/input/event3: EV_SYN  SYN_REPORT 00000000
# [   123.601234] /dev/input/event3: EV_KEY  KEY_GREEN  UP

adb shell cat /proc/bus/input/devices                 # name, IDs, handlers (eventN), key bitmap
adb shell cat /sys/class/input/event3/device/name     # also id/vendor, id/product, id/version, capabilities/key
```

If nothing appears here, the problem is in the kernel (DT node, pinctrl, polarity, `CONFIG_KEYBOARD_GPIO` / `CONFIG_KEYBOARD_MATRIX`), not in Android.

## 3. Android side

### 3.1 EventHub: open the device and load its config

EventHub (`frameworks/native/services/inputflinger/reader/EventHub.cpp`) runs inside `system_server`.
It watches `/dev/input` with inotify. When a device appears, it reads the identity (name, bus, vendor, product, version) and loads three kinds of files:

| File | Purpose |
| --- | --- |
| `.kl` (key layout) | scancode → Android keycode, plus flags such as `WAKE` |
| `.kcm` (key character map) | keycode → characters; only matters for text keyboards |
| `.idc` (input device configuration) | device properties (touch, keyboard type, ...) |

Android tries these `.kl` names in order, and the first match wins:

1. `Vendor_XXXX_Product_XXXX_Version_XXXX.kl`
2. `Vendor_XXXX_Product_XXXX.kl`
3. `<device name>.kl`, where characters other than letters, digits, `-` and `_` become `_`
4. `Generic.kl`

Each name is searched in several directories, including `/odm/usr/keylayout/`, `/vendor/usr/keylayout/`, `/system/usr/keylayout/` and `/data/system/devices/keylayout/`.

`gpio-keys` reports a generic ID (vendor 0001, product 0001), so match by device name instead.

### 3.2 The key layout file

`/vendor/usr/keylayout/green-key.kl`:

```text
key 399   PROG_GREEN
# to wake the device from suspend:
# key 399   PROG_GREEN   WAKE
```

Each line is `key <scancode> <KEYCODE without the KEYCODE_ prefix> [flags]`. The flags are:

| Flag | Meaning |
| --- | --- |
| `WAKE` | The key wakes the device when it is asleep |
| `VIRTUAL` | A virtual (capacitive or on-screen) key; enables haptic feedback and touch-slop handling |
| `FUNCTION` | Interpret the key as if the Fn modifier were pressed |
| `GESTURE` | The key is generated by a user gesture, such as palming the touchscreen |

Install it from the device makefile:

```text
PRODUCT_COPY_FILES += \
    device/<vendor>/<board>/green-key.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/green-key.kl
```

AOSP's `Generic.kl` already maps 398–401 to `PROG_RED`, `PROG_GREEN`, `PROG_YELLOW` and `PROG_BLUE`.
A device-specific file still makes the mapping explicit, and it lets you map the same scancode to another keycode.

### 3.3 InputReader

InputReader sees `EV_KEY` bits and classifies the device as a keyboard.
Its `KeyboardInputMapper` looks up scancode 399 in the loaded layout, gets `AKEYCODE_PROG_GREEN`, adds meta state and policy flags (such as `WAKE`), and passes a `NotifyKeyArgs` to the dispatcher.
If the scancode isn't in the layout, the keycode is `KEYCODE_UNKNOWN` (0).

For keys that type text, the `.kcm` file turns the keycode plus meta state (Shift, Alt, Ctrl) into a character, which apps read with `KeyEvent.getUnicodeChar()`.
Text fields usually get their text from the IME through `InputConnection` instead.
A single button doesn't need a `.kcm` file.

### 3.4 InputDispatcher and the window manager policy

The dispatcher asks the policy, `PhoneWindowManager`, about each key twice:

+ **`interceptKeyBeforeQueueing()`** runs first, even when the screen is off. Power, volume and screen wake are handled here.
+ **`interceptKeyBeforeDispatching()`** runs just before delivery. Home, global keys and shortcuts are handled here.

If neither step consumes the key, it goes to the **focused window** over that window's InputChannel (a socket pair).
While a key is held down, the dispatcher also generates the repeat events (`getRepeatCount() > 0`).

### 3.5 App

```kotlin
override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
    if (keyCode == KeyEvent.KEYCODE_PROG_GREEN) {
        // handle the green button
        return true
    }
    return super.onKeyDown(keyCode, event)
}
```

## 4. Debugging

```shell
adb shell getevent -lt                              # kernel events (section 2.3)
adb shell dumpsys input | grep -A15 green-key       # look for KeyLayoutFile: /vendor/usr/keylayout/green-key.kl
adb shell input keyevent KEYCODE_PROG_GREEN         # app side only: skips the kernel and the .kl file
adb logcat -s InputReader InputDispatcher           # device add/remove, mapping errors
```

| Symptom | Likely cause |
| --- | --- |
| No events in `getevent` | DT node, pinctrl/pull, polarity, or driver not enabled |
| `getevent` OK, app gets nothing | Wrong `.kl` name or path, missing mapping (`KeyLayoutFile` in `dumpsys input`), or the app window isn't focused |
| `dumpsys input` shows `Generic.kl` | Your `.kl` file name doesn't match the device name |
| Key doesn't wake the device | No `wakeup-source` in DT, or no `WAKE` flag in `.kl` |

## 5. Design notes

+ **Only the focused window receives keys.** To react while your app is in the background, handle the key in the policy layer (`PhoneWindowManager` in your platform build), or use an `AccessibilityService` that requests key event filtering. A normal background app can't receive keys.
+ **Reuse an existing keycode.** Good choices are `PROG_RED/GREEN/YELLOW/BLUE`, `F1`–`F12` and `BUTTON_1`–`BUTTON_16`. A new Android keycode needs changes in `keycodes.h`, the input event labels, `KeyEvent.java`, `attrs.xml` and the public API, so it's rarely worth it.
+ **No permission changes are needed.** `system_server` already reads `/dev/input/event*`, so you don't need `ueventd.rc` or SELinux changes. Those matter only if your own native daemon opens the event node directly.
+ **Kernel driver or libgpiod, not both.** A `gpio-keys` button is an input device. Use libgpiod only if the pin is a plain signal that no kernel driver owns.

## Related notes

+ [gpio_control.md](gpio_control.md): GPIO and LED control on the RK3566 board
+ [ADC_values.md](ADC_values.md): reading the RK3566 SARADC (the ADC that `adc-keys` buttons use)
+ [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md): `gpio-leds`, and when to use `gpio-keys` instead

## Reference

+ [Input (source.android.com)](https://source.android.com/docs/core/interaction/input)
+ [Key layout files (source.android.com)](https://source.android.com/docs/core/interaction/input/key-layout-files)
+ [Input device configuration files (source.android.com)](https://source.android.com/docs/core/interaction/input/input-device-configuration-files)
+ [KeyEvent (Android API)](https://developer.android.com/reference/android/view/KeyEvent)
+ [Input event codes (kernel docs)](https://docs.kernel.org/input/event-codes.html)
+ [gpio-keys binding (gpio-keys.yaml)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/input/gpio-keys.yaml)
