# common domain in Android 14

In Android 14 (and modern Android versions built on SELinux and Project Treble),  
security policies are split between **system** (core Android OS components provided by Google)  
and **vendor** (OEM/hardware-specific drivers and services).

Processes and apps run inside designated security domains (types ending in _t or defined as a domain macro).  
Here are the most common and critical SELinux domains you will encounter in Android 14:

## 1. App Domains (Third-Party & System Apps)

Android heavily isolates apps from one another using sandboxed domains based on their **UID** and **signature permissions**:

+ `untrusted_app`: The default domain for standard, third-party apps installed by the user.  
  Android 14 further splits this (e.g., untrusted_app_30, untrusted_app_32) based on the app's target SDK version  
  to enforce stricter API level constraints.
+ `isolated_app`: Highly restricted domains used for isolated processes  
  (such as rendering web views or processing untrusted data inside a sandbox where network access and storage are completely stripped away).
+ `platform_app`: Apps signed with the core Android platform certificate  
  (e.g., system-bundled apps like Settings or default system utilities).
+ `system_app`: Apps running with the system UID (such as specific system management tools or settings extensions).
+ `priv_app`: Privileged apps residing in system partition paths like `/system/priv-app/`  
  (e.g., Launcher, SystemUI components) that require elevated permissions.

## 2. Core System Daemon & Service Domains

These are foundational OS processes managed by init or zygote that power Android's internal architecture:

+ `init`: The very first process (PID 1) that boots the system and launches subsequent services.
+ `zygote`: The parent process of all Android Java applications; it spawns app processes dynamically.
+ `system_server`: The core Java-based system service hub controlling window management, activity management, power management, and most system APIs.
+ `servicemanager`: The binder service registry daemon that allows different system and app processes  
  to find and talk to each other via Android Interface Definition Language **(AIDL)/ Binder**.
+ `surfaceflinger`: The system compositor responsible for drawing window layers, handling screen buffers,  
  and outputting graphics to the display hardware.
+ `netd`: The networking daemon responsible for managing firewall rules, iptables, network interfaces, and connectivity.
+ `vold`: The volume daemon handling storage mounting, encryption (File-Based Encryption / FBE in Android 14), and external SD cards.

## 3. Hardware Abstraction Layer (HAL) Domains

Under Android’s Treble architecture,  
hardware drivers run in isolated vendor domains rather than inside the main system server:

+ `hal_audio_default`/ `hal_audio`: Manages audio hardware playback and recording.
+ `hal_camera_default`/ `hal_camera`: Controls camera sensors, flash, and image capture pipelines.
+ `hal_graphics_allocator`/ `hal_graphics_composer`: Manages low-level GPU frame allocations and hardware composition.
+ `hal_fingerprint`/ `hal_biometrics`: Handles biometric authentication hardware (fingerprint, face unlock).
+ `hal_power`: Manages CPU frequencies, power states, and hints.

## 4. Root / Admin / Debugging Domains

+ kernel: The base kernel thread domain.
+ `su`: The domain for superuser/root access. In standard production builds (User builds) of Android 14,  
  `su` is completely stripped or heavily blocked by neverallow rules, but it exists in Debug/Engineering builds (userdebug/eng).
+ shell: The domain assigned to the adb shell environment when developers interact with the device via command line.
