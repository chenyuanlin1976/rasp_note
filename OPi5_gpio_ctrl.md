# Orange Pi 5: GPIO control

The Orange Pi 5 uses a Rockchip **RK3588S** (the Orange Pi 5 Plus/Max use the RK3588).
The recommended way to control its header GPIOs is the kernel **GPIO character device** through **libgpiod**.
Orange Pi's own images also ship **wiringOP** (`gpio` command), which has RK3588 support.

## 1. Find the chip and line

```shell
gpiodetect            # gpiochip0..gpiochip4 = Rockchip banks GPIO0..GPIO4 (check the labels)
gpioinfo gpiochip1    # direction and consumer per line; "used" lines belong to a driver
gpio readall          # (Orange Pi images, wiringOP) table: physical pin <-> wPi number <-> GPIO name <-> mode
```

Rockchip pin math: `GPIO<bank>_<group><n>` → `gpiochip<bank>`, offset = group × 8 + n (A=0, B=1, C=2, D=3).
For example `GPIO1_C6` → `gpiochip1` line 22.
Take the pin names from the board's header pinout (or `gpio readall`). Don't guess them.

## 2. Command line (libgpiod)

```shell
sudo apt update
sudo apt install gpiod python3-libgpiod libgpiod-dev   # Ubuntu 22.04 / Debian 12 images: libgpiod v1

gpioget gpiochip1 22
sudo gpioset --mode=wait gpiochip1 22=1                # hold high until Enter (plain gpioset releases on exit)
```

`sudo` is needed unless a udev rule gives your group access to `/dev/gpiochip*`, for example
`SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"`.

## 3. Python

**libgpiod v1 bindings** (`python3-libgpiod`):

```python
import time
import gpiod

chip = gpiod.Chip("gpiochip1")
line = chip.get_line(22)                     # GPIO1_C6
line.request(consumer="blink", type=gpiod.LINE_REQ_DIR_OUT, default_val=0)
try:
    for _ in range(5):
        line.set_value(1); time.sleep(0.5)
        line.set_value(0); time.sleep(0.5)
finally:
    line.release()
```

The v2 API (`pip install gpiod`) is shown in [Linux/libgpiod_intro.md](Linux/libgpiod_intro.md).

**Board-number wrappers**: wiringOP's Python binding (`wiringpi` for Orange Pi, from Orange Pi's GitHub)
and community `RPi.GPIO`-style packages (for example `OPi5.GPIO`) let you use physical pin numbers.
They're third-party: check that they support your board revision and kernel before relying on them.

**Adafruit Blinka** (`pip install Adafruit-Blinka`) runs CircuitPython drivers for sensors and displays on top of libgpiod.
Check that your board is in Blinka's supported list.

## 4. Hardware notes

+ The header is **3.3 V** logic. Never apply 5 V to a GPIO.
+ Many header pins default to I2C/SPI/UART/PWM functions, which are enabled by overlays in `/boot/orangepiEnv.txt` (`overlays=...`).
  If a pin doesn't work as a GPIO, `gpioinfo` shows whether a driver owns it (`EBUSY` on request).
  Remove the overlay or choose another pin.

## Related notes

+ [Linux/libgpiod_intro.md](Linux/libgpiod_intro.md), [Linux/dts_node_leds.md](Linux/dts_node_leds.md) (Rockchip pinctrl/GPIO in DT)
+ [RPi5_gpio_ctrl.md](RPi5_gpio_ctrl.md), [NV_jetson_gpio_ctrl.md](NV_jetson_gpio_ctrl.md), [orangePi.md](orangePi.md)

## Reference

+ [Orange Pi 5 wiki / user manual (orangepi.org)](http://www.orangepi.org/html/hardWiki/index.html)
+ [libgpiod](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)
