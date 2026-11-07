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
Other button sources work the same way through a different driver: `adc-keys` (resistor ladder on a SARADC channel), a PMIC power key, or an I2C keypad.
All of them end in `EV_KEY <code>` events.

### 2.2 Check the kernel events

```shell
adb shell getevent -i     # lists devices: name "green-key", bus/vendor/product/version
adb shell getevent -lt    # press the button:
# [   123.456789] /dev/input/event3: EV_KEY  KEY_GREEN  DOWN
# [   123.456789] /dev/input/event3: EV_SYN  SYN_REPORT 00000000
# [   123.601234] /dev/input/event3: EV_KEY  KEY_GREEN  UP
```

If nothing appears here, the problem is in the kernel (DT node, pinctrl, polarity, `CONFIG_KEYBOARD_GPIO`), not in Android.

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

Each name is searched in several directories, including `/odm/usr/keylayout/`, `/vendor/usr/keylayout/` and `/system/usr/keylayout/`.

`gpio-keys` reports a generic ID (vendor 0001, product 0001), so match by device name instead.

### 3.2 The key layout file

`/vendor/usr/keylayout/green-key.kl`:

```text
key 399   PROG_GREEN
# to wake the device from suspend:
# key 399   PROG_GREEN   WAKE
```

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

### 3.4 InputDispatcher and the window manager policy

The dispatcher asks the policy, `PhoneWindowManager`, about each key twice:

+ **`interceptKeyBeforeQueueing()`** runs first, even when the screen is off. Power, volume and screen wake are handled here.
+ **`interceptKeyBeforeDispatching()`** runs just before delivery. Home, global keys and shortcuts are handled here.

If neither step consumes the key, it goes to the **focused window** over that window's InputChannel (a socket pair).

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
adb shell getevent -lt                              # kernel events (section 2.2)
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
+ [../Linux/dts_node_led_vs_gpio.md](../Linux/dts_node_led_vs_gpio.md): `gpio-leds`, and when to use `gpio-keys` instead

## Reference

+ [Input (source.android.com)](https://source.android.com/docs/core/interaction/input)
+ [Key layout files (source.android.com)](https://source.android.com/docs/core/interaction/input/key-layout-files)
+ [Input device configuration files (source.android.com)](https://source.android.com/docs/core/interaction/input/input-device-configuration-files)
+ [KeyEvent (Android API)](https://developer.android.com/reference/android/view/KeyEvent)
+ [Input event codes (kernel docs)](https://docs.kernel.org/input/event-codes.html)
+ [gpio-keys binding (gpio-keys.yaml)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/input/gpio-keys.yaml)
