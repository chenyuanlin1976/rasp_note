# GPIO from user space: sysfs (`/sys/class/gpio`) vs character device (`/dev/gpiochipN`)

Linux has 2 user-space interfaces to GPIO lines. Both are front ends to the same in-kernel **gpiolib**:

+ **`/sys/class/gpio/`**: the legacy sysfs interface, **deprecated since Linux 4.8** (2016).
  Its ABI is listed under `Documentation/ABI/obsolete/sysfs-gpio`.
+ **`/dev/gpiochipN`**: the **GPIO character device**, available since 4.8.
  Its uAPI v2 arrived in 5.10, and v1 is now deprecated too.
  It's used through **libgpiod** (C library + `gpiodetect`/`gpioinfo`/`gpioget`/`gpioset`/`gpiomon` tools).

The kernel owns `/dev/gpiochipN`. libgpiod is just a user-space wrapper around its ioctls.
The examples use an RK3566 pin, **GPIO4_D5** (bank 4, group D = 3, pin 5 → offset 3 × 8 + 5 = 29).

## 1. Legacy sysfs interface

```shell
# Global GPIO number = chip base + offset. With the classic Rockchip base (bank * 32): 4*32 + 29 = 157
cat /sys/class/gpio/gpiochip*/base /sys/class/gpio/gpiochip*/label   # find the real bases first

echo 157  | sudo tee /sys/class/gpio/export          # creates /sys/class/gpio/gpio157/
echo high | sudo tee /sys/class/gpio/gpio157/direction   # output, initially high ("out" = output low)
echo 0    | sudo tee /sys/class/gpio/gpio157/value
echo 157  | sudo tee /sys/class/gpio/unexport
```

How it works:

+ Writing to `export` makes gpiolib **request** the line, the same as a kernel consumer would.
  For a controller with `gpio-ranges`, that request goes through **pinctrl**, which switches the pin's mux to the GPIO function.
  So sysfs does *not* bypass pinctrl. But it can't apply pull-ups or drive strength;
  those must come from the device tree's pinctrl configuration.
+ If a kernel driver already owns the line (for example `leds-gpio`, or a driver using `*-gpios` through `gpiod_get()`), the export fails with **`EBUSY`**.

Problems, and the reasons it's deprecated:

+ **Global numbers**: you need the chip's base address, and that isn't stable.
  Newer kernels allocate bases dynamically (often starting at 512), so `bank * 32 + offset` breaks.
+ **No ownership**: an exported line stays exported after the process exits or crashes.
  Nothing tracks who uses it, and any process with write access can change it.
+ **One line per file write**: you can't change several lines atomically, and every operation is open/write/close of a text file.
+ **Polarity and settings from the device tree aren't applied**: there's only a manual `active_low` file. Bias, open-drain, and debounce can't be set.
+ **Events**: `poll()` on `value` with an `edge` file. Edges can be lost, and there are no timestamps.
+ Many current kernels, including Android GKI configs, ship with **`CONFIG_GPIO_SYSFS` disabled**, and then `/sys/class/gpio` doesn't exist.

## 2. Character device (`/dev/gpiochipN`) with libgpiod

```shell
gpiodetect                       # gpiochip4 [gpio4] (32 lines)  <- label shows the bank
gpioinfo gpiochip4               # line names, direction, and "used"/consumer per line

# libgpiod v1 tools
gpioset gpiochip4 29=1           # sets the line, then EXITS and releases it
gpioget gpiochip4 29

# libgpiod v2 tools (different syntax)
gpioset -c gpiochip4 29=1        # holds the line until killed (Ctrl-C); add -z/--daemonize to background it
gpioget -c gpiochip4 29
gpiomon -c gpiochip4 29          # wait for edge events (with timestamps)
```

After a line is released (v1 `gpioset` exiting, or a process dying), the kernel no longer guarantees its value.
For an output that must stay set, keep a process holding it: v2 `gpioset`, or your own daemon.

Advantages:

+ **Chip + offset addressing**, or **by name** with the device tree's `gpio-line-names` (`gpiofind`/`gpioinfo`),
  so it doesn't depend on global numbers.
  On Rockchip, `gpiochipN` usually matches bank `gpioN`. Check `gpiodetect`'s label rather than assuming the probe order.
+ **Ownership**: a request belongs to the file descriptor, shows a consumer name, and is released automatically when the process exits.
  Two processes can't request the same line.
+ **Atomic multi-line** get/set in one request.
+ **Line settings**: active-low, bias (pull-up/pull-down/disable), drive (push-pull/open-drain/open-source), and debounce (uAPI v2).
+ **Edge events**: queued in the kernel, with timestamps, so none are missed.
+ Uses binary ioctls instead of text parsing.
  Speed is rarely the deciding factor, though: correctness and ownership are.

## 3. Comparison

| | `/sys/class/gpio` (legacy) | `/dev/gpiochipN` (current) |
| --- | --- | --- |
| Kernel status | Deprecated (4.8), often not built | Standard; uAPI v2 since 5.10 |
| Addressing | Global number (`gpio157`) | Chip + offset (`gpiochip4 29`) or line name |
| Ownership / cleanup | None; stays exported after a crash | Per file descriptor; released on exit |
| Multiple lines | One at a time | Atomic |
| Bias / drive / debounce | No | Yes (v2) |
| Edge events | `poll()` on `value`, can miss edges | Queued, timestamped |
| Interface | Text files | ioctl through libgpiod (C, C++, Python bindings) |

## 4. Recommendation

Use **`/dev/gpiochipN` + libgpiod** for scripts, daemons, and HALs. That includes RK3566 Linux and Android builds.
Use `/sys/class/gpio` only on old kernels or for quick throwaway tests where it's still enabled.
On Android, the HAL design is in [../Android/HAL/HAL_libgpiod.md](../Android/HAL/HAL_libgpiod.md) and [../Android/HAL/AIDL_HAL_gpio.md](../Android/HAL/AIDL_HAL_gpio.md).

## Related notes

+ [libgpiod_intro.md](libgpiod_intro.md), [sysfs_intro.md](sysfs_intro.md), [HAL_mmio_vs_sysfs.md](HAL_mmio_vs_sysfs.md)
+ [../Android/HW/hw_control_sysfs.md](../Android/HW/hw_control_sysfs.md): sysfs GPIO on Android (permissions, SELinux)

## Reference

+ [GPIO character device uAPI (kernel docs)](https://docs.kernel.org/userspace-api/gpio/chardev.html)
+ [Sysfs GPIO interface, obsolete (kernel docs)](https://docs.kernel.org/userspace-api/gpio/sysfs.html)
+ [libgpiod](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)
