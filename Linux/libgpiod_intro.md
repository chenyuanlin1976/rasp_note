# libgpiod introduction

**libgpiod** is the user-space C library and command-line toolkit for the Linux **GPIO character device** (`/dev/gpiochipN`).
The kernel provides the character device, and libgpiod wraps its `ioctl` interface.
It replaced the deprecated sysfs interface (`/sys/class/gpio`); see [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md) for that comparison.
Use it to read inputs (buttons, sensors), drive outputs (LEDs, relays, enable pins), and wait for edge events.

## 1. The GPIO character device

Linux exposes most hardware as device files, in 2 main kinds:

| | Block device | Character device |
| --- | --- | --- |
| Data unit | Fixed-size blocks, through the page cache | Byte stream, no block cache |
| Access | Random (seekable) | Usually sequential, or control through `ioctl` |
| Examples | `/dev/sda`, `/dev/mmcblk0` | `/dev/ttyS0`, `/dev/input/event0`, `/dev/gpiochip0` |
| `ls -l` type | `b` | `c` |

Each GPIO controller (one bank of the SoC, or an I/O expander) registers one character device, `/dev/gpiochipN`.
User space doesn't read or write pin values as text. It works on the file descriptor:

```text
open("/dev/gpiochip0")                          -> chip fd
ioctl(chip fd, GPIO_GET_CHIPINFO_IOCTL)         -> name, label, number of lines
ioctl(chip fd, GPIO_V2_GET_LINE_IOCTL, offsets) -> request fd (owns the lines)
ioctl(request fd, GPIO_V2_LINE_SET_VALUES_IOCTL / GET_VALUES_IOCTL)
poll() + read(request fd)                       -> edge events with timestamps
close(request fd)                               -> lines released
```

These are the uAPI v2 ioctl names; v1 has `GPIO_GET_LINEHANDLE_IOCTL` and `GPIO_GET_LINEEVENT_IOCTL` instead.
libgpiod hides these calls behind its C API and tools.

## 2. Versions

There are 2 incompatible generations. Check which one you have first: `gpiodetect --version`, or `pkg-config --modversion libgpiod`.

| | libgpiod **v1.x** (1.6.x is the last) | libgpiod **v2.x** |
| --- | --- | --- |
| Kernel uAPI | GPIO chardev v1 (`CONFIG_GPIO_CDEV_V1`, deprecated) | chardev **v2** (Linux **5.10+**) |
| Core C objects | `gpiod_chip`, `gpiod_line` | `gpiod_chip`, `gpiod_line_settings`, `gpiod_line_config`, `gpiod_request_config`, `gpiod_line_request` |
| Python module | `gpiod` 1.x (`python3-libgpiod` on Debian 12 / Raspberry Pi OS Bookworm) | `gpiod` 2.x (`pip install gpiod`, newer distros) |
| Typical in | Debian 12, Ubuntu 22.04, older Yocto/Buildroot | Debian 13, Ubuntu 24.04+, Fedora, current Yocto/Buildroot |

The other notes in this repo use the **v1** C API (for example [../Android/AIDL_impl_gpio_cxx.md](../Android/AIDL_impl_gpio_cxx.md)).

## 3. What's in the package

+ **Library**: `libgpiod` (C), with C++ (`libgpiodcxx`) and Python bindings. v2 adds GLib bindings and a D-Bus daemon (`gpio-manager`, 2.2+).
  Rust bindings live in a separate crate (`libgpiod`/`gpiod` on crates.io).
+ **Tools**:

| Tool | Purpose |
| --- | --- |
| `gpiodetect` | List chips: name, label (e.g. `gpio4`, `pinctrl-rp1`), number of lines |
| `gpioinfo` | Per line: offset, name (from `gpio-line-names`), direction, active-low, and **consumer** if it's in use. It does **not** show values |
| `gpioget` | Read line values (the line is requested as input unless `--as-is`/v2 options say otherwise) |
| `gpioset` | Drive lines as outputs |
| `gpiomon` | Wait for edge events (rising/falling), with timestamps |
| `gpiofind` | **v1 only**: find a line by name (`gpiofind WIFI_PWR_EN` → `gpiochip1 12`). v2 tools take names directly |
| `gpionotify` | **v2 only**: watch line-info changes (requested/released/reconfigured by others) |

## 4. Tool syntax: v1 vs v2

```shell
gpiodetect                                   # same in both

# --- v1 ---
gpioinfo gpiochip4
gpioget  gpiochip4 29
gpioset  gpiochip4 29=1                      # sets, then EXITS and releases the line
gpioset  --mode=signal gpiochip4 29=1        # holds the line until Ctrl-C / SIGTERM
gpiomon  --rising-edge gpiochip4 5

# --- v2 ---
gpioinfo -c gpiochip4                        # or: gpioinfo WIFI_PWR_EN
gpioget  -c gpiochip4 29                     # or: gpioget WIFI_PWR_EN
gpioset  -c gpiochip4 29=1                   # HOLDS the line until killed; -z to daemonize
gpioset  -t 500ms -c gpiochip4 29=1          # toggle every 500 ms (blink)
gpiomon  -e rising -c gpiochip4 5
```

A released line's value is no longer guaranteed: the kernel or driver may keep it or reset it.
Anything that must **stay** driven needs a process that keeps holding the line, such as v2 `gpioset`, `gpioset --mode=signal` (v1), or your daemon.

## 5. C API

### 5.1 v1

