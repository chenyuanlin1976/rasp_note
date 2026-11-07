# Raspberry Pi 5: GPIO control

On the Pi 5, the 40-pin header isn't driven by the Broadcom SoC (BCM2712) directly.
It's driven by **RP1**, Raspberry Pi's own I/O controller, which is connected over PCIe.
Libraries that `mmap` the old Broadcom GPIO registers therefore **don't work** on the Pi 5:
`RPi.GPIO` fails with `RuntimeError: Cannot determine SOC peripheral base address`, and `pigpio` isn't supported.
Use the kernel **GPIO character device** (libgpiod) or libraries built on it (`lgpio`, `gpiozero`).

## 1. Find the chip and line

```shell
gpiodetect          # look for the chip labeled "pinctrl-rp1"
gpioinfo | less     # lines are named GPIO0..GPIO27 for the header
```

+ The header chip is **`gpiochip4`** on early Bookworm kernels and **`gpiochip0`** on newer ones (kernel updates from 2024).
  Newer images keep a `gpiochip4` symlink for compatibility. Trust `gpiodetect`.
+ The line offset is the **BCM GPIO number**, for example GPIO17 = header pin 11.
+ Permissions: `/dev/gpiochip*` belongs to group `gpio`, and the default user is in it, so no `sudo` is needed.

## 2. Command line

Raspberry Pi OS Bookworm ships **libgpiod v1** tools:

```shell
gpioget gpiochip0 17
gpioset --mode=wait gpiochip0 17=1      # drive high and HOLD until Enter; plain "gpioset" releases on exit
```

`pinctrl` is Raspberry Pi's own tool. It reads and writes the RP1 registers directly, which is handy for inspection:

```shell
pinctrl get 17                # function, pull, level
pinctrl set 17 op dh          # output, drive high
pinctrl set 17 dl             # drive low
pinctrl set 17 ip pu          # input with pull-up
```

`pinctrl` bypasses the kernel's line ownership: it can change a pin that a driver is using. Use it for debugging, not in applications.

## 3. Python

**gpiozero** (preinstalled; on the Pi 5 it uses the `lgpio` backend):

```python
from gpiozero import LED, Button
from signal import pause

led = LED(17)               # BCM numbering
button = Button(27)         # pull-up enabled by default
button.when_pressed = led.toggle
pause()
```

**lgpio** (lower level; `sudo apt install python3-lgpio`):

```python
import time
import lgpio

h = lgpio.gpiochip_open(0)          # the RP1 chip number from gpiodetect (0 or 4)
lgpio.gpio_claim_output(h, 17, 0)   # claim GPIO17 as output, initially low
try:
    for _ in range(5):
        lgpio.gpio_write(h, 17, 1); time.sleep(0.5)
        lgpio.gpio_write(h, 17, 0); time.sleep(0.5)
finally:
    lgpio.gpiochip_close(h)         # releases the line
```

**libgpiod Python bindings**: see [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md). Bookworm's `python3-libgpiod` is v1. The `pip` package `gpiod` is v2.

## 4. PWM

+ `lgpio.tx_pwm()` / `gpiozero.PWMLED` give **software-timed** PWM, which has jitter. That's fine for LEDs but not for servos.
+ For **hardware PWM**, enable an overlay (for example `dtoverlay=pwm-2chan` in `/boot/firmware/config.txt`, for GPIO18/19)
  and use `/sys/class/pwm/pwmchip*/` or a library such as `rpi-hardware-pwm`.

## 5. Old `RPi.GPIO` scripts

Install the drop-in replacement, which implements the `RPi.GPIO` API on top of lgpio:

```shell
sudo apt remove python3-rpi.gpio
sudo apt install python3-rpi-lgpio       # or, inside a venv: pip install rpi-lgpio
```

Plain `pip install` into the system Python is blocked on Bookworm (externally managed environment), so use apt or a venv.
`WiringPi` users need the maintained fork (WiringPi 3.x), which supports the Pi 5.

## 6. Hardware notes

+ The header GPIOs are **3.3 V** logic and **not 5 V tolerant**.
+ Many pins have alternate functions (I2C, SPI, UART, PWM) that are enabled by `dtparam`/`dtoverlay` in `config.txt`.
  A pin that a driver uses shows its consumer in `gpioinfo`, and requesting it fails with `EBUSY`.

## Related notes

+ [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md), [../Linux/libgpiod_sysfs_cmp.md](../Linux/libgpiod_sysfs_cmp.md)
+ [OPi5_gpio_ctrl.md](OPi5_gpio_ctrl.md), [NV_jetson_gpio_ctrl.md](NV_jetson_gpio_ctrl.md)

## Reference

+ [Raspberry Pi documentation: GPIO and the 40-pin header](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#gpio)
+ [gpiozero documentation](https://gpiozero.readthedocs.io/)
+ [lgpio](https://abyz.me.uk/lg/py_lgpio.html)
