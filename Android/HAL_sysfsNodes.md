# HAL and sysfs

To understand the difference between using a HAL (Hardware Abstraction Layer)  
and reading/writing directly to `/sys/class/...` nodes (`sysfs`),  
it helps to look at them as 2 different levels of abstraction in a software stack.

In short:  
Reading/writing to sysfs nodes is a technique that a HAL implementation often uses under the hood.  
They are not mutually exclusive, but **they serve different layers of architecture**.

## 1. What is  sysfs node

**Sysfs node** is a virtual filesystem provided by the Linux kernel.  
**It exposes kernel objects, device drivers, and their hardware parameters as ordinary text files.**

+ How you use it: Using standard file operations (open, read, write, close) **in C, C++, or even shell scripts**.
+ Example: To turn on an LED using sysfs on an embedded Linux system, you literally write text into a file:

`echo "255" > /sys/class/leds/red_led/brightness`

## 2. What is a HAL?

**A HAL is an API contract**/ software architecture layer that sits above the OS kernel (and above things like `sysfs`).  
It defines a strict, standardized set of functions that higher-level software (like an Android framework or application service) can call.

How you use it: By calling a structured function interface (e.g., in C++ or via Binder RPC):
`module->set_light(module, LIGHT_ID_BACKLIGHT, &state);`

## 3. Key Differences: HAL vs. Sysfs Nodes

### Feature of Sysfs Nodes (/sys/class/...)

+ What is it: **A kernel-to-userspace interface** (files and directories).
+ Where does it live: In the Linux kernel space (**exposed to userspace as files**).
+ Language/Format: *Text-based file I/O* (open, write, text strings like "255").
+ Portability: **Low**. Sysfs paths (`/sys/class/leds/...` or naming schemes) change depending on the kernel version, vendor, or device driver.
+ Access Control: Controlled by standard Linux **file permissions** (e.g., `chmod` on the file).

### Feature of HAL

+ What is it: A software API interface (functions, classes, contracts).
+ Where does it live: In userspace, acting as middleware between apps and the kernel.
+ Language/Format: Programmatic function calls (struct pointers, strongly typed arguments).
+ Portability: **High**. The HAL hides those messy paths. Even if the sysfs path changes, the HAL API stays identical.
+ Access Control: Controlled by platform security models (e.g., **Android Binder permissions, SELinux policies**).

## 4. How They Work Together (The Real-World Reality)

If you look at the source code of an actual Android HAL implementation  
(for example, the Android Lights HAL or Backlight HAL),  
you will **often** find that the HAL itself is just a wrapper around `sysfs` nodes!

When the Android framework calls the HAL function `setLightState(...)`:

1. The HAL code executes in C++.
2. The HAL code opens the file descriptor: `open("/sys/class/backlight/panel/brightness", O_WRONLY)`.
3. The HAL writes the calculated brightness value into that sysfs file.
4. The Linux kernel driver picks up that write in `sysfs` node and toggles the hardware registers.

## Summary Analogy

+ Sysfs node is like the raw wiring and plumbing behind your wall (pipes, valves, wires).  
  It gets the job done, but it's raw, hardware-dependent, and messy to interact with directly.
+ The HAL is the modern smart-home wall switch panel.  
  It gives you a clean, standardized button (Turn On) so you don't have to care about what kind of pipes or wires are hidden inside the wall.  
  Inside the wall switch, it might pull the physical wires, but to the user, it provides a safe, uniform interface.
