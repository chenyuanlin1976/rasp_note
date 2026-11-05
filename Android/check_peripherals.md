# Checking board peripherals over adb (Android)

This note is a checklist for bring-up and factory tests on an Android board.
It checks the common on-board peripherals with `adb` from a host PC: Bluetooth, Wi-Fi, Ethernet, USB, USB-C Power Delivery, battery, and RTC.
For each peripheral, it checks 3 layers, from the bottom up:

1. **Kernel**: the driver probed, and the device shows up in sysfs (`/sys/class/...`) or `/dev`.
2. **Framework**: the system service is registered and reports the expected state (`service check`, `dumpsys`, `cmd`).
3. **Function**: the peripheral really works (scan, connect, ping, read/write, survive a reboot).

| Peripheral | Framework service | Kernel side | Quick check |
| --- | --- | --- | --- |
| Bluetooth | `bluetooth_manager` | `hci0` (only visible to the Bluetooth stack on Android) | `dumpsys bluetooth_manager` |
| Wi-Fi | `wifi` | `/sys/class/net/wlan0` | `cmd wifi status` |
| Ethernet | `ethernet`, `connectivity` | `/sys/class/net/eth0` | `cat /sys/class/net/eth0/carrier` |
| USB host | `usb` | `/sys/bus/usb/devices` | `lsusb` |
| USB device (gadget) | `usb` | `/sys/class/udc` | `svc usb getFunctions` |
| USB-C / PD | `usb` (port status) | `/sys/class/typec`, `/sys/class/power_supply/tcpm-*` | `cat /sys/class/typec/port0/power_operation_mode` |
| Battery / charger | `battery` (health HAL) | `/sys/class/power_supply` | `dumpsys battery` |
| RTC | `alarm` (sets the clock) | `/sys/class/rtc/rtc0`, `/dev/rtc0` | `cat /sys/class/rtc/rtc0/time` |

## 1. Before you start

```shell
adb devices -l                            # board connected and authorized
adb shell getprop ro.build.type           # user / userdebug / eng
adb root                                  # userdebug/eng only; needed for dmesg, /dev/rtc0, debugfs
adb shell service list                    # every registered Binder service
adb shell service check wifi              # "Service wifi: found" / "not found"
adb shell dmesg | grep -iE 'error|fail'   # driver probe errors (root on most builds)
```

+ Commands are written as `adb shell <cmd>`. Inside an interactive `adb shell`, drop the prefix.
+ Pipes after `adb shell ...` run on the **host**. To run the whole pipeline on the device, quote it: `adb shell 'cmd | grep x'`.
+ On a `user` build, SELinux may deny the `shell` user some sysfs and `/dev` files ("Permission denied").
  Use a `userdebug` build and `adb root` for bring-up.
+ The `cmd` and `dumpsys` output formats aren't stable between Android releases. `adb shell cmd <service> help` lists what your release supports.

More about the tools themselves: [adb_intro.md](adb_intro.md), [adb_shell_cmds.md](adb_shell_cmds.md).

## 2. Bluetooth

The Bluetooth service is registered as **`bluetooth_manager`**, not `bluetooth`.

```shell
adb shell service check bluetooth_manager           # registered?
adb shell settings get global bluetooth_on          # 1 = on (the saved user setting)
adb shell 'dumpsys bluetooth_manager | grep -E "enabled:|state:|address:|name:"'
```

```text
  enabled: true
  state: ON
  address: XX:XX:XX:XX:XX:XX
  name: rk3566_box
```

Toggle it:

```shell
adb shell svc bluetooth enable                      # or: disable
adb shell cmd bluetooth_manager enable              # Android 13+; also: disable, wait-for-state:STATE_ON
```

+ `state: ON` with a valid address means the controller firmware loaded and the HCI transport (UART, USB, or SDIO) works.
  A state that goes `TURNING_ON` → `OFF` usually means a firmware, UART, or Bluetooth HAL problem: check `adb logcat | grep -iE 'bt|bluetooth'`.
+ The Bluetooth HAL must be running: `adb shell service list | grep -i bluetooth` (AIDL) or `adb shell lshal | grep -i bluetooth` (HIDL).
+ Functional test: pair a phone or a BLE device from Settings, or scan with an app such as nRF Connect.
  There is no stable adb command to start a scan.

