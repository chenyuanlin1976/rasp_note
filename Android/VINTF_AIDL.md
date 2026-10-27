# AIDL and VINTF

In modern Android system development (under Project Treble and Android 11+),  
**AIDL, HAL, and VINTF** are the 3 core pillars used to **decouple** the Android OS framework  
from **vendor-specific hardware implementations.**

When building a custom hardware control service like your `AuoCtrlSvc`,  
these 3 components work together in a strict architectural flow.

## 1. AIDL (Android Interface Definition Language) — The Contract

AIDL defines the programming interface that both the **client** (your App) and the **service** (the HAL) agree upon.

+ **Stable AIDL**: Modern Android uses **Stable AIDL** for **HALs** (replacing the older HIDL).  
  It allows versioning, parcelables, and ensures backward/forward compatibility between the system/vendor partitions.
+ Your Project Role: You define `IAuoCtrlSvc.aidl` containing methods like `setLedBrightness()` or `getMacAddress()`.  
  The build system **automatically** generates proxy/stub Java or C++ code.

## 2. HAL (Hardware Abstraction Layer) — The Implementation

The HAL is the actual low-level service (usually written in C++ or Rust) running in the vendor partition.

+ Role: It takes the requests passed down via **AIDL** from your app  
  and interacts **directly with the Linux kernel drivers**  
  (e.g., writing to `/sys/class/leds/` or reading network interfaces).
+ **Service Registration**: The compiled C++ daemon registers itself with the Android **servicemanager**  
  using a registered name (e.g., `com.auo.auoctrlsvc.IAuoCtrlSvc/default`).

## 3. VINTF (Vendor Interface) — The Manifest & Compatibility

VINTF stands for Vendor Interface Object.  
It is a mechanism Android uses to check compatibility between the **system image** and the **vendor image**.

+ Role: Android needs to know what HALs are provided by the **vendor partition**.  
  You declare your HAL service inside the device's VINTF manifest XML file  
  (`manifest.xml` or `device/auo/.../manifest.xml`).
+ Why it matters: If a HAL is missing from the VINTF manifest, the Android build system or init process will block it,  
  or servicemanager will refuse to recognize it.

## End-to-End Architecture Flow

[ App (Java/Kotlin) ] 
         │ (Binds via Intent / AIDL Proxy)
         v
  [ ServiceManager ]  <--- (Managed & Validated by VINTF Manifest)
         │
         v
 [ HAL Service (C++) ] 
         │ (Sysfs / Kernel IOCTL)
         v
  [ Hardware (LED / Wi-Fi / Power) ]

## What a VINTF Manifest Entry Looks Like for a HAL

In your device's `manifest.xml`, a Stable AIDL HAL is typically declared like this:

```xml
<manifest version="1.0" type="device">
    <!-- Declare your custom AUO Control HAL service -->
    <hal format="aidl">
        <name>com.auo.auoctrlsvc</name>
        <version>1</version>
        <interface>
            <name>IAuoCtrlSvc</name>
            <instance>default</instance>
        </interface>
    </hal>
</manifest>
```

## Summary Checklist for System Integrators

1. Define AIDL: Create the .aidl interface files in a shared shared-library repository.
2. Implement HAL: Write the C++ service that inherits from `BnAuoCtrlSvc`, reads/writes hardware nodes, and publishes itself to `servicemanager`.
3. Add VINTF Declaration: Add the <hal format="aidl"> block to your device's manifest.xml.
4. App Integration: Use `bindService()` in your app (as shown in your MainActivity)  
   to connect to this native HAL service seamlessly.
