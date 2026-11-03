# Loadable kernel modules (`.ko`)

A `.ko` file ("kernel object") is a **loadable kernel module**: compiled kernel code that can be inserted into
and removed from a running kernel. Most drivers, file systems, and protocols can be built either into the kernel image
(`CONFIG_FOO=y`) or as a module (`CONFIG_FOO=m`); see [kernel_build.md](kernel_build.md).

+ Module code runs **in kernel space** with full privileges, in the same address space as the rest of the kernel.
  A bug can crash (oops/panic) or corrupt the whole system. A `.so` library, by contrast, runs in a user process.
+ Modules keep the kernel image small and load drivers only for the hardware that is present.

## 1. Commands

```shell
lsmod                                   # loaded modules, size, users (also /proc/modules)
modinfo hello.ko                        # or a module name: description, license, parameters, vermagic, alias
sudo modprobe ftdi_sio                  # load by name from /lib/modules/$(uname -r), with its dependencies
sudo modprobe -r ftdi_sio               # unload (with unused dependencies)
sudo insmod ./hello.ko count=3          # load one file by path, no dependency handling (development)
sudo rmmod hello
cat /sys/module/hello/parameters/count  # parameters of a loaded module (if readable)
sudo depmod -a                          # rebuild modules.dep / modules.alias after installing modules
```

+ Modules live in `/lib/modules/$(uname -r)/kernel/{drivers,fs,net,...}`.
+ **Automatic loading**: drivers declare the devices they support (`MODULE_DEVICE_TABLE`), which becomes **aliases**
  (`modules.alias`). When the kernel finds a device, udev runs `modprobe <modalias>` and the right module loads.
+ Boot-time loading: `/etc/modules-load.d/*.conf`. Options: `/etc/modprobe.d/*.conf` (`options ftdi_sio ...`, `blacklist ...`).

## 2. A minimal module, built outside the kernel tree

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/module.h>

static int count = 1;
module_param(count, int, 0444);
MODULE_PARM_DESC(count, "how many greetings to print");

static int __init hello_init(void)
{
	int i;

	for (i = 0; i < count; i++)
		pr_info("hello %d\n", i);
	return 0;
}

static void __exit hello_exit(void)
{
	pr_info("bye\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Minimal example module");
```

```make
# Makefile (the recipe lines start with a TAB)
obj-m += hello.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
```

```shell
sudo apt install linux-headers-$(uname -r)    # provides /lib/modules/$(uname -r)/build
make                                          # -> hello.ko
sudo insmod hello.ko count=2 && sudo dmesg | tail -2 && sudo rmmod hello
```

This example was built against Ubuntu's 6.14 headers, and `checkpatch.pl` reports no problems.

For a board, point `KDIR` at the **configured and built** kernel source that the board runs, and cross-compile:
`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=~/rk3566-kernel`.

## 3. Why a `.ko` only loads into "its" kernel

A module is machine code for one CPU architecture, **and** it links against internal kernel symbols and structure layouts
that change between versions and configurations. Several checks reject a mismatch:

| Check | What it compares | Typical message (`insmod`, then `dmesg`) |
| --- | --- | --- |
| Architecture | ELF machine type (x86-64 vs AArch64) | `Invalid module format` |
| **vermagic** | Kernel version string + key options (`SMP preempt mod_unload modversions`) | `Invalid module format`; dmesg: `version magic '...' should be '...'` |
| **modversions** (`CONFIG_MODVERSIONS`) | A CRC for each used symbol's prototype | `disagrees about version of symbol ...` |
| Missing symbols | Symbols the module needs but the kernel doesn't export | `Unknown symbol ...` |
| **Module signing** (`CONFIG_MODULE_SIG_FORCE`, Secure Boot lockdown) | Signature by a trusted key | `Key was rejected by service` / `Required key not available` |
| License | Non-GPL modules can't use `EXPORT_SYMBOL_GPL` symbols, and they "taint" the kernel | `Unknown symbol` / taint message |

```shell
modinfo -F vermagic hello.ko     # 6.14.0-33-generic SMP preempt mod_unload modversions
uname -r                         # must match the version part
```

So rebuild modules for every kernel, or use DKMS, which rebuilds out-of-tree modules automatically when a new kernel is installed.

### 3.1 Android: GKI and vendor modules

On Android 12+ devices with a **Generic Kernel Image (GKI)**, Google builds the kernel,
and SoC and device drivers are **vendor modules** in `vendor_dlkm` (and boot-critical ones in `vendor_boot`).
The **KMI** (kernel module interface) is a stable list of exported symbols, with ABI checking, for each GKI branch.
Vendor modules built against it keep loading after GKI security updates within the same branch.
They are built with Kleaf/DDK ([../Android/Bazel_intro.md](../Android/Bazel_intro.md)).

## Related notes

+ [kernel_build.md](kernel_build.md), [kernel_coding_style.md](kernel_coding_style.md), [dts_driver.md](dts_driver.md)
+ [sysfs_intro.md](sysfs_intro.md): `/sys/module/` shows loaded modules and their parameters

## Reference

+ [Building external modules (kernel docs)](https://docs.kernel.org/kbuild/modules.html)
+ [Module signing (kernel docs)](https://docs.kernel.org/admin-guide/module-signing.html)
+ [Generic Kernel Image and KMI (AOSP)](https://source.android.com/docs/core/architecture/kernel/generic-kernel-image)
+ `man 8 modprobe`, `man 5 modprobe.d`, `man 8 depmod`
