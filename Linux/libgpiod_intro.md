# libgpiod

## control gpio pin standalone

To control your Wi-Fi power enable/disable pin standalone, you can use the modern `libgpiod` command-line tools.  
This bypasses the old sysfs interface and safely interacts with the GPIO chip directly.

1. Identify the Wi-Fi GPIO Chip and Line:  
   Run `gpiodetect` to list all available GPIO controllers on your system,  
   then use `gpiofind "enable"` (substituting your actual Wi-Fi enable label or pin name from your device tree) to find the exact chip and line offset.
2. Power Off the Wi-Fi Module:  
   Drive the enable pin low to cut power or disable the module using `gpioset`:  
   `gpioset <chip_name> <line_offset>=0`  
   Verification: Run `gpioget <chip_name> <line_offset>` to confirm the line reads 0.
3. Power On the Wi-Fi Module:  
   Drive the enable pin high to power it back on:  
   `gpioset <chip_name> <line_offset>=1`
   Verification: Run `gpioget <chip_name> <line_offset>` to confirm the line reads 1,  
   and check `dmesg` or `ip link` to see if the Wi-Fi interface re-initializes.

## AIDL with libgpiod

AIDL (Android Interface Definition Language) can work with this configuration, but indirectly.  
AIDL is strictly an Inter-Process Communication (IPC) mechanism used in Android to define interfaces between client applications and system services.  
**It does not communicate directly with the Linux kernel or Device Tree.**

Instead, **AIDL serves as the public contract for a native Hardware Abstraction Layer (HAL) service.**  
The architecture follows a layered path:

+ Android App or System Service calls the AIDL Interface.
+ The Native HAL Service (written in C++) processes the call.
+ The HAL code uses libgpiod to control the GPIO pin defined in your Device Tree (.dtsi).

### How to Connect Them

To control your GPIO configuration via AIDL:

+ Define the Interface: Create an .aidl file (e.g., IWifiControl.aidl) defining methods like enableWifi(boolean enable).
+ Implement the HAL: Create a C++ vendor service that inherits from the generated AIDL binder class.
+ Control the GPIO: Inside your C++ service implementation, use `libgpiod` functions (`gpiod_line_set_value`)  
  to drive the power enable pin high or low based on the AIDL request.
+ Verification: You can verify the HAL is communicating with the kernel by checking `dmesg` logs or running `gpioget`  
  while triggering the AIDL service call from an app shell command (`cmd <service_name>`).

## examples: AIDL service

Here is a complete, simplified example of how to implement an **AIDL (Android Interface Definition Language) service**  
that bridges an Android application down to the C++ HAL layer to control the Wi-Fi power GPIO pin.

### Step 1: Define the AIDL Interface

First, create an **.aidl file**.  
This defines the contract between Android apps/system services and your native hardware service.

```java, File: IWifiPowerControl.aidl
package android.hardware.wifi.power;

interface IWifiPowerControl {
    /**
     * Enables or disables Wi-Fi hardware power via GPIO.
     */
    boolean setWifiPower(boolean enable);

    /**
     * Gets the current power status of the Wi-Fi hardware.
     */
    boolean getWifiPowerStatus();
}
```

### Step 2: Implement the Native C++ HAL Service

The C++ service implements the generated **binder** interface and uses `libgpiod` to actually toggle the GPIO line defined in your Device Tree (.dtsi).

```c, WifiPowerControl.cpp
#include "android/hardware/wifi/power/BnWifiPowerControl.h"
#include <gpiod.h>
#include <android-base/logging.h>

namespace android {
namespace hardware {
namespace wifi {
namespace power {

class WifiPowerControl : public BnWifiPowerControl {
private:
    struct gpiod_chip *chip;
    struct gpiod_line *line;

public:
    WifiPowerControl() {
        // 1. Open the GPIO chip (e.g., gpiochip1)
        chip = gpiod_chip_open_by_name("gpiochip1");
        if (!chip) {
            LOG(ERROR) << "Failed to open GPIO chip";
            return;
        }
        
        // 2. Get the specific line offset for Wi-Fi power enable (e.g., line 12)
        line = gpiod_chip_get_line(chip, 12);
        if (!line) {
            LOG(ERROR) << "Failed to get GPIO line";
            return;
        }

        // 3. Request line as output, default low
        gpiod_line_request_output(line, "wifi-power", 0);
    }

    ~WifiPowerControl() {
        if (line) gpiod_line_release(line);
        if (chip) gpiod_chip_close(chip);
    }

    binder::Status setWifiPower(bool enable, bool* _aidl_return) override {
        if (!line) {
            *_aidl_return = false;
            return binder::Status::fromServiceSpecificError(-1);
        }

        // Drive the GPIO pin high (1) or low (0)
        int ret = gpiod_line_set_value(line, enable ? 1 : 0);
        *_aidl_return = (ret == 0);
        return binder::Status::ok();
    }

    binder::Status getWifiPowerStatus(bool* _aidl_return) override {
        if (!line) {
            *_aidl_return = false;
            return binder::Status::fromServiceSpecificError(-1);
        }

        // Read the current state of the pin
        int val = gpiod_line_get_value(line);
        *_aidl_return = (val == 1);
        return binder::Status::ok();
    }
};

} // namespace power
} // namespace wifi
} // namespace hardware
} // namespace android
```

### How It All Connects

+ The App/Framework calls `wifiPowerService.setWifiPower(true);`.
+ AIDL marshals this call across process boundaries using Android's binder driver.
+ The C++ Service receives the boolean, translates it via `libgpiod`, and toggles the physical GPIO line.
+ The Device Tree (.dtsi) configuration ensures the kernel allocated that exact line to the GPIO block during boot.
