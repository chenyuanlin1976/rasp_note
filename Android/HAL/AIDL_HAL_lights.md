# Lights AIDL HAL: from `HwLight` to sysfs (RK3566)

The vendor Lights HAL implements AOSP's `android.hardware.light.ILights` and registers it as `android.hardware.light.ILights/default`.
It has 2 jobs:

1. **Discovery**: `getLights()` tells `LightsService` which lights the board has.
2. **State updates**: `setLightState(id, state)` turns an `HwLightState` into writes to `/sys/class/leds/<name>/` (`brightness`, and for blinking `trigger`, `delay_on`, `delay_off`).

This note covers the HAL side on an RK3566 board. For the framework side (`LightsService`, which lights the framework controls, the state cache), see [../HW/LightsService_intro.md](../HW/LightsService_intro.md).

The interface is Google's (`android.hardware.light`); the vendor only implements it.
A vendor's own interface would use `vendor.<company>.hardware.*` instead ([AIDL_HAL_impl.md](AIDL_HAL_impl.md)).

## 1. Connection: registration and lookup

```text
vendor: android.hardware.light-service.<board>            system_server: LightsService
  (started by its .rc, domain hal_light_default)
  AServiceManager_addService(                               waitForDeclaredService(
      "android.hardware.light.ILights/default")  <-------       "android.hardware.light.ILights/default")
            ^                                                       |
            |  servicemanager accepts it only if the                |  getLights()        once, at boot
            |  VINTF manifest declares ILights/default              |  setLightState()    on every change
            +-------------------------------------------------------+
```

+ The HAL registers only if the device's VINTF manifest declares the instance. Otherwise `servicemanager` rejects it ([VINTF_intro.md](VINTF_intro.md#5-declaring-an-aidl-hal)).
+ `LightsService` waits for the declared service and calls `getLights()` once. Lights that the HAL doesn't report then don't exist for the framework.
+ The SELinux pieces that don't depend on the board are already in AOSP: the attribute `hal_light` (with `hal_light_client` / `hal_light_server`), the domain `hal_light_default`, `system_server` as a `hal_light` client, and `hal_light_service` for the instance name in `service_contexts`.
  The board adds the label for its binary and the sysfs rules (section 5).

## 2. Discovery: `getLights()`

`getLights()` returns one `HwLight` per light:

| Field | Meaning |
| --- | --- |
| `id` | Chosen by the HAL and unique. `LightsService` passes it back in every `setLightState()` call |
| `ordinal` | Index among lights of the same type (`0` for the first) |
| `type` | `LightType`: `BACKLIGHT` (0), `KEYBOARD` (1), `BUTTONS` (2), `BATTERY` (3), `NOTIFICATIONS` (4), `ATTENTION` (5), `BLUETOOTH` (6), `WIFI` (7), `MICROPHONE` (8), `CAMERA` (9, added in a later interface version; check the `LightType.aidl` of the version your device uses). The enum is fixed: a vendor can't add types |

+ Report only lights whose sysfs node exists and is writable. Then `dumpsys lights` shows what really works, and the framework doesn't drive a missing LED.
+ The HAL needs a board table that maps each light to a node: compiled in (simplest), a config file in `/vendor/etc`, or system properties.
+ The node name comes from the device tree: the `label`, or `function` + `color` in newer bindings ([../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md)).
  If the table and the DT don't match, the light is missing or every write fails.

### 2.1 The board table

In the example (section 4), the table is a compile-time array that maps a `LightType` to an LED class directory:

```c++
constexpr BoardLed kBoardLeds[] = {
        {LightType::BATTERY, "/sys/class/leds/led_r"},
        {LightType::NOTIFICATIONS, "/sys/class/leds/led_g"},
};
```

The constructor turns each entry whose `brightness` is writable into an `HwLight`, and `setLightState()` finds the directory by `id`.
An entry whose node is missing (for example on another board variant) is skipped, so the HAL still starts.

**Which types to list.** A type is useful only if something calls it:

