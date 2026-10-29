# libgpiod introduction

## What is libgpiod

`libgpiod` is a C library and set of command-line tools used to interact with the GPIO  
(General-Purpose Input/Output) **character devices** on Linux systems.

It was created to replace the older, now-deprecated **sysfs** GPIO interface (`/sys/class/gpio`),  
which had performance bottlenecks, race conditions, and was eventually removed from the Linux kernel.  

`libgpiod` interfaces directly with the modern GPIO character device ABI (`/dev/gpiochipN`),  
making it cleaner, faster, and more robust.

## Key Components of libgpiod

1. The Library (`libgpiod`):  
   A C library that developers can use in their own applications to control GPIO lines programmatically.  
   There are also bindings available for other languages, most notably Python (gpiod).
2. Command-Line Tools:  
   A set of handy utilities included in the package for scripting and debugging directly from the terminal:

   + `gpiodetect`: Lists all available GPIO chips on the system along with their labels and number of lines.
   + `gpioinfo`: Shows detailed information about all lines on a specific GPIO chip (their names, consumers, direction, active state, etc.).
   + `gpioget`: Reads the current value(s) of specified GPIO line(s).
   + `gpioset`: Sets the output value of specified GPIO line(s).
   + `gpiomon`: Monitors GPIO lines for specific events (like rising or falling edges, indicating a button press or sensor trigger).

## Why Use libgpiod

+ Modern Standard: It is the official, future-proof way to handle GPIOs on Linux  
  (heavily used on single-board computers like the Raspberry Pi, BeagleBone, and various embedded ARM boards).
+ Better Performance: Direct kernel interaction via `ioctl` calls is much faster than reading and writing text files in **sysfs**.
+ Safety & Reliability: It supports proper handle management and prevents race conditions when multiple programs try to access the same pin.

## Example: Using Python (gpiod)

If you are working with a Raspberry Pi running a modern OS (like Raspberry Pi OS Bookworm or later),  
you will typically use the Python bindings for `libgpiod` to control pins:

```python
import gpiod

# Find the chip (e.g., gpiochip4 on newer Raspberry Pi models)
chip = gpiod.Chip("gpiochip4")

# Get a specific line (e.g., line 17)
line = chip.get_line(17)

# Request the line as an output
line.request(consumer="my_script", type=gpiod.LINE_REQ_DIR_OUT)

# Set the pin high (3.3V)
line.set_value(1)

# Set the pin low (0V)
line.set_value(0)
```

## Note

Depending on the specific version of `libgpiod` and Python bindings installed on your system,  
the API might use object-oriented line requests, but the underlying concept remains the same.
