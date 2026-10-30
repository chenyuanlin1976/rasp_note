# led blinking

On Android 14, using the kernel sysfs trigger (`/sys/class/leds/.../trigger`) via your native HAL or system service  
is vastly superior and the industry-standard approach.

Using a Kotlin-level timer to continuously toggle LEDs is heavily discouraged for several critical architectural and power-efficiency reasons.

## Comparison of Approaches

### Approach 1: Kernel Sysfs Triggers (timer/ heartbeat)

+ Power Consumption: Minimal. The kernel handles the timing loop in hardware or low-power CPU states. The CPU can sleep.
+ Reliability & Jitter: Rock-solid. Hardware/kernel timing is immune to app load, thread starvation, or GC pauses.
+ Android 14 Restrictions: Unaffected. Runs at the `system/kernel` level.
+ Implementation Complexity: Requires native C/C++ or SELinux policies to write to sysfs nodes.

### Approach 2: Kotlin Code Timer (Handler, Coroutine, Timer)

+ Power Consumption: High. Wakes up the CPU repeatedly every few milliseconds, preventing deep sleep and draining the battery.
+ Reliability & Jitter: Unstable.  
  Subject to ART Garbage Collection (GC) pauses, UI thread congestion, and system load fluctuations (causing stuttery blinking).
+ Android 14 Restrictions: Severely Restricted.  
  Android 14's strict background execution limits, App Standby, and Doze mode will throttle, delay, or outright kill app-level timers.
+ Implementation Complexity: Easy to write quickly in Kotlin.

## Why Kernel Sysfs is the Correct Choice for Android 14

+ Power Management (Doze Mode & Standby):  
  Android 14 aggressively manages background tasks to preserve battery life.  
  If your Kotlin code runs a timer from an app or a non-exempted background service,  
  the OS will likely freeze or terminate it when the device enters Doze mode.  
  **Kernel triggers operate independently of Android's power management states.**
+ The "Duty Cycle" Offloading:  
  The Linux LED subsystem (`/sys/class/leds/`) has built-in triggers like timer that  
  let you configure `delay_on` and `delay_off` milliseconds directly.  
  Once set, the kernel handles the blinking autonomously without requiring continuous user-space intervention  
  or IPC (Inter-Process Communication) overhead through your AIDL interface.

## Recommended Implementation Architecture

Instead of having Kotlin control the interval of the blink,  
your AIDL interface should act as a command channel that configures the kernel trigger.

### 1. AIDL Interface Definition

Define high-level semantic methods rather than raw toggle commands:

```java
// ILedService.aidl
package com.example.led;

interface ILedService {
    // mode: 0 = OFF, 1 = ON, 2 = BLINK
    void setLedMode(int color, int mode, int delayOnMs, int delayOffMs);
}
```

### 2. Native HAL / Service Implementation (C++)

When your native service receives the request via **AIDL**, it interacts with the `sysfs` nodes:

**To blink**:

```bash
echo "timer" > /sys/class/leds/sys_led_r/trigger
echo "500"   > /sys/class/leds/sys_led_r/delay_on
echo "500"   > /sys/class/leds/sys_led_r/delay_off
```

**To turn off**:

```bash
echo "none"  > /sys/class/leds/sys_led_r/trigger
echo "0"     > /sys/class/leds/sys_led_r/brightness
```

### 3. Kotlin Usage

Your Kotlin code simply fires the AIDL command once to start or stop the blinking,  
completely freeing the app from maintaining timing loops:  

```kotlin
// Clean, simple, and battery-friendly call
ledService?.setLedMode(COLOR_RED, MODE_BLINK, 500, 500)
```

## Summary

Always push the blinking logic down to the Linux kernel sysfs trigger layer.  
Use your AIDL interface solely to pass configuration parameters (delay_on, delay_off, trigger type) down to your native service.