```c
#include <gpiod.h>

int blink_v1(void)
{
    struct gpiod_chip *chip = gpiod_chip_open_by_name("gpiochip4");   /* or gpiod_chip_open("/dev/gpiochip4") */
    if (!chip) return -1;

    struct gpiod_line *line = gpiod_chip_get_line(chip, 29);
    if (!line || gpiod_line_request_output(line, "blink", 0) < 0) {  /* EBUSY: a driver/another process owns it */
        gpiod_chip_close(chip);
        return -1;
    }

    gpiod_line_set_value(line, 1);
    gpiod_line_set_value(line, 0);

    gpiod_line_release(line);
    gpiod_chip_close(chip);
    return 0;
}
```

### 5.2 v2

```c
#include <gpiod.h>

int blink_v2(void)
{
    unsigned int offset = 29;
    int ret = -1;

    struct gpiod_chip *chip = gpiod_chip_open("/dev/gpiochip4");      /* v2 opens by path only */
    struct gpiod_line_settings *ls = gpiod_line_settings_new();
    struct gpiod_line_config *lc = gpiod_line_config_new();
    struct gpiod_request_config *rc = gpiod_request_config_new();
    struct gpiod_line_request *req = NULL;
    if (!chip || !ls || !lc || !rc) goto out;

    gpiod_line_settings_set_direction(ls, GPIOD_LINE_DIRECTION_OUTPUT);
    gpiod_line_settings_set_output_value(ls, GPIOD_LINE_VALUE_INACTIVE);
    gpiod_line_config_add_line_settings(lc, &offset, 1, ls);
    gpiod_request_config_set_consumer(rc, "blink");

    req = gpiod_chip_request_lines(chip, rc, lc);
    if (!req) goto out;

    gpiod_line_request_set_value(req, offset, GPIOD_LINE_VALUE_ACTIVE);
    gpiod_line_request_set_value(req, offset, GPIOD_LINE_VALUE_INACTIVE);
    ret = 0;

out:
    if (req) gpiod_line_request_release(req);
    gpiod_request_config_free(rc);
    gpiod_line_config_free(lc);
    gpiod_line_settings_free(ls);
    if (chip) gpiod_chip_close(chip);
    return ret;
}
```

Build with `gcc blink.c -lgpiod`, or `pkg-config --cflags --libs libgpiod`.

## 6. Python

v2 (`pip install gpiod`, libgpiod ≥ 2.0):

```python
import time
import gpiod
from gpiod.line import Direction, Value

with gpiod.request_lines(
    "/dev/gpiochip0",
    consumer="blink",
    config={17: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.INACTIVE)},
) as req:
    for _ in range(5):
        req.set_value(17, Value.ACTIVE)
        time.sleep(0.5)
        req.set_value(17, Value.INACTIVE)
        time.sleep(0.5)
# the line is released when the "with" block exits
```

v1 (`python3-libgpiod` 1.x, e.g. Debian 12 / Raspberry Pi OS Bookworm):

```python
import gpiod

chip = gpiod.Chip("gpiochip0")
line = chip.get_line(17)
line.request(consumer="blink", type=gpiod.LINE_REQ_DIR_OUT, default_val=0)
line.set_value(1)
line.set_value(0)
line.release()
```

Raspberry Pi 5: the 40-pin header is on the RP1 chip, labeled `pinctrl-rp1`.
Depending on the kernel version it is `gpiochip4` (early Bookworm kernels) or `gpiochip0` (newer kernels). Check with `gpiodetect`.
The offset is the **BCM GPIO number** (17 = header pin 11), not the physical pin number.

## 7. Features worth knowing

+ **Ownership**: a request belongs to the file descriptor and shows the consumer name in `gpioinfo`.
  It is **released automatically** when the process exits. A second request for the same line fails with `EBUSY`.
+ **Multiple lines in one request**: values are set together.
  The update is truly simultaneous only on the same chip, and only if its driver implements `set_multiple`.
  This is a convenience, not a timing guarantee.
+ **Line settings** (v2 / uAPI v2): active-low, bias (pull-up / pull-down / disabled), drive (push-pull / open-drain / open-source), and debounce.
+ **Edge events**: the kernel queues them with timestamps, and the request's file descriptor can be used with `poll`/`epoll`.
  Latency is still that of Linux user space: µs to ms, not real time.
+ **Names**: if the device tree has `gpio-line-names`, tools and code can use names (`WIFI_PWR_EN`) instead of numbers.

## 8. Requirements and permissions

+ Kernel: `CONFIG_GPIO_CDEV=y`, plus `CONFIG_GPIO_CDEV_V1=y` if you use libgpiod v1.
+ The pin must be muxed as GPIO (pinctrl in the device tree) and **not claimed** by a kernel driver (`leds-gpio`, `*-gpios` consumers).
  Otherwise the request fails with `EBUSY`; `gpioinfo` shows the owner.
+ `/dev/gpiochipN` is `root:root 0600` by default.
  Distributions or udev rules may grant a group (Raspberry Pi OS: `gpio`).
  To give your own service access: `SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"`.
+ No kernel module of your own is needed. It's pure user space on top of the chardev.

## Related notes

+ [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md): chardev vs legacy sysfs GPIO
+ [HAL_mmio_vs_sysfs.md](HAL_mmio_vs_sysfs.md), [HAL_intro.md](HAL_intro.md): a C++ HAL on top of libgpiod
+ [../Android/libgpiod_android.md](../Android/libgpiod_android.md): libgpiod on Android (build, test, HAL)

## Reference

+ [libgpiod (git, README, docs)](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)
+ [libgpiod API documentation](https://libgpiod.readthedocs.io/)
+ [GPIO character device uAPI (kernel docs)](https://docs.kernel.org/userspace-api/gpio/chardev.html)
