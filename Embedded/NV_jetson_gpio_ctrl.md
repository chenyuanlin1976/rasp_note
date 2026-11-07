# NVIDIA Jetson Orin Nano: GPIO control

Controlling a header GPIO on the Jetson Orin Nano developer kit (JetPack 6.x, Ubuntu 22.04) takes 2 steps:

1. **Pinmux**: make the pin a GPIO. Most header pins default to special functions (I2C, SPI, UART, I2S).
2. **Runtime control** through the GPIO character device: libgpiod tools, or the `Jetson.GPIO` Python library.

## 1. Configure the pin with jetson-io

```shell
sudo /opt/nvidia/jetson-io/jetson-io.py
```

1. Choose **Configure Jetson 40pin Header** → **Configure header pins manually**.
2. Select the functions you need. The tool generates a device-tree overlay.
   Pins that aren't assigned to a special function stay GPIOs.
3. **Save and reboot**.

Some pins (for example header pin 7, `GPIO09`) are GPIOs by default. jetson-io shows the current assignment.

## 2. Command line (libgpiod)

Tegra GPIO lines are **named by SoC port**, such as `PAC.06`, so you can look them up by name instead of guessing offsets:

```shell
gpiodetect                       # tegra234-gpio (main, ~164 lines) and tegra234-gpio-aon
gpioinfo | grep -E "PAC.06|PQ.05"
gpiofind PAC.06                  # -> e.g. "gpiochip0 144" (libgpiod v1 on Ubuntu 22.04)

gpioget $(gpiofind PAC.06)
sudo gpioset --mode=wait $(gpiofind PAC.06)=1      # hold high until Enter
```

+ The header-pin → Tegra-port mapping is in the developer kit's pinmux spreadsheet or carrier board spec.
  For example, pin 7 = GPIO09 = `PAC.06`.
  The line numbers differ between JetPack releases, so look them up on your system.
+ A plain v1 `gpioset` **releases** the line when it exits, and the pin may return to its previous state.
  To keep a level, hold the line (`--mode=wait|signal`) or control it from a running program.

## 3. Python: Jetson.GPIO

`Jetson.GPIO` comes with JetPack. It has an `RPi.GPIO`-style API on top of the character device.

```shell
sudo groupadd -f -r gpio
sudo usermod -a -G gpio $USER     # then log out/in
# if Jetson.GPIO was installed with pip, also install its udev rules (99-gpio.rules) as its README describes
```

```python
import time
import Jetson.GPIO as GPIO

PIN = 7                       # physical header pin (BOARD mode)

GPIO.setmode(GPIO.BOARD)
GPIO.setup(PIN, GPIO.OUT, initial=GPIO.LOW)
try:
    for _ in range(5):
        GPIO.output(PIN, GPIO.HIGH); time.sleep(0.5)
        GPIO.output(PIN, GPIO.LOW);  time.sleep(0.5)
finally:
    GPIO.cleanup()            # release the pins
```

The libgpiod Python bindings (`python3-libgpiod`, v1) also work; see [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md).

## 4. Hardware notes

+ The SoC's pins are **1.8 V**. On the developer kit carrier board, the 40-pin header is level-shifted to **3.3 V**.
  Many header lines go through bidirectional, weak level shifters, so they drive only small loads.
  Use a buffer or transistor for LEDs or relays.
  Custom carrier boards may expose 1.8 V. Check your board's design guide.
+ Pins that a pinmux/overlay assigns to I2C/SPI/UART are owned by those drivers. Requesting them as GPIO fails with `EBUSY`.

## Related notes

+ [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md), [../Linux/libgpiod_sysfs_cmp.md](../Linux/libgpiod_sysfs_cmp.md)
+ [RPi5_gpio_ctrl.md](RPi5_gpio_ctrl.md), [OPi5_gpio_ctrl.md](OPi5_gpio_ctrl.md)

## Reference

+ [Jetson.GPIO (GitHub)](https://github.com/NVIDIA/jetson-gpio)
+ Jetson Linux Developer Guide (docs.nvidia.com/jetson), section "Configuring the Jetson Expansion Headers" for your JetPack release
