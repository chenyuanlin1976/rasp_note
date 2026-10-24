# Led on/off

To implement this cleanly on Android 14, you need to wire up the architecture from the `hardware/sysfs` layer  
all the way up to your Kotlin application via **AIDL**.

Here is a complete end-to-end demonstration of how to turn an LED on and off  
(and optionally blink it) using the recommended `sysfs` approach.

## Step 1: Define the AIDL Interface

Create an AIDL file so your app can communicate with your system service or native HAL daemon.

```java
// package com.example.led;
package com.example.led;

interface ILedControl {
    // controlState: 0 = OFF, 1 = ON, 2 = BLINK
    // delayOn/delayOff are used only if state is BLINK (in milliseconds)
    void setLedState(int controlState, int delayOn, int delayOff);
}
```

## Step 2: Implement the Native C++ Daemon/ Service

Because regular apps do **not** have permission to modify `/sys/class/leds/` directly  
**due to Android's strict SELinux policies and sandboxing,**  
this must be handled by a **privileged system service** or **native daemon** running with appropriate permissions  
(e.g., system or root context, with a custom SELinux policy rule).

Here is how your C++ service writes to the `sysfs` node:

```c++
#include <string>
#include <fstream>
#include <iostream>

#define LED_PATH "/sys/class/leds/sys_led_r"

bool writeToFile(const std::string& path, const std::string& value) {
    std::ofstream file(path);
    if (!file.is_open()) {
        return false;
    }
    file << value;
    return file.good();
}

void setLedState(int controlState, int delayOn, int delayOff) {
    if (controlState == 0) {
        // TURN OFF: Disable trigger, then set brightness to 0
        writeToFile(std::string(LED_PATH) + "/trigger", "none");
        writeToFile(std::string(LED_PATH) + "/brightness", "0");
    } 
    else if (controlState == 1) {
        // TURN ON: Disable trigger, then set brightness to max (e.g., 255)
        writeToFile(std::string(LED_PATH) + "/trigger", "none");
        writeToFile(std::string(LED_PATH) + "/brightness", "255");
    } 
    else if (controlState == 2) {
        // BLINK: Use kernel's timer trigger
        writeToFile(std::string(LED_PATH) + "/trigger", "timer");
        writeToFile(std::string(LED_PATH) + "/delay_on", std::to_string(delayOn));
        writeToFile(std::string(LED_PATH) + "/delay_off", std::to_string(delayOff));
    }
}
```

## Step 3: Implement the Service Stub in Java/Kotlin

Your system service implements the **AIDL stub** and calls your native layer (via **JNI**)  
or *directly executes the file operations if running with system privileges*.

```kotlin
package com.example.led

import com.example.led.ILedControl.Stub
import java.io.File

class LedControlService : Stub() {

    override fun setLedState(controlState: Int, delayOn: Int, delayOff: Int) {
        // Enforce permission checks here (e.g., context.enforceCallingOrSelfPermission)
        
        val triggerPath = File("/sys/class/leds/sys_led_r/trigger")
        val brightnessPath = File("/sys/class/leds/sys_led_r/brightness")
        val delayOnPath = File("/sys/class/leds/sys_led_r/delay_on")
        val delayOffPath = File("/sys/class/leds/sys_led_r/delay_off")

        try {
            when (controlState) {
                0 -> { // OFF
                    triggerPath.writeText("none")
                    brightnessPath.writeText("0")
                }
                1 -> { // ON
                    triggerPath.writeText("none")
                    brightnessPath.writeText("255")
                }
                2 -> { // BLINK
                    triggerPath.writeText("timer")
                    delayOnPath.writeText(delayOn.toString())
                    delayOffPath.writeText(delayOff.toString())
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            // Handle file write errors (SELinux blocks, missing nodes, etc.)
        }
    }
}
```

## Step 4: Call it from your Kotlin App

Once your service is registered with `ServiceManager`,  
your application client can bind to it and control the LED with single function calls,  
no timers or background loops required in your app code:

```kotlin
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import androidx.appcompat.app.AppCompatActivity
import com.example.led.ILedControl

class MainActivity : AppCompatActivity() {

    private var ledService: ILedControl? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            ledService = ILedControl.Stub.asInterface(service)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            ledService = null
        }
    }

    override fun onStart() {
        super.onStart()
        // Bind to your system-level or app-exposed service providing the AIDL interface
        // Note: Real system services usually require specific binding flags or Context.bindService() mechanisms
    }

    // --- Action Examples ---

    fun turnLedOn() {
        // state 1 = ON, parameters delayOn/delayOff are ignored for ON/OFF
        ledService?.setLedState(1, 0, 0)
    }

    fun turnLedOff() {
        // state 0 = OFF
        ledService?.setLedState(0, 0, 0)
    }

    fun startLedBlinking() {
        // state 2 = BLINK, 500ms ON, 500ms OFF handled entirely by the kernel
        ledService?.setLedState(2, 500, 500)
    }
}
```

## Important Android 14 Note (SELinux)

Because Android 14 implements rigorous sandboxing,  
if your service runs as a regular app or a non-privileged process,  
writing to `/sys/class/leds/` will throw a Permission Denied exception.  
You must ensure:

+ Your service runs within a context (`system_server` or a dedicated native daemon like vendor_init or a custom init service).
+ Appropriate SELinux policy rules (`.te` files) are added to grant your daemon write permissions to the `sysfs` LED labels  
  (`leds_sysfs` or generic sysfs file contexts).

## Can Java/Kotlin write to files,  

Technically, Yes. Java/Kotlin can write to files,  
but practically no for standard Android apps due to Android's security architecture.

Even though you can easily write file operations in Kotlin using `File("/sys/class/leds/.../brightness").writeText("255")`,  
the operating system will block it unless specific conditions are met.

### Why Standard Android Apps Cannot Do It

1. File Permissions: The Linux kernel nodes under `/sys/class/leds/` are owned by root or the system user  
   with restrictive file permissions (e.g., read/write only for the owner).  
   **Regular apps run under an unprivileged user ID (u0_a...) and lack permission to modify them.**
2. SELinux Restrictions: Android's mandatory access control (SELinux) has strict rules (.te policies)  
   that completely block 3rd-party app domains from touching sysfs hardware paths.  
   Any attempt will immediately throw a **Permission Denied** or **FileNotFoundException**.

### When Can Java/Kotlin Write to Sysfs?

Java/Kotlin can only successfully write to these paths  
**if your code runs in a privileged context where security checks are bypassed or granted**:

+ Inside a Privileged System Service:  
  **If you are building a custom AOSP image and writing a core system service in Java**  
  (like a service running inside system_server), it has higher privileges.  
  However, AOSP architecture guidelines strongly recommend pushing `sysfs` interactions down to a **C/C++ HAL**  
  (Hardware Abstraction Layer) or native daemon rather than doing file I/O in Java system services.
+ On a Rooted Device: If the device has root access and your app requests root permissions (su),  
  a Kotlin app could execute shell commands to echo values into sysfs.  
  (This is fine for personal projects or debugging, but unacceptable for production devices).

### Summary

+ Can you write the code in Kotlin? -> Yes (`File(...).writeText()`).
+ Will it work out-of-the-box in an Android app? -> No, Android 14 will block it due to sandbox security and SELinux.
+ The Correct Pattern: Keep your UI and app logic in Kotlin,  
  but delegate the actual hardware interaction to a privileged native service or HAL daemon (using AIDL to bridge the gap safely).
