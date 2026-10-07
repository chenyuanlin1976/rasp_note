# AIDL introduction

To understand the phrase "**AIDL serves as the public contract for a native Hardware Abstraction Layer (HAL) service**",  
it helps to break down how Android separates different software layers to keep the system secure, modular, and stable.

## 1. What is a "Contract"?

+ In software, a contract is a strict agreement on how two separate pieces of software will talk to each other.
+ It specifies the exact function names, inputs (arguments), and outputs (return values).
+ Neither side needs to know how the other is written internally; they only need to follow the rules of the contract.

## 2. What is the HAL (Hardware Abstraction Layer)?

Android devices run on many different chips (Qualcomm, MediaTek, Samsung, etc.).  
Each chip has different ways of interacting with physical hardware (like how a Wi-Fi chip is powered on).

+ The HAL is a collection of native (C/C++) services written by chipmakers or device manufacturers  
  that hide the messy, hardware-specific details from the rest of Android.
+ Android's core system and apps shouldn't care how a Wi-Fi chip turns on—they just want a simple command to turn it on.

## 3. Why AIDL is the Public Contract

Android apps and system services run in different processes (sandboxes) for security.  
A Java-based app cannot directly call a C++ function inside a native HAL service.

+ AIDL (Android Interface Definition Language) acts as the translator and the official agreement across this process boundary.
+ By writing an .aidl file (like IWifiPowerControl), you establish a standardized API contract.
+ The Android build system automatically generates the low-level code needed to pass data safely back  
  and forth across processes (via Android's Binder IPC driver).

**In short**: AIDL is the standardized rulebook that lets high-level Android software securely tell the low-level C++ hardware driver what to do,  
without crashing the system if something goes wrong.

## example

Here is a concrete, end-to-end example of how this contract works in practice,  
showing how a high-level caller uses the AIDL contract to talk to the low-level HAL service.

The Scenario: Turning Wi-Fi Power On: Imagine an Android system app wants to turn on the Wi-Fi hardware.  
**It cannot talk directly to the Linux kernel or the C++ hardware driver.**  
Instead, **it relies on the AIDL contract.**

### 1. The Contractual Agreement (.aidl)

Both the app developer and the C++ HAL developer look at the exact same file to agree on the rules:

```java
// File: IWifiPowerControl.aidl
package android.hardware.wifi.power;

interface IWifiPowerControl {
    boolean setWifiPower(boolean enable);
}
```

+ The Rule: Anyone calling this service must pass a boolean,  
  and the service must return a boolean indicating success or failure.  
  No other data formats are allowed.

### 2. The Client Side (The Android App / System Service)

**An Android system service uses the contract to make a request**.  
It doesn't know (or care) that C++ or libgpiod is running underneath; it only cares about the contract.

```java
// Java / Kotlin code in an Android System Service
try {
    // 1. Get the service using the AIDL interface name
    IBinder binder = ServiceManager.getService("wifi_power_service");
    IWifiPowerControl wifiService = IWifiPowerControl.Stub.asInterface(binder);

    // 2. Execute the contract method
    boolean success = wifiService.setWifiPower(true);
    if (success) {
        Log.d("WifiApp", "Wi-Fi power turned on successfully!");
    }
} catch (RemoteException e) {
    Log.e("WifiApp", "Failed to communicate with the hardware service", e);
}
```

### 3. The Server Side (The C++ Native HAL)

On the other side of the contract, the C++ HAL service implements that exact rule.  
Because it honors the contract, it receives the request safely from the app.

```c++
// C++ code implementing the service
binder::Status WifiPowerControl::setWifiPower(bool enable, bool* _aidl_return) {
    // The contract guaranteed a boolean ('enable') was passed.
    // Now the HAL uses its low-level tools (like libgpiod) to fulfill it:
    
    int value = enable ? 1 : 0;
    int ret = gpiod_line_set_value(wifi_gpio_line, value);

    // Return the boolean result back across the contract
    *_aidl_return = (ret == 0);
    return binder::Status::ok();
}
```

### Why this structure matters

+ Decoupling: If the chip manufacturer updates the C++ code or changes how `libgpiod` talks to the kernel,  
  they don't have to change anything in the Android app.  
  As long as the C++ code still fulfills the IWifiPowerControl contract, everything works seamlessly.
+ Safety: If the C++ hardware driver crashes due to a low-level kernel error,  
  Android's process isolation prevents it from crashing the entire operating system or the user's app.

## config in the .dtsi

To configure a GPIO pin for a Wi-Fi power enable/disable function in a Device Tree Source Include (.dtsi) file,  
you need to add a pin definition inside your Wi-Fi device node, referencing the correct SoC GPIO controller bank and line.

### Configuration Steps

1. Locate the GPIO Controller Node:  
   Find the parent GPIO controller alias or label in your SoC's base .dtsi file (e.g., &gpio1 or &pio). You will need its reference handle.
2. Add the Pin Property to your Device Node:  
   Inside your device's node block, define your power pin using the standard `-gpios` suffix convention.  
   Specify the controller reference, the pin index, and the polarity flag.

   ```ini, DTS
   wifi_module: wifi@1 {
       compatible = "vendor,wifi-chip";
       /* Connects line 12 of gpio1 as an active-high enable pin */
       wifi-enable-gpios = <&gpio1 12 GPIO_ACTIVE_HIGH>;
   };
   ```

3. Compile and Update the DTB:  
   Recompile your device tree source into a .dtb file and flash/load it onto your target device.  
   You can verify the configuration applied successfully by checking if the node and property appear under `/proc/device-tree/` on the running system.
