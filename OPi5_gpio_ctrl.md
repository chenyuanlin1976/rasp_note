# Orange Pi5: GPIO control

Controlling the GPIO pins on the Orange Pi 5 (powered by the Rockchip RK3588S or RK3588 processor)  
relies on modern Linux architecture.  
Because it uses a Rockchip SoC, traditional Allwinner-based tools  
(like old versions of WiringOP designed for H3 boards) will not work.

The standard and most reliable ways to control the Orange Pi 5 GPIO header  
include command-line tools, Python bindings via `libgpiod`, or SoC-specific libraries.

## Method 1: Using libgpiod (Command Line & Python)

Modern Linux images for the Orange Pi 5 use the kernel's character device interface (`/dev/gpiochipN`).  
This is the most future-proof way to control pins.

1. Install libgpiod Tools:  

```bash
sudo apt update
sudo apt install gpiod libgpiod-dev python3-libgpiod
```

2. Check Available Pins:  
   To inspect the available GPIO chips and their line layout on your specific OS image,  
   run: `gpioinfo`
3. Control Pins via Terminal:  
   + Read a pin state: `gpioget gpiochipX <offset>`
   + Drive a pin High or Low:  

```bash
sudo gpioset gpiochipX <offset>=1
# To set it low:
sudo gpioset gpiochipX <offset>=0
```

## Method 2: Using Python with OPi5.GPIO (Board-Specific Wrapper)

If you prefer a familiar syntax similar to Raspberry Pi's `RPi.GPIO` (using physical pin numbers or board modes),  
community-maintained wrappers built specifically for the Rockchip-based Orange Pi 5 are available.

1. Clone and install a dedicated library  
   (such as community repositories tailored for the Orange Pi 5 RK3588 header):

```bash
git clone https://github.com/hyphen04/OPi5.git
cd OPi5
# Follow repository installation instructions or use python setup
```

2. Example Python Script (BlinkLed.py):

```python
import time
import OPi5.GPIO as GPIO

# Use physical pin numbers on the 40-pin header
pin = 13

GPIO.setmode(GPIO.BOARD)
GPIO.setup(pin, GPIO.OUT)

try:
  while True:
    GPIO.output(pin, GPIO.HIGH)
    time.sleep(1)
    GPIO.output(pin, GPIO.LOW)
    time.sleep(1)
except KeyboardInterrupt:
  GPIO.cleanup()
```

## Method 3: Using CircuitPython via Adafruit-Blinka

If you want cross-compatible Python code that can interface with sensors, screens, and modules using standard higher-level libraries,  
you can layer **Adafruit Blinka** on top of the Orange Pi 5's Linux libgpiod interface.

1. Install Blinka for Orange Pi 5: `pip3 install Adafruit-Blinka`
2. This maps standard CircuitPython digital IO commands directly to the Orange Pi 5's underlying Linux GPIO pins.

## Crucial Hardware Reminders for Orange Pi 5

+ Voltage Level: The 40-pin expansion header on the Orange Pi 5 operates at **3.3V logic**.  
  Do not feed 5V logic directly into any GPIO pin, or you may permanently damage the Rockchip SoC.
+ Pin Multiplexing: Many pins on the 40-pin header double as SPI, I2C, UART, or PWM lines.  
  If a pin refuses to work as a basic digital GPIO,  
  check if it is being occupied or reserved by a device tree overlay in your system configuration.
