# Porting an existing driver to a board (RTC and Wi-Fi examples)

For a well-known chip, "porting the driver" rarely means writing one.
The kernel (mainline or the vendor BSP) usually has the driver already; the work is to **connect it to your board**:
enable it in the kernel config, describe the chip in the device tree (bus, address, interrupt, reset/enable GPIOs, supplies),
and install any firmware it needs.

How a device-tree node becomes a probed driver is in [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md).
A full RK3566 walkthrough for an I2C RTC (schematic, pinctrl, IO domains, build, checks) is in
[../DeviceTree/dts_board_checklist.md](../DeviceTree/dts_board_checklist.md).

## 1. Existing drivers for common chips

| Class | Subsystem | Where | Examples |
| --- | --- | --- | --- |
| RTC | RTC class: `/dev/rtcN`, `/sys/class/rtc/`, `hwclock`, wake alarms | `drivers/rtc/` | `rtc-pcf8563` (PCF8563), `rtc-ds1307` (DS1307, DS1337, DS3231, ...), `rtc-rx8025`, `rtc-pcf2123` (SPI) |
| Wi-Fi | `cfg80211` (+ `mac80211` for soft-MAC chips) | `drivers/net/wireless/` | Realtek `rtw88`, `rtw89`, `rtl8xxxu`; MediaTek `mt76`; Broadcom/Cypress/Infineon `brcmfmac`; Qualcomm Atheros `ath9k`, `ath10k`, `ath11k`; Marvell/NXP `mwifiex` |

+ One driver often covers a whole family (`rtc-ds1307` handles about a dozen chips), so search by family, not only by part number.
+ Most Wi-Fi chips also need **firmware** in `/lib/firmware/` (on Android, usually `/vendor/firmware/` or a vendor path), and some need board-specific
  calibration or NVRAM files (for example `brcmfmac` loads a `.txt` NVRAM file next to the `.bin`).
+ Newer or niche Wi-Fi silicon may only have an out-of-tree vendor driver. Expect more work there (kernel version mismatches, missing DT bindings).

## 2. Workflow

1. **Read the schematic**: which bus (RTCs: I2C or SPI; Wi-Fi: SDIO, PCIe, or USB), the address or chip select,
   and the interrupt, reset, enable, and supply lines.
2. **Find and enable the driver**: search `drivers/rtc/` or `drivers/net/wireless/` and their `Kconfig` files.
   Enable it as built-in (`y`) or module (`m`), together with the bus controller driver (I2C, SPI, SDIO/MMC)
   and the subsystem (`CONFIG_RTC_CLASS`, `CONFIG_CFG80211`). See [kernel_build.md](kernel_build.md).
3. **Describe the hardware in the device tree**: add a child node under the right bus controller with the
   `compatible` string from the binding, `reg`, interrupts, GPIOs, and supplies, and set `status = "okay"` on the controller.
   The binding (`Documentation/devicetree/bindings/rtc/`, `.../net/wireless/`) lists the required properties.
4. **Install firmware and userspace tools**: firmware files for Wi-Fi; `hwclock` (util-linux) for RTCs;
   `iw`, `wpa_supplicant`, or NetworkManager for Wi-Fi.
5. **Verify at runtime**: probe messages in `dmesg`, then the device node or interface (sections 3.3 and 4).

USB and PCIe Wi-Fi devices are enumerated by their bus, so they usually need no device-tree node, only power and reset.
SDIO devices sit on a non-removable MMC bus and normally need a power sequence (section 4).

## 3. Example: adding an RTC

### 3.1 Device-tree node (I2C)

A PCF8563 at address `0x51`, placed under an I2C controller that the board enables:

```dts
#include <dt-bindings/interrupt-controller/irq.h>

&i2c1 {
    status = "okay";

    ext_rtc: rtc@51 {
        compatible = "nxp,pcf8563";
        reg = <0x51>;                                    /* 7-bit I2C address = unit address */
        /* optional, only if the INT pin is wired (alarms, wakeup):
        interrupt-parent = <&gpio0>;
        interrupts = <5 IRQ_TYPE_LEVEL_LOW>;
        */
    };
};
```

Kernel config: `CONFIG_RTC_CLASS=y`, `CONFIG_RTC_DRV_PCF8563=y` (or `m`), plus the I2C controller driver.

### 3.2 Device-tree node (SPI)

A PCF2123 on chip select 0. For SPI devices, `reg` is the chip-select number and `spi-max-frequency` is required:

```dts
&spi1 {
    status = "okay";

    rtc@0 {
        compatible = "nxp,pcf2123";
        reg = <0>;                                       /* chip select 0 */
        spi-max-frequency = <1000000>;                   /* 1 MHz, within the chip's limit */
        spi-cs-high;                                     /* the PCF2123 chip enable is active high */
    };
};
```

Kernel config: `CONFIG_RTC_DRV_PCF2123`, plus the SPI controller driver.
Chip-select polarity and SPI mode differ between chips, so take them from the binding and datasheet.

### 3.3 Choosing the primary RTC

Many SoCs (and PMICs such as the RK809 on RK3566 boards) have their own RTC, so the external chip may become `rtc1`.

+ On recent kernels the RTC core honors an alias: `aliases { rtc0 = &ext_rtc; };` (the node needs the `ext_rtc:` label).
  Check that your kernel's `drivers/rtc/class.c` uses `of_alias_get_id(..., "rtc")` before relying on it.
