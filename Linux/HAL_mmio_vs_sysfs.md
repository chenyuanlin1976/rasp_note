# Accessing hardware from Linux: MMIO vs kernel interfaces

On a Linux board (Raspberry Pi, RK3566, i.MX, ...), there are 2 basic ways for code to reach a peripheral's registers:

+ **The kernel driver owns the hardware.** User space talks to the driver through **sysfs** files or a **character device** (`/dev/...`, `ioctl`).
  This is the normal Linux way.
+ **User space maps the registers itself** (MMIO through `mmap()`) and bypasses the driver.
  This is possible, but it's a special case.

Inside the kernel, drivers always use MMIO, with `ioremap()` + `readl()`/`writel()`.
The question here is only whether **user space** should do it too.

## 1. Direct memory-mapped I/O (MMIO) from user space

Peripheral registers sit at fixed **physical** addresses.
A process can map them into its virtual address space with `mmap()` on `/dev/mem`, and then use plain loads and stores.

Raspberry Pi 2/3 (BCM2836/7) GPIO example: the GPIO block's physical base is `0x3F200000`.
It's `0xFE200000` on the Pi 4, and the Pi 5 has its GPIO in the RP1 chip, behind PCIe, with a different layout.

```c
#include <fcntl.h>
#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>

#define GPIO_BASE  0x3F200000UL      /* BCM2837 (Pi 2/3) */
#define GPFSEL1    (0x04 / 4)        /* function select, pins 10-19 */
#define GPSET0     (0x1C / 4)        /* write 1 = set pin high   */
#define GPCLR0     (0x28 / 4)        /* write 1 = set pin low    */

int main(void) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);          /* needs root; /dev/gpiomem (Pi OS) needs no root, map offset 0 */
    if (fd < 0) return 1;
    volatile uint32_t *gpio = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, GPIO_BASE);
    close(fd);
    if (gpio == MAP_FAILED) return 1;

    gpio[GPFSEL1] = (gpio[GPFSEL1] & ~(7u << 9)) | (1u << 9);   /* pin 13 = output (read-modify-write!) */
    gpio[GPSET0]  = 1u << 13;                                    /* pin 13 high (atomic set register)   */
    gpio[GPCLR0]  = 1u << 13;                                    /* pin 13 low                          */
    return 0;
}
```

+ **Speed**: once mapped, each access is a single store instruction, with no system call.
  That's nanoseconds per access, compared with microseconds for a syscall.
+ **Safety**: there are no checks.
  A wrong offset doesn't just segfault: it writes to *another device's* registers, which can corrupt state, hang the bus, or lock up the board.
  The program also fights with any kernel driver that thinks it owns the same block.
+ **Concurrency**: the read-modify-write of `GPFSEL1` above isn't atomic.
  Another process, or the kernel, changing a neighboring pin at the same moment loses its update.
+ **Access**: needs root or `CAP_SYS_RAWIO`, and kernels built with `CONFIG_STRICT_DEVMEM` / `CONFIG_IO_STRICT_DEVMEM`
  block `/dev/mem` for regions that a driver has claimed.
  Raspberry Pi OS adds `/dev/gpiomem`, which maps **only** the GPIO block, without root.
+ **Portability**: none. Addresses and register layouts differ per SoC, and even per board revision.

## 2. Kernel interfaces: sysfs and character devices

The driver owns the registers. User space makes system calls, and the driver validates the request and does the MMIO.

```c
/* sysfs (one value per text file) - legacy GPIO interface shown */
int fd = open("/sys/class/gpio/gpio13/value", O_WRONLY | O_CLOEXEC);
if (fd >= 0) {
    if (write(fd, "1", 1) != 1) { /* handle errno */ }
    close(fd);
}
```

+ **Speed**: every `write()` is a system call: a user→kernel **mode switch**
  (not a process context switch), text parsing, and the driver code.
  That's a few µs; opening the file each time costs more.
  Keep the descriptor open for repeated writes.
