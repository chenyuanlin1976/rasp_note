# Building the Linux kernel: Kconfig and Kbuild

Two systems drive a kernel build:

+ **Kconfig** decides **what** is built. `Kconfig` files declare options, and the `make *config` targets write the choices to **`.config`**.
+ **Kbuild** decides **how**. The `Makefile` in each directory lists objects depending on those options, and the top-level `make` compiles them.

Loadable modules (`.ko`) are in [kernel_module.md](kernel_module.md). Android kernels use Kleaf (Bazel) on top of this; see [../Android/Bazel_intro.md](../Android/Bazel_intro.md).

## 1. Configure

```shell
make defconfig                    # default config for the architecture (arch/<arch>/configs/defconfig)
make bcm2711_defconfig            # or a board/SoC defconfig (this one: Raspberry Pi 4 in the raspberrypi/linux tree)
make menuconfig                   # text UI (needs libncurses-dev); '/' searches for an option
make olddefconfig                 # update an existing .config for a newer kernel: new options get their defaults
make savedefconfig                # write a minimal 'defconfig' file (only non-default values) to keep in git
scripts/config --enable CONFIG_LEDS_GPIO --module CONFIG_USB_SERIAL_FTDI_SIO   # edit .config from scripts
make olddefconfig                 # resolve dependencies after scripts/config
```

On a running system, the active configuration is in `/boot/config-$(uname -r)`, or in `/proc/config.gz` if `CONFIG_IKCONFIG_PROC=y`.

### 1.1 `Kconfig` syntax

```text
# drivers/misc/Kconfig
config MY_SENSOR
	tristate "My I2C sensor driver"
	depends on I2C && OF
	select REGMAP_I2C
	default n
	help
	  Driver for the XYZ temperature sensor.
	  Say M to build it as a module called my_sensor.
```

| Keyword | Meaning |
| --- | --- |
| `bool` / `tristate` | `y`/`n`, or `y` (built in) / `m` (module) / `n` |
| `int`, `hex`, `string` | Value options, often with `range` |
| `depends on X` | The option is only visible and settable when `X` is enabled |
| `select X` | Forces `X` on, **ignoring `X`'s own dependencies**. Use it only for library-like options with no dependencies |
| `imply X` | Like `select`, but `X` can still be turned off |
| `default` | Default value (`default y if ARCH_ROCKCHIP`) |
| `menu` / `if` / `source "dir/Kconfig"` | Structure and inclusion |

## 2. Kbuild makefiles

```make
# drivers/misc/Makefile
obj-$(CONFIG_MY_SENSOR) += my_sensor.o      # CONFIG_MY_SENSOR=y -> obj-y (built in), =m -> obj-m (module)
my_sensor-y := core.o i2c.o                 # a module built from several source files
obj-y += always_built.o
obj-$(CONFIG_FOO) += foo/                   # descend into a subdirectory
ccflags-y += -DDEBUG                        # extra compiler flags for this directory
```

## 3. Build and install

```shell
make -j"$(nproc)"                      # vmlinux, the compressed image, modules, DTBs (depending on the architecture)
sudo make modules_install              # -> /lib/modules/<version>/
sudo make install                      # copy the image to /boot, run the distribution's installkernel hook
```

### 3.1 Cross-compiling for ARM64 boards (RK3566, Raspberry Pi, Orange Pi)

```shell
sudo apt install gcc-aarch64-linux-gnu bc bison flex libssl-dev libncurses-dev
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-     # or LLVM=1 to use clang
make defconfig                                         # or the vendor's defconfig
make -j"$(nproc)" Image modules dtbs
make INSTALL_MOD_PATH="$PWD/rootfs" modules_install    # modules into a staging root file system
```

Outputs: `arch/arm64/boot/Image`, `arch/arm64/boot/dts/<vendor>/*.dtb`, and the `.ko` files.
How they get onto the board (boot partition, U-Boot, `boot.img` on Android) depends on the board's BSP.
Vendor BSP kernels (Rockchip SDK, Raspberry Pi tree) use their own defconfigs and sometimes their own build scripts.

## Related notes

+ [kernel_module.md](kernel_module.md), [kernel_coding_style.md](kernel_coding_style.md), [dts_intro.md](dts_intro.md)
+ [../Android/Bazel_intro.md](../Android/Bazel_intro.md): Kleaf for Android kernels

## Reference

+ [Kconfig language](https://docs.kernel.org/kbuild/kconfig-language.html)
+ [Kbuild makefiles](https://docs.kernel.org/kbuild/makefiles.html)
+ [Building external modules](https://docs.kernel.org/kbuild/modules.html)
+ [Raspberry Pi: building the kernel](https://www.raspberrypi.com/documentation/computers/linux_kernel.html)