+ `CONFIG_RTC_HCTOSYS=y` sets the system time from `CONFIG_RTC_HCTOSYS_DEVICE` (default `rtc0`) at boot.
+ Alternatively, disable the unused RTC node (`status = "disabled"`).

### 3.4 Build, boot, and test

Rebuild the kernel and the DTB, then check that the node made it into the blob:

```shell
dtc -I dtb -O dts my-board.dtb | grep -A3 "rtc@"     # node, compatible and reg present?
```

On the board:

```shell
dmesg | grep -iE "rtc|i2c|spi"                     # probe messages, transfer errors
ls -l /dev/rtc*
cat /sys/class/rtc/rtc0/name                       # driver name: is rtc0 the chip you expect?
cat /sys/class/rtc/rtc0/date /sys/class/rtc/rtc0/time

sudo hwclock -r -f /dev/rtc0                       # read the RTC
sudo date -s "2026-11-21 09:00:00"                 # set the system time (or let NTP set it)
sudo hwclock -w -f /dev/rtc0                       # write the system time to the RTC
```

Then the power test: with a backup battery or supercap installed, remove main power for a while, boot again, and read the RTC.
The time should have kept running, with no "low voltage" / "time is not reliable" message in `dmesg`.
If the INT pin is wired, `rtcwake -d rtc0 -m mem -s 20` tests the alarm as a wakeup source
(see [../Power/wakeup_count.md](../Power/wakeup_count.md)).

## 4. Wi-Fi specifics

+ **SDIO chips** need their power-on sequence (enable GPIO, 32 kHz clock, delays) described with `mmc-pwrseq-simple`,
  see [../DeviceTree/dts_node_mmc_pwrseq.md](../DeviceTree/dts_node_mmc_pwrseq.md).
+ **Firmware**: `dmesg | grep -i firmware` shows the exact file names the driver requested; missing files are the most common failure.
+ **Verify**: the interface appears (`ip link`, `iw dev`), then a scan returns networks (`iw dev wlan0 scan`).
  Commands are in [../Network/wifi_cmds.md](../Network/wifi_cmds.md).

## 5. When you do write or patch driver code

+ **No driver exists** for the chip. Build on the subsystem instead of inventing an interface:
  an RTC driver implements `struct rtc_class_ops` and registers with `devm_rtc_allocate_device()` + `devm_rtc_register_device()`
  (older drivers use the deprecated `devm_rtc_device_register()`); a soft-MAC Wi-Fi driver implements `ieee80211_ops` for `mac80211`.
  Often the quickest start is an existing driver for a similar chip.
+ **A driver exists but the board has quirks**: an unusual power-on or reset sequence, a missing `compatible` entry
  for a pin-compatible variant, or a clock the driver doesn't request.

## 6. Troubleshooting

Work from the bottom up, so you don't chase the wrong layer:

| Layer | Check | Good result |
| --- | --- | --- |
| Kernel config | Driver, bus controller, and subsystem enabled (`zcat /proc/config.gz \| grep RTC_DRV`, if `CONFIG_IKCONFIG_PROC` is set) | Options are `y` or `m`, and the module is loaded (`lsmod`) |
| Device tree | Node in the live tree (`/proc/device-tree/...`), controller `status = "okay"` | Device appears under `/sys/bus/i2c/devices/` or `/sys/bus/spi/devices/` |
| Probe | `dmesg` around the driver name | Driver bound; no `-ENODEV`/`-EIO`; no endless probe deferral (`/sys/kernel/debug/devices_deferred`) |
| Hardware | Supply voltages, reset/enable GPIO levels, IRQ line, bus speed, against the datasheet | Rails present and lines at their active levels during probe |
| Userspace | Firmware files present, tools installed | `hwclock -r` returns a valid time, or `iw dev wlan0 scan` lists networks |

More probe debugging is in [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md#5-debugging-my-driver-doesnt-probe),
and a symptom table in [../DeviceTree/dts_board_checklist.md](../DeviceTree/dts_board_checklist.md#5-common-mistakes).

## Related notes

+ [kernel_build.md](kernel_build.md), [kernel_module.md](kernel_module.md)
+ [../DeviceTree/dts_board_checklist.md](../DeviceTree/dts_board_checklist.md): RK3566 I2C RTC walkthrough
+ [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md), [../DeviceTree/dts_provider_consumer.md](../DeviceTree/dts_provider_consumer.md)
+ [../DeviceTree/dts_node_mmc_pwrseq.md](../DeviceTree/dts_node_mmc_pwrseq.md), [../DeviceTree/dts_node_regulator_fixed.md](../DeviceTree/dts_node_regulator_fixed.md)
+ [../Network/wifi_cmds.md](../Network/wifi_cmds.md), [../Power/wakeup_count.md](../Power/wakeup_count.md)
+ [../../Android/AOSP_cfg/time_detection.md](../../Android/AOSP_cfg/time_detection.md): how Android uses the RTC time

## Reference

+ [Real Time Clock (RTC) drivers for Linux (kernel docs)](https://docs.kernel.org/admin-guide/rtc.html)
+ [RTC device-tree bindings](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/rtc)
+ [Linux wireless documentation](https://wireless.docs.kernel.org/)
+ [Linux and the Devicetree (kernel docs)](https://docs.kernel.org/devicetree/usage-model.html)
