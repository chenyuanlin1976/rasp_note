# Platform devices in sysfs (`/sys/devices/platform`)

`/sys/devices/platform/` is the part of [sysfs](sysfs_intro.md) that holds the devices on the **platform bus**.
On an SoC such as the RK3566, almost every on-chip controller (I2C, UART, PWM, GPIO, GPU, VOP, USB, Ethernet) shows up here.
This note explains what a platform device is, what you find in its sysfs directory, and how to use it on an RK3566 running Android 14.

## 1. What a platform device is

Buses like **PCIe** and **USB** can be enumerated: the kernel asks the bus what is connected and gets IDs back.
Many components can't be discovered that way, because they sit at fixed addresses inside the SoC or on the board:

+ timers, watchdogs, interrupt and clock controllers
+ GPIO and pin controllers
+ integrated UARTs, I2C/SPI controllers, PWM controllers
+ display, GPU, NPU, USB and Ethernet controllers inside an SoC
+ on x86 PCs: legacy and ACPI-described devices (`serial8250`, `i8042`, vendor WMI/platform drivers)

The kernel puts these on a **pseudo-bus**, the **platform bus**.
Something other than the bus has to say that the device exists:

| Source | Typical system | How the device is created |
| --- | --- | --- |
| Device tree | ARM/RISC-V SoCs (RK3566, Raspberry Pi) | `of_platform_populate()` creates one for each enabled child of the root or of a `simple-bus` node |
| ACPI | x86 PCs, some ARM servers | the ACPI core creates platform devices for ACPI device objects that no other bus claims |
| Board code / drivers | older ARM boards, MFD drivers | `platform_device_register()`, or MFD drivers adding sub-devices (e.g. the RTC and regulators of a PMIC) |

A **platform driver** (`struct platform_driver`) binds to a platform device by matching `compatible` (DT), an ACPI ID, or the device name.
The DT side of this is in [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md).

## 2. Where platform devices appear in sysfs

| Path | Contents |
| --- | --- |
| `/sys/devices/platform/` | The real device directories, in the device hierarchy (parent → child) |
| `/sys/bus/platform/devices/` | A flat list of **symlinks** to every platform device, wherever it lives under `/sys/devices` |
| `/sys/bus/platform/drivers/<driver>/` | One directory per platform driver, with symlinks to the bound devices and `bind`/`unbind` files |
| `/sys/class/<class>/` | The same devices grouped by function (`pwm`, `leds`, `backlight`, `net`, ...), as symlinks |

+ **Naming**: a DT-created device is named `<unit address>.<node name>`.
  The node `pwm@fe6f0000` becomes `fe6f0000.pwm`, so the name gives you the register base address from the SoC's technical reference manual.
  A node without `reg` (for example `gpio-leds` or `pinctrl`) keeps just its node name.
+ **Nesting**: not every platform device is a direct child of `/sys/devices/platform/`.
  Children of a platform device sit inside their parent's directory.
  On Rockchip kernels, for example, the GPIO controllers are children of the `pinctrl` node, and the sub-devices of a PMIC sit under its I2C device.
  `/sys/bus/platform/devices/` lists them all, so use it to find a device, then `readlink -f` to get its real path.

## 3. Inside a platform device directory

| Entry | Meaning |
| --- | --- |
| `driver` | Symlink to the bound driver. **Missing = no driver bound** (not probed, probe failed, or deferred) |
| `of_node` | Symlink to the DT node in `/sys/firmware/devicetree/base/` (DT systems) |
| `modalias` | The string udev/`ueventd` uses to load the driver module, e.g. `of:Npwm...Crockchip,rk3568-pwm...` |
| `uevent` | The device's uevent variables; writing `add` re-sends the event |
| `driver_override` | Forces which driver may bind to this device |
| `subsystem` | Symlink to the bus (`/sys/bus/platform`) |
| `power/` | Runtime PM (`control`, `runtime_status`) and, on wakeup-capable devices, `wakeup` |
| class subdirectories | What the driver registered, e.g. `pwm/pwmchipN/`, `net/eth0/`, `leds/<name>/`, `i2c-0/` |
| driver-specific files | Extra attributes the driver adds (status, counters, tuning knobs) |

