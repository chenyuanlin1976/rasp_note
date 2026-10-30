
On Linux-based systems like Android (running on an RK3566),  
the difference between `/dev/gpiochip*` and `/sys/class/gpio/gpiochip*` represents an evolution in the Linux kernel architecture.

+ `/sys/class/gpio/gpiochip*` is the legacy sysfs interface (now deprecated),  
+ `/dev/gpiochip*` is the modern character device interface managed by `libgpiod`.

## 1. /sys/class/gpio/gpiochip* (The Legacy Sysfs Interface)

This is an older **text-based file** system interface  
that exposes individual GPIO pins as directories and files.

### How it looks/works

You interact with it by "exporting" a global GPIO pin number into a control file:

```bash
echo 157 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio157/direction
echo 1 > /sys/class/gpio/gpio157/value
```

### Key Characteristics

+ Deprecated: The Linux kernel community officially deprecated the `sysfs` GPIO interface  
  because it is slow, prone to race conditions, awkward to handle multi-pin operations,  
  and uses messy global integer math (e.g., calculating `bank * 32 + index`).
+ Text-heavy: Every read or write involves parsing text strings ("out", "in", "1", "0"),  
  which introduces unnecessary overhead.
+ Removal: Depending on how modern your Android kernel version is (Linux 5.10+ / 6.x),  
  the `CONFIG_GPIO_SYSFS` option might be completely turned off.

## 2. /dev/gpiochip* (The Modern Character Device API)

This is the modern, robust, and recommended kernel API for controlling GPIOs, accessed via the `libgpiod` toolset  
(`gpiodetect`, `gpioinfo`, `gpioset`, `gpioget`).

### How it looks/works

Instead of individual files for every pin,  
the system exposes entire GPIO banks/controllers as **character device files**  
(e.g., `/dev/gpiochip0`, `/dev/gpiochip1`, etc., matching the RK3566's hardware **banks**).

```bash
# Check available chips and lines
gpiodetect
gpioinfo

# Set a line directly using libgpiod tools (e.g., chip 4, line 29 to high)
gpioset gpiochip4 29=1
```

### Key Characteristics

+ Performance & Safety: Uses fast ioctl system calls instead of text I/O.  
  It handles multiple lines atomically and provides proper ownership tracking  
  (preventing 2 apps from accidentally fighting over the same pin).
+ Hardware-aligned: It maps directly to the SoC's architecture  
  (e.g., Rockchip's gpio0 through gpio4 map cleanly to gpiochip0 through gpiochip4).
+ Android/ Native Support: Modern Android native daemons and HALs prefer using `libgpiod`  
  (or direct C/C++ API wrappers around `/dev/gpiochip*`) rather than legacy file paths.

## Quick Comparison Summary

### Feature: /sys/class/gpio/ (Legacy)

+ Interface Type: Virtual File System (`Sysfs`)
+ Status: Deprecated by the Linux kernel
+ Naming Convention: Flat global numbers (gpio157)
+ Performance: Slow (string-based parsing)
+ Safety/ Locking: Poor (easy to cause race conditions)

### Feature: /dev/gpiochip* (Modern)

+ Interface Type: Character Device / ioctl (`libgpiod`)
+ Status: Standard / Current Best Practice
+ Naming Convention: Controller + Line offset (`gpiochip4 29`)
+ Performance: Fast (binary ioctl calls)
+ Safety/ Locking: Robust (kernel-enforced line tracking)

## Recommendation for RK3566 Android Development

If you are writing scripts, native services, or HAL modules for an RK3566 Android image, avoid `/sys/class/gpio`.  
Use the `libgpiod` libraries and utilities targeting `/dev/gpiochip*` to ensure compatibility with newer kernels and cleaner execution.
