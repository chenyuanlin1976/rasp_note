# libgpiod introduction

`libgpiod` is the modern, standard C library and toolkit used to interact with GPIO (General Purpose Input/Output) pins on Linux systems.  
It was created to replace the legacy `sysfs` GPIO interface (`/sys/class/gpio`),  
which has been officially deprecated by the Linux kernel since version 4.8.

## Why libgpiod Replaced sysfs

+ The Legacy `sysfs` Flaws:  
  The old `sysfs` interface treated GPIOs as a collection of files and directories.  
  This caused race conditions, struggled heavily with multi-pin operations, lacked robust event handling,  
  and left orphaned configurations if a program crashed.
+ The **Character Device Approach** (`libgpiod`):  
  Linux introduced a character device interface (`/dev/gpiochipN`) managed via `ioctl` calls.  
  `libgpiod` wraps these complex `ioctl` operations into clean, safe, and easy-to-use APIs.

## Core Components of libgpiod

`libgpiod` is divided into 2 primary parts:

1. The Library (`libgpiod`):  
   + Written in C (with a C++ wrapper).
   + Provides bindings for high-level languages like Python.
   + Guarantees proper resource cleanup when file descriptors are closed (preventing kernel-level pin leaks).
2. Command-Line Tools (`gpiod` utilities):  
   A helpful suite of command-line applications for debugging and quick scripting without writing code:
   + `gpiodetect`: Lists all GPIO chips present on the system and their line counts.
   + `gpioinfo`: Displays detailed information about all lines on a specific chip  
     (e.g., whether they are inputs, outputs, current values, or actively claimed by a driver).
   + `gpioget`: Reads the logic level (0 or 1) of specified GPIO lines.
   + `gpioset`: Sets the logic level of specified GPIO lines.
   + `gpiomon`: Monitors GPIO lines for events (like rising or falling edges, e.g., button presses) and prints event details to the terminal.

## Key Advantages

+ Atomic Multi-line Operations:  
  You can request and change the values of multiple GPIO lines simultaneously,  
  which is critical for parallel buses or tightly timed hardware interfaces.
+ Event Notification:  
  Built on efficient polling mechanisms (epoll),  
  making it trivial to wait for hardware interrupts (button presses, sensor triggers) with low latency.
+ No Kernel Modules Required:  
  Operates strictly through user-space character devices provided the user/process has appropriate permissions (gpio group or root).

## Quick Example: Python Usage

Because `libgpiod` has native bindings, using it in Python is straightforward (using version 2+ object-oriented style):

```python
import gpiod

# Find the gpiochip (e.g., chip 0) and configure a line as output
chip_path = "/dev/gpiochip0"
line_offset = 17  # GPIO pin number

# Request the line as output
with gpiod.request_lines(
    chip_path,
    consumer="my-led-script",
    config={line_offset: gpiod.LineSettings(direction=gpiod.line.DIRECTION_OUTPUT)},
) as request:

  # Turn LED on
  request.set_value(line_offset, gpiod.line.VALUE_ACTIVE)

  # Turn LED off
  request.set_value(line_offset, gpiod.line.VALUE_INACTIVE)
```

## When should you use it?

If you are developing embedded Linux applications  
(such as on Raspberry Pi, BeagleBone, or custom industrial boards running modern Linux kernels)  
and need to read sensors, blink LEDs, or handle hardware interrupts via GPIO,  
`libgpiod` is the mandatory toolset to use.