Module parameters aren't here. They live in `/sys/module/<module>/parameters/`.

## 4. Common tasks

```shell
# Inventory of platform devices
ls /sys/bus/platform/devices/

# Find where a device really lives, and which driver is bound
readlink -f /sys/bus/platform/devices/fe6f0000.pwm
readlink /sys/bus/platform/devices/fe6f0000.pwm/driver     # empty -> no driver bound

# Which DT node created it, and its compatible string
cat /sys/bus/platform/devices/fe6f0000.pwm/of_node/compatible; echo

# Devices bound to one driver
ls /sys/bus/platform/drivers/rockchip-pwm/

# Unbind and re-bind a driver (re-runs probe(); root only)
echo fe6f0000.pwm > /sys/bus/platform/drivers/rockchip-pwm/unbind
echo fe6f0000.pwm > /sys/bus/platform/drivers/rockchip-pwm/bind

# Runtime PM state ("auto" = may suspend when idle, "on" = keep powered)
cat /sys/bus/platform/devices/fe6f0000.pwm/power/control
cat /sys/bus/platform/devices/fe6f0000.pwm/power/runtime_status
```

The driver directory name (`rockchip-pwm` here) is the driver's `.name`. Read it from the `driver` symlink rather than guessing.
If `driver` is missing, follow the checklist in [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md#5-debugging-my-driver-doesnt-probe).

## 5. RK3566 example: what you find on the board

The list depends on which nodes the board `.dts` enables. Typical entries (addresses from the RK3566/RK3568 device tree) look like this:

| Entry | Block | Notes |
| --- | --- | --- |
| `fdd40000.i2c` | I2C0 (PMU domain) | Usually carries the RK809 PMIC; its RTC/regulator sub-devices sit below it |
| `fe660000.serial` | UART2 | Default debug console |
| `fdd60000.gpio`, `fe740000.gpio` … `fe770000.gpio` | GPIO0 … GPIO4 | Children of `pinctrl`; each provides `/dev/gpiochipN` |
| `fe6f0000.pwm` | PWM8 | One of the PWM channels; see §6 |
| `fe720000.saradc` | SAR ADC | Analog keys, board-ID resistors |
| `fde60000.gpu` | Mali-G52 GPU | |
| `fe040000.vop` | Video Output Processor | Display pipeline |
| `fe0a0000.hdmi` | HDMI TX | |
| `fe010000.ethernet` | GMAC1 | The only Ethernet MAC on RK3566 |
| `*.usb` | DWC3 (USB OTG/host) and EHCI/OHCI (USB 2.0 host) | |

Check the real list on your board instead of trusting this table:

```shell
adb shell ls /sys/bus/platform/devices/
adb shell ls -d /sys/bus/platform/devices/*pwm*
```

GPIO pins are not controlled through these directories.
Use the character device (`/dev/gpiochipN`) with libgpiod; the sysfs GPIO interface is deprecated (see [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md)).

## 6. Example: a PWM controller on RK3566

PWM drives LCD backlights, fans, and buzzers.
In the RK3566 device tree each PWM **channel** is its own node (`pwm@fe6f0000`, `pwm@fe6f0010`, ...),
so each one registers its own `pwmchipN` with a single channel (`npwm` = 1).

```shell
adb root                                        # userdebug/eng build
adb shell
ls /sys/devices/platform/fe6f0000.pwm/pwm/      # -> pwmchipN
```

The `N` in `pwmchipN` depends on probe order, so don't hard-code it.
Find it from the platform device, then use the standard PWM sysfs interface (times in nanoseconds):

```shell
CHIP=/sys/devices/platform/fe6f0000.pwm/pwm/$(ls /sys/devices/platform/fe6f0000.pwm/pwm/)
cat $CHIP/npwm                      # 1
echo 0 > $CHIP/export               # creates $CHIP/pwm0/
echo 1000000 > $CHIP/pwm0/period        # 1 ms = 1 kHz
echo 500000  > $CHIP/pwm0/duty_cycle    # 50 %; must not exceed period
echo 1 > $CHIP/pwm0/enable
echo 0 > $CHIP/pwm0/enable
echo 0 > $CHIP/unexport
```

+ If a kernel driver already uses the channel (for example `pwm-backlight`), `export` fails with `EBUSY`.
  Then control it through that driver's class instead, e.g. `/sys/class/backlight/<name>/brightness`.
+ Full PWM bring-up on RK3566/Android 14 (device tree mux, `ueventd.rc`, SELinux): [../../Android/HW/pwm_control.md](../../Android/HW/pwm_control.md).
  A kernel driver that owns a PWM channel: [../Kernel/pwm_consumer_driver.md](../Kernel/pwm_consumer_driver.md).
+ Bring-up checklist when a backlight stays dark: does `fe6f0000.pwm` exist (node enabled)? Is `driver` bound?
  Is the pin muxed to PWM (`/sys/kernel/debug/pinctrl/`)? Is the backlight driver bound to it?

## 7. Access on Android 14

+ **`adb shell`** runs as the `shell` user and SELinux domain. It can read many sysfs attributes, but writing needs `adb root`, which works only on userdebug/eng builds.
+ **Apps** can't access these nodes: DAC permissions and SELinux block them, and `neverallow` rules forbid granting app domains generic sysfs access.
+ **Production**: a vendor HAL or native daemon owns the node.
  Its permissions are set in `ueventd.rc`, the files get a specific SELinux type with `genfscon`, and apps reach the HAL through Binder.
  See [../Android/HAL/HAL_sysfsNodes.md](../../Android/HAL/HAL_sysfsNodes.md) and [../Android/HW/hw_control_sysfs.md](../../Android/HW/hw_control_sysfs.md).
+ Typical users of `/sys/devices/platform/` on Android are BSP engineers checking that a driver probed during bring-up,
  test scripts toggling hardware over `adb shell`, and HAL services that bridge framework requests to kernel drivers.

## Related notes

+ [sysfs_intro.md](sysfs_intro.md): the sysfs tree, attributes, and rules
+ [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md): how a DT node becomes a probed platform device
+ [sysfs_led_class.md](sysfs_led_class.md): the LED class, another sysfs interface
+ [../../Android/HW/pwm_control.md](../../Android/HW/pwm_control.md), [../Kernel/pwm_consumer_driver.md](../Kernel/pwm_consumer_driver.md): PWM on RK3566, PWM consumer driver
+ [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md): why GPIO moved from sysfs to `/dev/gpiochipN`
+ [../Power/suspend_resume_flow.md](../Power/suspend_resume_flow.md): system sleep, related to the `power/` attributes
+ [../Android/HAL/HAL_sysfsNodes.md](../../Android/HAL/HAL_sysfsNodes.md): sysfs nodes on Android (ueventd, SELinux labels)
+ [../Android/HW/hw_control_sysfs.md](../../Android/HW/hw_control_sysfs.md): hardware control through sysfs on Android

## Reference

+ [Platform devices and drivers (kernel docs)](https://docs.kernel.org/driver-api/driver-model/platform.html)
+ [Linux and the Devicetree (kernel docs)](https://docs.kernel.org/devicetree/usage-model.html)
+ [PWM: using PWMs with the sysfs interface (kernel docs)](https://docs.kernel.org/driver-api/pwm.html)
+ [Runtime power management (kernel docs)](https://docs.kernel.org/power/runtime_pm.html)
+ [sysfs: the filesystem for exporting kernel objects (kernel docs)](https://docs.kernel.org/filesystems/sysfs.html)
