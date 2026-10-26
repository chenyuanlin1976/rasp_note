# control GPIO pins on the NVIDIA Jetson Orin Nano

Controlling GPIO pins on the NVIDIA Jetson Orin Nano (especially on modern JetPack 6.x releases)  
differs significantly from traditional microcontrollers like Arduino or older single-board computers like Raspberry Pi.  

Because the pins on the Orin Nano's 40-pin expansion header are heavily multiplexed (shared with I2C, SPI, UART, etc.),  
controlling them requires a 2-step process: pin configuration (Pinmux) and runtime control using libgpiod (or the Python wrapper).

## Step 1: Configure the Pin via jetson-io

By default, expansion header pins might be assigned to special functions (like a serial port or SPI) rather than generic GPIO.  
You must tell the system to use them as GPIOs first.

1. Run NVIDIA's built-in pin configuration tool:  
   `sudo /opt/nvidia/jetson-io/jetson-io.py`
2. Select Configure Jetson 40Pin Header.
3. Find the pin you want to use (e.g., Pin 7/ GPIO09) and change its configuration function to GPIO.
4. Choose Save and reboot to apply the Device Tree overlay and restart the board.

## Step 2: Identify and Control GPIOs via Command Line (libgpiod)

Modern JetPack versions use the modern Linux `libgpiod` character-device framework (`/dev/gpiochipN`)  
instead of the deprecated `sysfs` interface.

1. Inspect the Available Chips and Lines:  
   Run `gpioinfo` to list all GPIO controllers and lines: `gpioinfo`  
   You can also locate a specific named pin using: `gpiofind "GPIO_PIN_NAME"`
2. Read a Pin State (gpioget):  
   To read the logic level (0 or 1) of a specific line on a chip (e.g., gpiochip0, line 232):
   `gpioget gpiochip0 232`
3. Set a Pin Output (gpioset):  
   To drive a pin high (1) or low (0):

```bash
# Set line 232 high (3.3V)
sudo gpioset gpiochip0 232=1

# Set line 232 low (0V)
sudo gpioset gpiochip0 232=0
```

### Step 3: Controlling GPIOs with Python

NVIDIA provides support through Python (**Jetson.GPIO**)  
which interacts cleanly with the underlying character devices, or you can use native python bindings for `libgpiod`.

Using the official `Jetson.GPIO` library (which mirrors standard Raspberry Pi RPi.GPIO syntax):

1. Install or verify the library: `sudo pip install Jetson.GPIO`
2. Ensure your user is added to the gpio group so you don't always need `sudo`:

```bash
sudo groupadd -f -r gpio
sudo usermod -a -G gpio $USER
```

3. Run a basic Python script (e.g., blink.py) using BOARD mode (physical pin numbers 1-40):

```python
import time
import Jetson.GPIO as GPIO

# Use physical board pin numbers (e.g., Pin 7)
PIN_T = 7

# Setup channel
GPIO.setmode(GPIO.BOARD)
GPIO.setup(PIN_T, GPIO.OUT)

print("Blinking pin 7. Press CTRL+C to stop.")

try:
  while True:
    GPIO.output(PIN_T, GPIO.HIGH)
    time.sleep(1)
    GPIO.output(PIN_T, GPIO.LOW)
    time.sleep(1)
except KeyboardInterrupt:
  # Clean up states on exit
  GPIO.cleanup()
```

## Important Hardware Notes for Jetson Orin Nano

1. Voltage Levels: The 40-pin header on the Orin Nano operates at **1.8V logic by default** on some pins, or switchable,  
   but standard carrier boards route 3.3V/1.8V compatible rails.  
   **Always verify your external peripheral requirements to prevent damage.**
2. Transient States: Setting a pin via command line (gpioset) is temporary and resets when the command or script terminates,  
   unless held or controlled continuously via a running daemon/script.
