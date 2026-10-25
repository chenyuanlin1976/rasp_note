# sysfs introduction

## What is sysfs in Linux?

`sysfs` is a pseudo-file system provided by the Linux kernel.  
It serves as a **bridge** between the **kernel** (which talks to hardware and drivers)  
and **user space** (applications, scripts, and system administrators).

Unlike traditional files on your hard drive (like documents or photos), `sysfs` files do not take up storage space on a disk.  
Instead, they are generated dynamically in RAM by the Linux kernel.  
When you read or write to them, you are interacting directly with live kernel data structures,  
device drivers, and hardware parameters in real time.

By default, `sysfs` is mounted at `/sys`.

## How Sysfs Works: The Directory Tree

When you explore `/sys`, you are looking at an organized hierarchy of directories  
that mirrors **how the kernel views your hardware and device drivers**:

+ `/sys/devices/`: The master directory containing a hierarchical tree of every physical device and bus connected to the system.
+ `/sys/class/`: Groups devices by their functional category  
  (e.g., net for network interfaces, block for storage drives, leds for status lights, hwmon for hardware monitoring/temperature sensors).  
  This is usually the easiest place for humans to find things.
+ `/sys/bus/`: Organizes devices by the bus type they use (e.g., pci, usb, i2c).
+ `/sys/module/`: Contains parameters and states for currently loaded kernel modules.

## Working with Sysfs: A Hands-On Example

Because `sysfs` nodes are presented as **ordinary text files**,  
you can interact with them using standard command-line tools like `cat` and `echo`,  
or file I/O operations (`open`, `read`, `write`) in C, Python, or Java.

### Example: Checking CPU Temperature

If you want to read a temperature sensor on a Linux machine, you might find a `sysfs` node like this:  
`cat /sys/class/thermal/thermal_zone0/temp`  
Output: 45000 (meaning 45.000 C).

### Example: Controlling an LED or Backlight

If your embedded Linux device has an adjustable screen backlight,  
you can change its brightness by writing a text string to its `sysfs` node:

```bash
# Check the maximum possible brightness
cat /sys/class/backlight/intel_backlight/max_brightness
# Output: 937

# Set the brightness to 500
echo 500 > /sys/class/backlight/intel_backlight/brightness
```

## Why does Sysfs Exist? (The Philosophy)

Before `sysfs` (and its older cousin procfs),  
communicating with kernel drivers required complex, platform-specific system calls or custom command-line utilities.

`Sysfs` revolutionized Linux systems configuration by adhering to the Unix philosophy: "**Everything is a file.**"

1. **Human-Readable & Scriptable**:  
   Because values are exposed as plain text strings,  
   you can easily inspect and modify hardware states using basic shell scripts, bash, cron jobs, or Python  
   without needing specialized compilers or libraries.
2. **Unified Interface**:  
   It standardizes how userspace interacts with hardware.  
   Whether you are on a Raspberry Pi, an Intel server, or an Android phone,  
   interacting with things like GPIOs, batteries, and touchscreens follows the same file-reading paradigms.
3. **Dynamic Hot-Plugging**:  
   When you plug in a USB device, the kernel dynamically creates the corresponding files in `/sys/bus/usb/` or `/sys/class/`.  
   When you unplug it, the kernel removes them instantly.

## Summary: Sysfs vs. Regular Files

### Feature of Regular File (on ext4/NTFS)

+ StorageStored: persistently on an HDD/SSD.
+ Purpose: To store data, code, or user documents.
+ Reading: Fetches stored bytes from disk.
+ Writing: Modifies data saved on disk.

### Feature of Sysfs Node (in /sys)

+ StorageStored: Exists only in RAM, managed by the kernel.
+ Purpose: To expose kernel/hardware status and controls.
+ Reading: Triggers kernel code to query hardware in real time.
+ Writing: Triggers kernel drivers to execute a command or change a register.
