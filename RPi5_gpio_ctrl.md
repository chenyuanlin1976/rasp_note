# RPi 5 GPIO control

Controlling GPIOs on the **Raspberry Pi 5** is notably **different** from older models (like the Pi 4 or Pi 3).

The Raspberry Pi 5 replaces the traditional Broadcom SoC direct memory mapping with a custom southbridge chip called RP1.  
Because of this hardware change, legacy libraries like `RPi.GPIO`, `pigpio`, and `WiringPi` do **not** work  
and will throw errors (such as `RuntimeError`: Cannot determine SOC peripheral base address).

Instead, modern Raspberry Pi OS relies on `lgpio`, `gpiozero`, or standard `libgpiod` character devices (`/dev/gpiochip4`).

## Method 1: Using gpiozero (Recommended for Python)

`gpiozero` is the official, high-level Python library for Raspberry Pi.  
It abstracts hardware into clean components (like LED, Button, MotionSensor)  
and automatically uses `lgpio` as its backend on the Pi 5.

### 1. Installation

`gpiozero` and its backend `lgpio` come pre-installed on Raspberry Pi OS.  
If you need to install them manually:

```bash
sudo apt update
sudo apt install python3-gpiozero python3-lgpio -y
```

### 2. Example Code (Blinking an LED)

Using BCM pin numbering (e.g., GPIO 17, which corresponds to physical Pin 11):

```python
from gpiozero import LED
from time import sleep

# Define LED connected to GPIO 17
led = LED(17)

while True:
  led.on()
  sleep(1)
  led.off()
  sleep(1)
```

## Method 2: Using lgpio Directly (For Low-Level Control)

If you need precise timing, hardware-timed PWM, or want a lower-level procedural approach,  
you can call `lgpio` directly in Python.

### 1. Example Code (Blinking with lgpio)

```python
import time
import lgpio

# Open the GPIO chip (on Pi 5, chip 0 handles the 40-pin header)
h = lgpio.gpiochip_open(0)

# Set GPIO 17 as an output
PIN = 17
lgpio.gpio_claim_output(h, PIN)

try:
  while True:
    lgpio.gpio_write(h, PIN, 1)  # Turn ON (High)
    time.sleep(1)
    lgpio.gpio_write(h, PIN, 0)  # Turn OFF (Low)
    time.sleep(1)
finally:
  lgpio.gpiochip_close(h)
```

## Method 3: Command-Line Tools (pinctrl and gpiod)

Raspberry Pi OS includes built-in command-line tools  
to check and modify pin states directly from the terminal without writing scripts.

### 1. Using pinctrl (Raspberry Pi's Native Tool)

`pinctrl` is built specifically for modern Pi hardware to inspect and alter pin multiplexing and states.

+ View the state of all 40 pins: `pinctrl get`
+ Set GPIO 17 as an output and pull it High (1):

```bash
pinctrl set 17 op
pinctrl set 17 dh
```

+ Set GPIO 17 low (0): `pinctrl set 17 dl`

### 2. Using Standard libgpiod Tools (gpioset / gpioget)

The Pi 5 maps the main 40-pin header to `gpiochip4`  
(or `gpiochip0` depending on the kernel/tool version mapping).

+ Read pin state: `gpioget gpiochip4 17`
+ Set pin state: `gpioset gpiochip4 17=1`

## Quick Migration Tip for Old Scripts

If you have an old project written entirely for `RPi.GPIO`  
that you don't want to rewrite line-by-line, you can install the `rpi-lgpio` compatibility layer:

```bash
sudo apt remove python3-rpi.gpio
pip install rpi-lgpio
```

This translates old import RPi.GPIO commands so they route through lgpio safely on the Pi 5.
