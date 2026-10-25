# HAL implemation

When working with hardware in Linux (such as on a Raspberry Pi, an embedded Linux board, or even a custom driver),  
you generally have 2 main ways to interact with hardware registers  
from **user space** or **kernel space**:  
reading/writing `sysfs` nodes vs. directly writing to memory-mapped registers (`MMIO`).

Here is a breakdown of the differences between these 2 approaches.

## 1. Direct Memory-Mapped I/O (MMIO)

In MMIO, physical hardware registers are mapped directly into the CPU's memory address space.  
Your code writes a value directly to a specific memory pointer address.

+ How it works: You use a system call like `mmap()` to map physical memory addresses  
  (e.g., 0x3F200000 for Raspberry Pi GPIO) into your user-space process's virtual memory, and then dereference pointers:

  ```c
  volatile uint32_t *gpio_register = (uint32_t *)mapped_address;
  *gpio_register = (1 << 13); // Directly write to the hardware bit
  ```

+ Speed: Blazing fast. It involves a direct CPU instruction (store to memory).  
  **There is zero kernel overhead**, zero file parsing, and no context switching once mapped.
+ Safety: Extremely dangerous. There are no guardrails.  
  If you write the wrong memory address, you will cause a Segmentation Fault and crash your program  
  - or worse, lock up the entire operating system hardware.
+ Portability: Zero. If you switch from a Broadcom chip to an Allwinner chip,  
  the physical memory addresses and register bit layouts change completely, breaking your code.

## 2. Reading/Writing sysfs Nodes (/sys/...)

As discussed earlier, `sysfs` is a virtual file system managed by the Linux kernel.

+ How it works: Your program opens a text file, writes a string to it, and closes it using standard file I/O:

  ```c
  int fd = open("/sys/class/gpio/gpio13/value", O_WRONLY);
  write(fd, "1", 1);
  close(fd);
  ```

+ Speed: Slow. Every time you call open, write, or close, the OS must perform a context switch (switching from user space to kernel space),  
  parse the text string, and execute kernel driver code.  
  It is thousands of times slower than MMIO.
+ Safety: High (Controlled). **The kernel driver acts as a bouncer.**  
  It validates your input (e.g., rejecting invalid strings), checks file permissions,  
  and ensures your application doesn't touch memory it isn't allowed to access.
+ Portability: Medium to High. The `sysfs` path might change depending on the driver,  
  but the abstraction hides the underlying memory addresses.  
  Well-written user-space apps can query device trees or configuration files to find the correct path dynamically.

## Summary Comparison

### Feature: Direct Memory Mapping (MMIO)

+ Primary Mechanism: Pointer dereferencing via `mmap()`
+ Execution Speed: Instant/ Ultra-fast (direct CPU memory write)
+ Safety & Stability: None (bugs can crash the entire OS)
+ Permissions/ Access: Requires **root** (/dev/mem) or kernel module
+ Portability: Hardcoded to specific silicon memory maps
+ Best Used For: High-frequency bit-banging, fast peripheral drivers (SPI/PWM)

### Feature: Sysfs Nodes (/sys/...)

+ Primary Mechanism: File I/O operations (open, read, write)
+ Execution Speed: Slow (kernel context switches and text parsing)
+ Safety & Stability: High (kernel driver protects system stability)
+ Permissions/ Access: Managed by standard Linux file permissions & SELinux
+ Portability: Abstracted by kernel device drivers
+ Best Used For: Configuration, status monitoring, LEDs, sensors, infrequent user commands

## HAL implemation in Linux

When writing a Hardware Abstraction Layer (**HAL**) in a Linux environment,  
the architecture almost always prefers `Sysfs` nodes  
(or modern kernel APIs like Character Devices / libgpiod)  
over raw direct memory mapping (`MMIO`), unless there is an extreme performance requirement.

Here is why vendor and platform HALs strongly prefer kernel interfaces over raw memory access:

### Why HAL Prefers Kernel Interfaces (Sysfs / Drivers) Over Raw MMIO

1. **Safety and Kernel Stability**  
   + **MMIO**: If a HAL written in user space uses raw `mmap()` to touch hardware registers,  
     a single software bug or bad pointer calculation can corrupt system memory or instantly kernel-panic the entire operating system.
   + **HAL via Kernel**: The Linux kernel driver owns the hardware.  
     The HAL simply asks the kernel (via sysfs or char devices) to do the work.  
     If something goes wrong, the kernel catches the error safely without crashing the system.
2. **Multi-Process Concurrency and Lock Management**  
   + **MMIO**: If 2 different applications or threads try to write to the same memory-mapped register at the same time using MMIO,  
     they will overwrite each other's bits, causing corrupted states (race conditions).
   + **HAL via Kernel**: The Linux kernel acts as a central arbiter.  
     It handles locking, queuing, and synchronization so multiple programs can safely request hardware actions  
     without stepping on each other's toes.
3. Security and Permissions  
   + **MMIO**: Giving user-space code direct access to physical memory requires **root** privileges (/dev/mem),  
     which is a massive security vulnerability.
   + **HAL via Kernel**: Sysfs nodes and device files allow fine-grained access control.  
     The system administrator can change file permissions (chmod or udev rules)  
     so a non-root Android or Linux service can safely toggle an LED or read a sensor.

### The Modern Evolution: Sysfs vs. Character Devices (libgpiod)

While `sysfs` was the gold standard for a long time,  
it has performance limitations (due to text parsing).

+ In modern Linux development,  
  `sysfs` for GPIO has actually been deprecated in favor of the Character Device GPIO interface  
  (`/dev/gpiochipX`) accessed via libraries like `libgpiod`.
+ However, the principle remains identical: the HAL calls a structured API or file descriptor managed by the kernel,  
  rather than poking raw memory addresses.

### Summary Exception: When is MMIO actually used?

A HAL will only use direct memory mapping (MMIO)  
when running on bare-metal systems or RTOS (Real-Time Operating Systems),  
(such as an STM32 microcontroller or an Arduino) where there is no Linux kernel at all.  
In those environments, your code is the operating system, so MMIO is the only way to talk to the silicon.