| Type | Who drives it |
| --- | --- |
| `BATTERY`, `NOTIFICATIONS` | `BatteryService`, `NotificationManagerService` ([../HW/notification_led.md](../HW/notification_led.md)) |
| `ATTENTION` | `NotificationManagerService`, only if `config_useAttentionLight` is `true` |
| `BACKLIGHT` | `DisplayManagerService`, only if the display has no Composer brightness control. The node is usually `/sys/class/backlight/<name>/`, not an LED, and needs its own scaling ([../HW/LightsService_intro.md](../HW/LightsService_intro.md#33-backlight-brightness-is-8-bit)) |
| `MICROPHONE` and later types | A privileged app through `LightsManager` ([../HW/LightsService_intro.md](../HW/LightsService_intro.md#2-system-lights-vs-lights-that-apps-can-use)) |
| `BLUETOOTH`, `WIFI`, `KEYBOARD`, `BUTTONS` | System types, so apps can't use them through `LightsManager`. Stock AOSP has no caller for `BLUETOOTH` / `WIFI`, so such a light does nothing without a framework change |

Check which types have a caller in your source tree with `grep -rn "LIGHT_ID_" frameworks/base/services/`.
For a Wi-Fi or Bluetooth status LED, a kernel trigger is usually simpler than the HAL: for example `phy0rx` / `phy0tx` (mac80211) or `bluetooth-power`, if the driver provides them. The `bcmdhd` Wi-Fi driver, common on RK3566 boards, doesn't use mac80211, so it has no `phy0*` triggers ([../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md)).

**Extra fields, when the board needs them:**

| Field | When | Note |
| --- | --- | --- |
| `max_brightness` override | Rarely | Read `<dir>/max_brightness` at startup (as the example does): `1` for `leds-gpio`, often `255` for `leds-pwm`. Hard-code it only if the driver reports a wrong value |
| Red, green, blue paths | One `LightType` drives a tri-color LED made of 3 LED class devices | Split `color` into channels ([section 3](#3-state-updates-setlightstate)). A multicolor LED class device instead has one `brightness` plus `multi_intensity` |
| Blink support | Never as a fixed flag | Read `<dir>/trigger` at startup and check that `timer` is in the list. If it isn't, enable `CONFIG_LEDS_TRIGGER_TIMER` rather than blinking in the HAL |
| Active-low | Never in the HAL | Set the polarity in the device tree (`GPIO_ACTIVE_LOW`). The LED class then shows the logical state: `brightness=0` is off for every driver. Inverting in the HAL breaks triggers, because writing `0` also removes the trigger |

Check the table against the target:

```shell
# every directory in kBoardLeds[] must exist (names from the DT label, or function + color)
adb shell ls -ld /sys/class/leds/led_r /sys/class/leds/led_g
adb shell cat /sys/class/leds/led_r/max_brightness /sys/class/leds/led_r/trigger
```

## 3. State updates: `setLightState()`

`HwLightState` fields and how a sysfs HAL usually handles them:

| Field | Values | Handling |
| --- | --- | --- |
| `color` | ARGB `0xAARRGGBB` | **RGB LED** (3 LED class devices): write `(color >> 16) & 0xFF`, `(color >> 8) & 0xFF`, `color & 0xFF` to the red, green, and blue `brightness`, each scaled to its `max_brightness`. **Single LED**: any non-zero RGB (`(color & 0x00FFFFFF) != 0`) is on. Use `1` for a GPIO LED, or a level scaled to `max_brightness` for a PWM LED. **Backlight**: the brightness `0..255` is in each RGB byte ([../HW/LightsService_intro.md](../HW/LightsService_intro.md#33-backlight-brightness-is-8-bit)) |
| `flashMode` | `NONE` (0), `TIMED` (1), `HARDWARE` (2) | `NONE`: set the brightness, no trigger. `TIMED`: kernel `timer` trigger with `delay_on` / `delay_off`. `HARDWARE`: like `TIMED` unless the LED controller has its own blink engine |
| `flashOnMs`, `flashOffMs` | milliseconds | Used only for `TIMED` / `HARDWARE`. If one is `0`, don't blink |
| `brightnessMode` | `USER` (0), `SENSOR` (1), `LOW_PERSISTENCE` (2) | Mostly for the backlight. A sysfs HAL usually ignores it |

Write order for one LED (`LED=/sys/class/leds/<name>`):

| Wanted state | Writes |
| --- | --- |
| Off | `0` → `brightness` (also removes the trigger) |
| On | `none` → `trigger`, then the level → `brightness` |
| Blink | the level → `brightness`, `timer` → `trigger`, then `delay_on`, `delay_off` (they exist only after `trigger=timer`) |

+ Use the kernel trigger rather than a blink thread in the HAL: no process wakes up for every edge ([../HW/Led_control.md](../HW/Led_control.md#3-blink-in-the-kernel-not-with-an-app-timer)).
  It needs `CONFIG_LEDS_TRIGGER_TIMER` in the kernel config.
+ If several light types share one physical LED (e.g. `BATTERY` and `NOTIFICATIONS`), keep the last state of each and write only the winner ([../HW/LightsService_intro.md](../HW/LightsService_intro.md#32-several-light-types-on-one-physical-led)).
+ `setLightState()` can be called from several Binder threads; serialize the writes.

## 4. Example: a minimal sysfs Lights HAL (NDK backend)

2 single-color LEDs from a `gpio-leds` node: red for battery, green for notifications.
There is no RGB mixing, no shared LED, and no backlight. The board table is explained in [section 2.1](#21-the-board-table).

### Lights.h

```c++
#pragma once

#include <aidl/android/hardware/light/BnLights.h>

#include <map>
#include <mutex>
#include <string>
#include <vector>

namespace aidl::android::hardware::light::impl {

struct LedNode {
    HwLight light;          // id, ordinal, type reported to LightsService
    std::string dir;        // e.g. /sys/class/leds/led_r
    int maxBrightness = 1;  // read from max_brightness at startup
};

class Lights : public BnLights {
  public:
    Lights();
    ndk::ScopedAStatus getLights(std::vector<HwLight>* lights) override;
    ndk::ScopedAStatus setLightState(int32_t id, const HwLightState& state) override;

  private:
    std::map<int32_t, LedNode> mNodes;  // key: HwLight.id
    std::mutex mLock;
};

}  // namespace aidl::android::hardware::light::impl
```

### Lights.cpp

```c++
#define LOG_TAG "lights-rk3566"

#include "Lights.h"

#include <unistd.h>

#include <algorithm>
#include <cstdint>
#include <fstream>

#include <log/log.h>

namespace aidl::android::hardware::light::impl {
namespace {

// Board table: which LED class device backs which light type (names from the DT labels).
struct BoardLed {
    LightType type;
    const char* dir;
};
constexpr BoardLed kBoardLeds[] = {
        {LightType::BATTERY, "/sys/class/leds/led_r"},
        {LightType::NOTIFICATIONS, "/sys/class/leds/led_g"},
};

bool writeFile(const std::string& path, const std::string& value) {
    std::ofstream f(path);
    f << value;
    f.close();
    if (f.fail()) {
        ALOGE("cannot write '%s' to %s", value.c_str(), path.c_str());
        return false;
    }
    return true;
}

int readInt(const std::string& path, int fallback) {
    std::ifstream f(path);
    int v = 0;
    return (f >> v) ? v : fallback;
}

// ARGB -> brightness of a single LED: the brightest RGB channel, scaled to max_brightness.
int toBrightness(int32_t color, int maxBrightness) {
    const uint32_t c = static_cast<uint32_t>(color);
    const int level = std::max({(c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF});  // 0..255
    if (level == 0) return 0;
    return std::max(1, level * maxBrightness / 255);  // any non-zero color is on
}

}  // namespace

Lights::Lights() {
    int32_t id = 0;
    for (const auto& led : kBoardLeds) {
        const std::string dir = led.dir;
        if (access((dir + "/brightness").c_str(), W_OK) != 0) {
            ALOGW("%s/brightness not writable, light not reported", led.dir);
            continue;
        }
        LedNode node;
        node.light.id = id;
        node.light.ordinal = 0;
        node.light.type = led.type;
        node.dir = dir;
        node.maxBrightness = readInt(dir + "/max_brightness", 1);
        mNodes.emplace(id++, node);
    }
}

ndk::ScopedAStatus Lights::getLights(std::vector<HwLight>* lights) {
    for (const auto& [id, node] : mNodes) lights->push_back(node.light);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Lights::setLightState(int32_t id, const HwLightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    const auto it = mNodes.find(id);
    if (it == mNodes.end()) {
        return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
    }
    const LedNode& node = it->second;
    const int level = toBrightness(state.color, node.maxBrightness);
    const bool blink = state.flashMode != FlashMode::NONE && state.flashOnMs > 0 &&
                       state.flashOffMs > 0;

    if (level == 0) {
        writeFile(node.dir + "/brightness", "0");  // also removes the trigger
    } else if (blink) {
        writeFile(node.dir + "/brightness", std::to_string(level));
        writeFile(node.dir + "/trigger", "timer");  // creates delay_on / delay_off
        writeFile(node.dir + "/delay_on", std::to_string(state.flashOnMs));
        writeFile(node.dir + "/delay_off", std::to_string(state.flashOffMs));
    } else {
        writeFile(node.dir + "/trigger", "none");
        writeFile(node.dir + "/brightness", std::to_string(level));
    }
    return ndk::ScopedAStatus::ok();
}

}  // namespace aidl::android::hardware::light::impl
```

### main.cpp

```c++
#define LOG_TAG "lights-rk3566"

#include "Lights.h"

#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

using aidl::android::hardware::light::impl::Lights;

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(0);

    auto lights = ndk::SharedRefBase::make<Lights>();
    const std::string instance = std::string(Lights::descriptor) + "/default";
    const binder_exception_t err =
            AServiceManager_addService(lights->asBinder().get(), instance.c_str());
    if (err != EX_NONE) {
        ALOGE("cannot register %s: %d", instance.c_str(), err);
        return 1;
    }

    ABinderProcess_joinThreadPool();
    return 1;  // not reached
}
```

### Android.bp

```bp
cc_binary {
    name: "android.hardware.light-service.rk3566",
    relative_install_path: "hw",
    vendor: true,
    init_rc: ["android.hardware.light-service.rk3566.rc"],
    vintf_fragments: ["android.hardware.light-service.rk3566.xml"],
    srcs: [
        "Lights.cpp",
        "main.cpp",
    ],
    shared_libs: [
        "libbinder_ndk",
        "liblog",
        // Use a frozen version that the Android 14 framework compatibility matrix accepts
        // (see hardware/interfaces/compatibility_matrices/), and the same version in the manifest.
        "android.hardware.light-V2-ndk",
    ],
}
```

## 5. init, VINTF, ueventd, SELinux

```text
# android.hardware.light-service.rk3566.rc
service vendor.light-rk3566 /vendor/bin/hw/android.hardware.light-service.rk3566
    class hal
    user system
    group system
    shutdown critical
```

```xml
<!-- android.hardware.light-service.rk3566.xml: device manifest fragment -->
<manifest version="1.0" type="device">
    <hal format="aidl">
        <name>android.hardware.light</name>
        <version>2</version>
        <fqname>ILights/default</fqname>
    </hal>
</manifest>
```

For AIDL, `fqname` is `<interface>/<instance>` without the package.
`<version>` must match the `-V<N>-ndk` library.

```text
# vendor ueventd.rc: give the LED attributes to the HAL's user
/sys/devices/platform/leds/leds/*   brightness   0664  system  system
/sys/devices/platform/leds/leds/*   trigger      0664  system  system

# vendor/file_contexts: run the binary in AOSP's hal_light_default domain
/vendor/bin/hw/android\.hardware\.light-service\.rk3566   u:object_r:hal_light_default_exec:s0

# vendor/genfs_contexts: label the real path (adb shell readlink -f /sys/class/leds/<name>)
genfscon sysfs /devices/platform/leds/leds    u:object_r:sysfs_leds:s0

# vendor/hal_light_default.te
allow hal_light_default sysfs_leds:dir r_dir_perms;
allow hal_light_default sysfs_leds:lnk_file read;
allow hal_light_default sysfs_leds:file rw_file_perms;
```

`delay_on` / `delay_off` are created only when the trigger changes, so the `ueventd.rc` rules may not reach them.
Check with `ls -l` after `trigger=timer`. If they are still owned by `root`, see [../HW/Led_control.md](../HW/Led_control.md#5-why-the-app-cant-write-sysfs-itself).

## 6. Verify

```shell
# is the HAL declared and registered?
adb shell service check android.hardware.light.ILights/default
adb shell ps -AZ | grep -i light

# what LightsService got from getLights(), and the last state per light
adb shell dumpsys lights

# the LED's attributes, their owners, and labels (blink attributes appear only with trigger=timer)
adb shell ls -lZ /sys/class/leds/led_g/
adb shell cat /sys/class/leds/led_g/max_brightness /sys/class/leds/led_g/trigger

# HAL log and SELinux denials
adb logcat -s lights-rk3566 LightsService
adb logcat -d | grep 'avc: denied' | grep hal_light
```

If `service check` says "not found", look for a `servicemanager` rejection in `logcat` (instance not in the VINTF manifest) or a crash of the HAL process.

## Related notes

+ [../HW/LightsService_intro.md](../HW/LightsService_intro.md): the framework side, system lights, the state cache, backlight scaling
+ [../HW/notification_led.md](../HW/notification_led.md): how `NotificationManagerService` drives the notification light
+ [../HW/Led_control.md](../HW/Led_control.md): Lights HAL vs. a vendor LED HAL, kernel blink triggers
+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md), [VINTF_intro.md](VINTF_intro.md), [HAL_sysfsNodes.md](HAL_sysfsNodes.md)
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)

## Reference

+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [VINTF manifests](https://source.android.com/docs/core/architecture/vintf/objects)
+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
