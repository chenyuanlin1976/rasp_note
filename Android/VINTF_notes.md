# VINTF notes

If your ultimate goal is simply to control a GPIO pin on the main chip from Android 14,  
dealing with full-blown VINTF, framework-level Stable AIDL, and native HAL architecture can feel like massive overkill.

Depending on your access level and design requirements,  
you can bypass the complex Android framework HAL infrastructure using alternative approaches.  
However, you need to understand the trade-offs:

## Alternative 1: Vendor-to-Vendor Direct Binder (Skip VINTF, keep AIDL)

If your application or daemon controlling the GPIO lives **completely inside the vendor partition**  
(e.g., a vendor-specific background service talking directly to a vendor driver), you do not need VINTF.

+ How it works: You can write a custom AIDL interface, compile it strictly for vendor usage (without @VintfStability),  
  and register it via `AServiceManager_addService()` locally inside the vendor domain.
+ Why it works: Android **ONLY** enforces VINTF checks **when an interface crosses partition boundaries (specifically system <-> vendor)**. 
  Intra-vendor communication is ignored by VINTF.
+ The Catch: Regular Android apps (system apps or third-party apps) cannot access this service directly  
  because **Service Manager will block cross-partition** calls to un-declared services.

## Alternative 2: Direct Kernel Access via a Vendor Daemon or Script (No Binder/AIDL at all)

If you just want a quick, pragmatic way to toggle a GPIO from a native binary, script, or a custom vendor daemon:

+ How it works:
  1. Export or manipulate the GPIO directly through standard Linux interfaces in userspace  
     (e.g., using `/sys/class/gpio/...` or character devices `/dev/gpiochip*`).
  2. Alternatively, write a small native C/C++ binary in the vendor partition that opens the device node and toggles the pins.
+ How to trigger it: You can trigger this binary using a custom `init.rc` service  
  or a property trigger (`setprop vendor.gpio.control 1`).
+ The Catch: This completely bypasses Android's IPC mechanisms (Binder/AIDL).  
  If an app needs to control the GPIO interactively,  
  the app would have to write to a socket, use a local Unix domain socket,  
  or modify a property that your vendor daemon watches.

## Alternative 3: Direct libgpiod in a Vendor Native Process

In modern Linux kernels (and Android 14),  
the old `/sys/class/gpio` sysfs interface is deprecated in favor of the GPIO character device (`libgpiod`).

+ You can include `libgpiod` in your vendor build (`Android.bp`).
+ Write a simple vendor C++ utility that uses `gpiod_chip` and `gpiod_line` APIs to set/get the pin state cleanly.

## Summary: Which path should you take?

### Use Case: An standard Android app needs to flip a GPIO pin.

+ Recommended Approach: Must use a **Stable AIDL HAL** properly registered with `VINTF`.
+ Do you need VINTF: Yes

### Use Case: A vendor background daemon/ native service needs to control a GPIO

+ Recommended Approach: Use local vendor AIDL or a C++ daemon using `libgpiod`.
+ Do you need VINTF: No

### Use Case: You just want to test/debug a GPIO manually on the board

+ Recommended Approach: Use shell commands/ `gpiod` tools directly via adb shell.
+ Do you need VINTF: No

## Conclusion

If you are trying to expose this GPIO to a standard Android application package (APK),  
you must go through the formal **VINTF/AIDL HAL route**.  

If it's just for internal board bring-up or a vendor background service,  
stick to a simple vendor daemon using `libgpiod` to save yourself considerable configuration overhead.