## 3. Wi-Fi

```shell
adb shell service check wifi
adb shell settings get global wifi_on               # 1 = on
adb shell cmd wifi status                           # enabled?, connected SSID, RSSI, link speed (Android 11+)
adb shell dumpsys wifi                              # full state; very long
adb shell ip addr show wlan0                        # interface up, IP address
```

Toggle, scan, and connect (Android 11+ for the `cmd wifi` subcommands):

```shell
adb shell svc wifi enable                           # or: disable
adb shell cmd wifi set-wifi-enabled enabled         # or: disabled
adb shell cmd wifi start-scan
adb shell cmd wifi list-scan-results                # BSSID, frequency, RSSI, SSID
adb shell cmd wifi connect-network MySSID wpa2 MyPassword   # open | owe | wpa2 | wpa3
adb shell ping -c 4 -I wlan0 8.8.8.8
```

+ Scan results with sensible RSSI on both 2.4 GHz (`frequency` 24xx) and 5 GHz (5xxx) confirm the radio and the antennas.
+ No `wlan0` at all: the driver or firmware didn't load (`dmesg`, and `lsmod` if the driver is a module).
+ Wi-Fi on by default after a factory reset: [wifi_default.md](wifi_default.md).

## 4. Ethernet

Linux reports the link state in sysfs. Android's `ethernet` service tracks the interface and brings it up with DHCP or a static IP.

```shell
adb shell ls /sys/class/net                         # eth0, wlan0, lo, ...
adb shell cat /sys/class/net/eth0/operstate         # up / down
adb shell cat /sys/class/net/eth0/carrier           # 1 = cable plugged in and link up
adb shell cat /sys/class/net/eth0/speed             # 10 / 100 / 1000 (Mbit/s); -1 or an error without a link
adb shell cat /sys/class/net/eth0/duplex            # full / half
adb shell cat /sys/class/net/eth0/address           # MAC address
adb shell ip addr show eth0                         # IP address from DHCP
adb shell ping -c 4 -I eth0 8.8.8.8
```

```shell
adb shell dumpsys ethernet                          # tracked interfaces, IP configuration
adb shell 'dumpsys connectivity | grep -i ethernet' # is Ethernet a validated network?
adb shell ip link set eth0 down                     # root: simulate a cable pull; "up" to restore
```

+ `carrier` = 1 but `speed` = 100 on a gigabit port: check the cable, the PHY strapping, and the RGMII delay settings in the device tree.
+ A random MAC after every boot means the MAC isn't programmed (eFuse, EEPROM, or vendor storage) and the driver made one up.
+ Linux network tools in general: [../network_cmds.md](../network_cmds.md).

## 5. USB

### 5.1 Host ports

```shell
adb shell lsusb                                     # toybox: bus, device, vendor:product ID
adb shell 'for d in /sys/bus/usb/devices/*; do [ -f $d/product ] && echo "$(basename $d) $(cat $d/speed)M $(cat $d/product)"; done'
adb shell sm list-volumes all                       # USB drives mounted by vold
adb shell ls /storage                               # e.g. /storage/1234-ABCD for a USB drive
adb shell getevent -i | grep name                   # USB keyboards, mice, barcode scanners
```

Plug a device into each port in turn and check that a new entry appears.
The `speed` column shows whether a USB 3 drive really connected at 5000M; details in [USB_port_speed.md](USB_port_speed.md).

### 5.2 Device (gadget) port

The port that adb runs on is in device role. Its functions are set by the `usb` service:

```shell
adb shell svc usb getFunctions                      # e.g. adb, mtp,adb
adb shell getprop sys.usb.state                     # the functions that are active now
adb shell cat /sys/class/udc/*/state                # configured = enumerated by the host
adb shell dumpsys usb                               # current functions, port status, connected accessories
```

Switching an OTG port between host and device role: [../USB_OTG.md](../USB_OTG.md).

## 6. USB-C and Power Delivery (PD)

A USB-C port with a PD controller (for example FUSB302 or HUSB311 on RK3566 boards) registers with the kernel **Type-C class** and the **TCPM** driver.
TCPM negotiates the voltage and current, and reports the result as a power supply.