+ **Safety**: the driver checks the input and serializes access (locking), and it can refuse bad values.
  A user-space bug can't corrupt other devices. It can still trigger driver bugs, but those are the kernel's job to handle.
+ **Access control**: per-file DAC (owner, mode, set by **udev** rules or `ueventd.rc` on Android) plus SELinux/AppArmor if enabled.
  A non-root service can be given exactly one LED or one GPIO chip.
+ **Portability**: the same API works on every SoC with a driver; only names or paths differ.

For GPIO in particular, use the **character device** `/dev/gpiochipN` through **libgpiod**, not `/sys/class/gpio`:
sysfs GPIO has been deprecated since Linux 4.8.
The chardev gives line ownership, automatic release when the process exits, atomic multi-line updates, and timestamped edge events.
See [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md) and [libgpiod_intro.md](libgpiod_intro.md).

## 3. Comparison

| | User-space MMIO (`/dev/mem` + `mmap`) | Kernel interface (sysfs / chardev) |
| --- | --- | --- |
| Mechanism | Pointer loads/stores | `open`/`read`/`write`/`ioctl` system calls |
| Cost per access | ~ns | ~µs |
| Who validates / locks | Nobody | The kernel driver |
| Privileges | Root / `CAP_SYS_RAWIO` (or `/dev/gpiomem` on Pi OS) | Per-file permissions, udev, MAC |
| Portability | Tied to one SoC's register map | Same API across SoCs |
| Coexists with kernel drivers | Badly (both touch the same registers) | Yes (the driver arbitrates) |
| Good for | Quick experiments, or legacy libraries (old `wiringPi`/`bcm2835`) | Everything in production |

## 4. What a Linux HAL should use

A user-space HAL (a library or daemon that wraps hardware for applications) should sit on **kernel interfaces**:

1. **Stability**: the driver owns the hardware, so a HAL bug can't scribble over other peripherals.
2. **Concurrency**: the kernel arbitrates between processes.
   For example, gpiolib won't let 2 consumers request the same line.
3. **Security**: grant access per device file, instead of giving the whole physical address space to a root process.
4. **Portability**: the HAL code doesn't change when the SoC changes; the device tree and drivers do.

### When MMIO is the right tool

+ **Kernel drivers**: always (`devm_ioremap_resource()`, `readl()`/`writel()`).
  If you need fast or precise register access, **write or extend a kernel driver**.
+ **Microcontrollers / RTOS** (STM32, ESP32, ...): there's no kernel boundary, so the vendor HAL writes registers directly.
  See [HAL_Std_Func.md](HAL_Std_Func.md).
+ **Special user-space drivers**: frameworks such as **UIO** and **VFIO** let user space `mmap` one device's registers safely,
  with the kernel still handling interrupts and permissions.
  This is used for FPGAs and for DPDK/SPDK network and storage.
+ **High-speed bit-banging**: user-space MMIO is faster than sysfs, but Linux isn't real-time,
  so the timing still jitters by µs to ms.
  Use a hardware peripheral (SPI, PWM, PIO/DMA) or a co-processor instead.

## Related notes

+ [HAL_DeviceTree.md](HAL_DeviceTree.md), [HAL_intro.md](HAL_intro.md), [HAL_Std_Func.md](HAL_Std_Func.md)
+ [libgpiod_intro.md](libgpiod_intro.md), [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md), [legacy_sysfs_gpio_if.md](legacy_sysfs_gpio_if.md)
+ [../Android/HAL_sysfsNodes.md](../Android/HAL_sysfsNodes.md): the same layering on Android

## Reference

+ [GPIO character device uAPI (kernel docs)](https://docs.kernel.org/userspace-api/gpio/chardev.html)
+ [The Userspace I/O HOWTO (kernel docs)](https://docs.kernel.org/driver-api/uio-howto.html)
+ BCM2835 ARM Peripherals datasheet, chapter 6 "General Purpose I/O"
