# HW control via sysfs

Controlling GPIO pins via sysfs (`/sys/class/gpio/`) on Android 14 faces major hurdles  
because modern Android versions and newer Linux kernels have largely **deprecated** sysfs GPIO  
in favor of the character device interface (`/dev/gpiochipN`).  
Furthermore, Android's strict SELinux policies and permissions **block** standard apps from touching these paths.

If you are working with an embedded board running Android 14 where sysfs GPIO is still exposed or enabled in the kernel,  
here is how permissions and access work:

## 1. Why Platform Keys and SELinux Still Matter for Sysfs

Even though sysfs files look like ordinary files (e.g., `/sys/class/gpio/export`),  
standard applications (untrusted_app) **cannot** access them because:

+ **SELinux File Contexts**: Sysfs nodes are labeled with specific security contexts (like sysfs_gpio or sysfs).  
  Regular app domains do not have read/write permissions to these contexts in their `policy rules` (**.te** files).
+ **Ownership and Groups**: By default, sysfs nodes are owned by `root:root` or specific system groups.  
  An app running under a standard UID cannot write to them.
+ To make sysfs work, you typically have to modify your device's AOSP source tree to grant access.

## 2. How to Grant Access for Sysfs Control

### a. Update init.rc or Udev rules

+ Configure your `init.rc` script or device-specific init files during boot  
  to change the ownership or permissions of the specific GPIO sysfs nodes so your service daemon can access them.  
  For example, assign them to a custom system group or make them readable/writable by a specific daemon UID.
+ Verification: Run `ls -l /sys/class/gpio/gpioX/value` via an `adb shell` (on a userdebug build)  
  to confirm the correct user/group ownership and permissions are applied.

### b. Add Custom SELinux Policies

+ Modify your device's SELinux policy files (e.g., `device/vendor/board/sepolicy/hal_gpio.te` or file_contexts)  
  to allow your native service domain to read and write to sysfs_gpio paths.  
  Without this, Android 14's kernel denial logs (**avc: denied**) will block access instantly.
+ Verification: Check `adb logcat | grep avc` while attempting to write to the pin to ensure no permission denials are logged.

### c.Implement Control via Native Daemon

+ Have a privileged native daemon (running as system or a custom system UID signed with the platform key) write the pin values to sysfs  
  (e.g., writing "1" to `/sys/class/gpio/gpio12/value`),  
  and expose this daemon to the rest of the system via a **ServiceManager AIDL interface**.
+ Verification: Call your custom ServiceManager method and check the physical pin state using a multimeter or oscilloscope.

## Kernel Deprecation Notice

In modern Linux kernels used by Android 14, the legacy sysfs GPIO interface (`/sys/class/gpio`) is deprecated  
and often disabled in default kernel configurations in favor of **libgpiod** and character devices (`/dev/gpiochip*`).  
If your kernel lacks sysfs support, attempts to access `/sys/class/gpio` will return **"No such file or directory"**.
