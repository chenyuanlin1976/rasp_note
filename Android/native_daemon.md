# native daemon

**A native daemon is a background process written in a native language (like C or C++)**  
that runs continuously in the operating system to perform specific tasks, handle system services, or manage hardware.

In the context of Android and Linux,  
a daemon runs independently of any user interface or user-facing app, usually starting up automatically when the device boots.

## Key Characteristics of a Native Daemon

1. Background Lifespan: Unlike an Android app activity that opens, closes, or gets killed when the user swipes it away,  
   a daemon runs perpetually in the background (unless the system explicitly restarts or stops it).
2. **Written in C/C++ (Native)**: Because it doesn't run inside the Java Virtual Machine (ART),  
   it has direct access to low-level system APIs, standard Linux libraries, and system resources.
3. Privileged Permissions: Daemons often run under specific system user IDs  
   (like `root`, `system`, or `radio`) with elevated privileges,  
   allowing them to perform actions that normal apps cannot - such as talking directly to the Linux kernel or modifying hardware sysfs nodes.

## How Daemons Fit Into Android Architecture

Android relies heavily on both Java-based system services (running inside `system_server`)  
and native C++ daemons running in user space:

+ Hardware Management (HIDL/ AIDL Daemons):  
  Vendor daemons or hardware abstraction layer (HAL) processes **run as native daemons to listen for commands from apps**  
  and **talk directly to drivers** (e.g., audio daemons, camera daemons, sensor daemons, or our LED control service).
+ Core OS Services: Daemons like `surfaceflinger` (manages screen composition), **`binder` (handles IPC routing)**,  
  and `init` (the parent of all processes) are foundational native daemons in AOSP.

## How It Connects to Our LED Example

If you implement the LED control logic using the Pure C++ AIDL approach we discussed earlier:

1. Your compiled C++ program (`main.cpp` + `LedControlService`) is packaged into the system image as a native daemon.
2. When the device boots, the `init` process starts your daemon (`init.rc` script).
3. Your daemon **registers** itself with the Android `ServiceManager`  
   and sits in a loop (`ABinderProcess_joinThreadPool()`), waiting for commands.
4. When an app sends a request via **AIDL**, your native daemon receives it and safely writes to `/sys/class/leds/`...  
   using its elevated system privileges.

## JNI and native daemon

Strictly speaking, JNI does **not** connect to a native daemon.

There is a fundamental architectural boundary between them:

+ JNI is strictly in-process (it bridges Java/Kotlin and C++ living inside the exact same memory space/process).
+ A Native Daemon runs in its own separate, independent process in the background.

Because they live in different processes,  
a Java/Kotlin app cannot use JNI to talk to a native daemon.  
**Instead, they communicate using Binder IPC (via AIDL).**

### How Communication Actually Works: AIDL vs. JNI

If you have a Kotlin app and a separate C++ native daemon controlling your LEDs, the connection looks like this:

[ Kotlin App Process ]
       │
       │  (1. Binder IPC/ AIDL - Crosses Process Boundary)
       v
[ C++ Native Daemon Process ]
       │
       │  (2. Direct C++ execution - NO JNI needed)
       v
[ Linux Kernel /sys/class/leds/ ]

1. The App sends a request to the native daemon using **AIDL** (Android Interface Definition Language).  
   Android’s Binder driver handles passing the data safely across the process boundary.
2. The native daemon receives the request directly in C++.  
   Since the daemon is already 100% C/C++, it executes its logic and writes to the sysfs node without using JNI at all.

### When Does JNI Involve Native Code and System Services?

You might be thinking of Android's legacy or framework architecture where Java system services talk to native code.  
That happens in a different scenario:

If a Java process (like `system_server`) wants to use a C++ library **within its own process**, it uses JNI:

1. system_server (Java) calls a method declared external.
2. JNI translates that call and runs a C++ function inside a shared library (.so) loaded directly into the same JVM process memory.
3. That C++ code interacts with hardware.

However, that shared library is part of the same app/service process - it is not a separate native daemon.

### Summary Rule of Thumb

+ Use JNI when your Java/Kotlin code needs to call C/C++ code **inside the same app/process**.
+ Use AIDL/ Binder when your app needs to talk to a **separate native daemon** or **system service running in another process**.
