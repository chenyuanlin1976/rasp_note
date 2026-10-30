# sysfs nodes for leds control

Unlike GPIOs which transitioned from the legacy `/sys/class/gpio/` directory to the modern **character device** `/dev/gpiochip*`,  
LEDs do **not** use a `/dev/` **character device interface**.

Instead, the Linux kernel manages LEDs entirely through a dedicated **sysfs-based** subsystem located at: `/sys/class/leds/`

## Why LEDs Stay on Sysfs (Instead of /dev/)

+ No Polling or Interrupts Needed:  
  GPIOs need character devices (`/dev/gpiochip*`)  
  because apps often need to read inputs or wait for fast hardware interrupts (button presses).  
  LEDs are almost always write-only outputs.
+ The Trigger System:  
  The core power of Linux LEDs is the kernel trigger framework (heartbeat, timer, mmc0).  
  Writing text values to /sys/class/leds/.../trigger is the intended, standard way to configure them.

## What if you really want a character device for an LED

If your architecture or Android application framework strictly requires a `/dev/` node to interact with an LED  
(for instance, if a custom hardware abstraction layer (HAL) is built to read/write character devices exclusively)

1. **Write a Custom Character Driver**:  
   You can write a tiny kernel module that registers a `/dev/my_led` character device  
   and internally calls the kernel's LED API (`led_classdev_set_brightness`).
2. Control the underlying GPIO directly via `libgpiod` (`/dev/gpiochip*`):  
   If you bypass the Linux LED subsystem entirely and treat the LED pin as a raw GPIO using `/dev/gpiochip*`,  
   you lose built-in triggers like heartbeat,  
   but you gain a character-device-based workflow to toggle the pin programmatically.