```shell
adb shell ls /sys/class/typec                       # port0, port0-partner (something is plugged in)
adb shell cat /sys/class/typec/port0/data_role      # [host] device
adb shell cat /sys/class/typec/port0/power_role     # [source] sink
adb shell cat /sys/class/typec/port0/power_operation_mode   # default | 1.5A | 3.0A | usb_power_delivery
adb shell cat /sys/class/typec/port0/usb_power_delivery_revision
```

The negotiated contract (TCPM power supply, values in µV and µA):

```shell
adb shell 'for f in online voltage_now current_max usb_type; do echo "$f: $(cat /sys/class/power_supply/tcpm-source-psy-*/$f)"; done'
```

```text
online: 1
voltage_now: 9000000
current_max: 2000000
usb_type: C [PD] PD_PPS
```

This example shows a 9 V / 2 A PD contract.
`power_operation_mode` = `default` with a PD charger means PD negotiation failed and the port fell back to 5 V USB power.

```shell
adb shell dumpsys usb | grep -iA5 port              # Android's view: power role, data role, supported modes
adb shell ls /sys/kernel/debug/usb/                 # root + debugfs: tcpm-<dev> holds the TCPM state machine log
adb shell 'cat /sys/kernel/debug/usb/tcpm-*'
adb shell dmesg | grep -iE 'tcpm|fusb302|husb311'
```

+ Kernels 6.0+ also export the PD capabilities (source and sink PDOs) under `/sys/class/usb_power_delivery/`, if the driver registers them.
+ Test with chargers that offer 5, 9, 12, and 15 V, and with a PD-capable USB-C power meter between charger and board.
+ CC-pin roles, DRP, and `DR_Swap`/`PR_Swap`: [../USB_OTG.md](../USB_OTG.md#22-usb-c-the-cc-pins).

## 7. Battery and charger

The `battery` service gets its values from the **health HAL**, which reads the kernel's power supply class.

```shell
adb shell dumpsys battery
```

```text
Current Battery Service state:
  AC powered: false
  USB powered: true
  Wireless powered: false
  status: 2
  health: 2
  present: true
  level: 76
  scale: 100
  voltage: 4012
  temperature: 285
  technology: Li-ion
```

| Field | Meaning |
| --- | --- |
| `status` | 1 unknown, 2 charging, 3 discharging, 4 not charging, 5 full |
| `health` | 1 unknown, 2 good, 3 overheat, 4 dead, 5 over voltage, 6 failure, 7 cold |
| `voltage` | mV |
| `temperature` | Tenths of a degree Celsius (285 = 28.5 °C) |

Raw kernel values (power supply names depend on the charger and fuel-gauge drivers):

```shell
adb shell 'for p in /sys/class/power_supply/*; do echo "$(basename $p): type=$(cat $p/type) online=$(cat $p/online 2>/dev/null)"; done'
adb shell cat /sys/class/power_supply/battery/capacity      # %
adb shell cat /sys/class/power_supply/battery/voltage_now   # µV
adb shell cat /sys/class/power_supply/battery/current_now   # µA; the sign convention depends on the driver
adb shell cat /sys/class/power_supply/battery/temp          # tenths of °C
```

+ Plug and unplug the charger and check that `status`, `AC powered`/`USB powered`, and `current_now` follow.
+ Development boards without a battery often report fixed values from the BSP (for example `level: 100`, `AC powered: true`). Check `present`.
+ `dumpsys battery set ...` only **fakes** the reported values for testing. Run `dumpsys battery reset` afterwards
  (see [adb_shell_cmds.md](adb_shell_cmds.md#5-dumpsys)).

## 8. RTC

The RTC keeps the time while the board is off. It holds **UTC**.
At boot, the kernel copies the RTC into the system clock (`CONFIG_RTC_HCTOSYS`, usually from `rtc0`).
When the time is set (by NTP or by the user), `AlarmManagerService` writes it back to the RTC whose `hctosys` attribute is 1.

```shell
adb shell ls /sys/class/rtc                         # rtc0, rtc1, ...
adb shell 'cd /sys/class/rtc/rtc0 && echo "$(cat name) hctosys=$(cat hctosys)"'   # e.g. rk808-rtc / hym8563, hctosys=1
adb shell 'cat /sys/class/rtc/rtc0/date /sys/class/rtc/rtc0/time; date -u'       # RTC vs system time, both UTC
adb shell hwclock -r                                # root; toybox hwclock reads /dev/rtc0
adb shell cat /proc/driver/rtc                      # if CONFIG_RTC_INTF_PROC; includes alarm and battery status
```

Test that the RTC keeps time across a power cycle:

```shell
adb shell settings put global auto_time 0           # stop NTP from correcting the clock
adb shell cmd alarm set-time 1767225600000          # ms since the epoch (2026-01-01 00:00:00 UTC); writes the RTC too
adb shell 'cat /sys/class/rtc/rtc0/date /sys/class/rtc/rtc0/time'
# power off, wait a few minutes with the RTC backup battery in place, power on with the network disconnected
adb shell 'cat /sys/class/rtc/rtc0/date /sys/class/rtc/rtc0/time; date -u'
adb shell settings put global auto_time 1
```

+ The time jumps back to a fixed date (often 2000, 1970, or the build date) after a power cycle: the RTC lost power (backup battery or supercap), or it isn't the `hctosys` RTC.
+ RTC wake-up alarm (root): `echo +60 > /sys/class/rtc/rtc0/wakealarm` sets an alarm 60 s ahead. `cat wakealarm` shows it, and `echo 0 > wakealarm` clears it.
+ How Android chooses between NTP, NITZ, and the RTC: [time_detection.md](time_detection.md).

## 9. One-shot summary script (host side)

A first pass over all peripherals, for example in a factory test. Each line needs the hardware to be connected (cable, charger, USB drive).

```shell
#!/bin/bash
# check_board.sh: print a short peripheral summary of the connected Android board
s() { adb shell "$@" 2>/dev/null | tr -d '\r'; }

echo "== build:     $(s getprop ro.build.fingerprint)"
echo "== bluetooth: $(s 'dumpsys bluetooth_manager | grep -m1 "state:"')"
echo "== wifi:      $(s 'cmd wifi status | head -1')"
echo "== network:"
s 'for n in /sys/class/net/*; do echo "   $(basename $n) $(cat $n/operstate) $(cat $n/address)"; done'
echo "== usb devices:"
s 'for d in /sys/bus/usb/devices/*; do [ -f $d/product ] && echo "   $(basename $d) $(cat $d/speed)M $(cat $d/product)"; done'
echo "== usb gadget: $(s svc usb getFunctions)"
echo "== type-c:    $(s cat /sys/class/typec/port0/power_operation_mode)"
echo "== battery:"
s 'dumpsys battery | grep -E "powered|status|level|voltage|temperature"'
echo "== rtc:       $(s 'cat /sys/class/rtc/rtc0/date /sys/class/rtc/rtc0/time | tr "\n" " "') (system UTC: $(s date -u))"
```

## Related notes

+ [adb_intro.md](adb_intro.md), [adb_shell_cmds.md](adb_shell_cmds.md), [logcat_intro.md](logcat_intro.md)
+ [wifi_default.md](wifi_default.md), [time_detection.md](time_detection.md), [SettingsProvider_intro.md](SettingsProvider_intro.md)
+ [USB_port_speed.md](USB_port_speed.md), [../USB_OTG.md](../USB_OTG.md), [../USB_CDC.md](../USB_CDC.md)
+ [../network_cmds.md](../network_cmds.md), [../BLE_intro.md](../BLE_intro.md), [../Linux/sysfs_intro.md](../Linux/sysfs_intro.md)

## Reference

+ [Android Debug Bridge (adb)](https://developer.android.com/tools/adb)
+ [dumpsys](https://developer.android.com/tools/dumpsys)
+ [Health HAL (AOSP)](https://source.android.com/docs/core/perf/health)
+ [Linux power supply class (kernel docs)](https://docs.kernel.org/power/power_supply_class.html)
+ [USB Type-C connector class (kernel docs)](https://docs.kernel.org/driver-api/usb/typec.html)
+ [Real Time Clock (RTC) drivers for Linux (kernel docs)](https://docs.kernel.org/admin-guide/rtc.html)
+ [sysfs ABI, including `sysfs-class-net` and `sysfs-class-typec` (kernel docs)](https://docs.kernel.org/admin-guide/abi-testing.html)
