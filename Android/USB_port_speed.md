# USB 2.0 or 3.0? Checking the host controller and port speed

To find out whether a device's USB host ports can run at USB 3 speeds, look at the **root hubs** the kernel registers,
not only at the controller type. The commands work in `adb shell` on Android and on any Linux system.

## 1. Host controller interfaces

| Interface | Driver (Linux) | Speeds |
| --- | --- | --- |
| **OHCI** / UHCI | `ohci_hcd` (`ohci-platform`), `uhci_hcd` | USB 1.1: 1.5 and 12 Mbit/s |
| **EHCI** | `ehci_hcd` (`ehci-platform`) | USB 2.0 High Speed, 480 Mbit/s. Paired with an OHCI ("companion") for USB 1.1 devices |
| **xHCI** | `xhci_hcd` (`xhci-plat-hcd`, `xhci_pci`) | All speeds in one controller: USB 1.1, 2.0, and, if the hardware has it, USB 3.x SuperSpeed |

+ An xHCI controller **registers two buses**: a USB 2.0 root hub (480M) and, if it has SuperSpeed ports, a USB 3.x root hub (5000M or more).
+ xHCI alone doesn't prove USB 3 ports: some xHCI controllers are USB 2.0 only and register just the 480M bus.
  The board must also wire the SuperSpeed lanes to the connector.
  On RK3566/RK3568, the USB 3 lanes share combo PHYs with SATA and PCIe, so a board's device tree can leave a port at USB 2.0.
+ On ARM SoCs the USB 3 controller is often a Synopsys **DWC3** (`dwc3` driver). It creates the `xhci-hcd.N.auto` device for host mode.
+ AHCI (`ahci-*`) is a SATA controller, not USB.

## 2. sysfs: root hubs and device speeds (no root needed)

```shell
for d in /sys/bus/usb/devices/usb*; do
    echo "$(basename "$d") speed=$(cat "$d/speed") version=$(cat "$d/version") ports=$(cat "$d/maxchild") $(cat "$d/product")"
done
cat /sys/bus/usb/devices/*/speed     # every device, in Mbit/s: 1.5, 12, 480, 5000, 10000, 20000
```

```text
usb1 speed=480 version= 2.00 ports=16 xHCI Host Controller
usb2 speed=20000 version= 3.10 ports=9 xHCI Host Controller
```

A root hub with speed 5000 or more is a SuperSpeed bus. Here one xHCI controller provides `usb1` (USB 2.0) and `usb2` (USB 3.2 Gen 2x2).
A device's own `speed` file shows the speed it actually connected at:
a USB 3 drive at 480 is on a USB 2.0 port or cable, or connected through a USB 2.0 hub.

## 3. `lsusb -t` (Linux PC or board)

```text
/:  Bus 001.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/16p, 480M
    |__ Port 011: Dev 003, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 003: Dev 005, If 0, Class=Human Interface Device, Driver=usbhid, 1.5M
    |__ Port 013: Dev 004, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 002: Dev 008, If 0, Class=Vendor Specific Class, Driver=ftdi_sio, 12M
/:  Bus 002.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/9p, 20000M/x2
```

The speed at the end of each line is the negotiated speed. This output is from a PC (usbutils 017).
Android's `lsusb` comes from toybox and has no `-t` option; use sysfs there.

## 4. debugfs: `/sys/kernel/debug/usb/devices` (root)

```shell
adb root
adb shell mount -t debugfs debugfs /sys/kernel/debug    # if it isn't mounted
adb shell cat /sys/kernel/debug/usb/devices
```

Devices launching with Android 12 or later never mount debugfs in `user` builds.
In `userdebug` builds, init mounts it during boot and unmounts it when boot completes, so mount it again by hand as above.
Output from an RK3566 board (Android, kernel 6.1), shortened:

```text
T:  Bus=01 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh= 1
D:  Ver= 2.00 Cls=09(hub  ) Sub=00 Prot=01 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0002 Rev= 6.01
S:  Product=xHCI Host Controller
S:  SerialNumber=xhci-hcd.0.auto

T:  Bus=02 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=5000 MxCh= 1
D:  Ver= 3.00 Cls=09(hub  ) Sub=00 Prot=03 MxPS= 9 #Cfgs=  1
P:  Vendor=1d6b ProdID=0003 Rev= 6.01
S:  Product=xHCI Host Controller
S:  SerialNumber=xhci-hcd.0.auto

T:  Bus=03 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh= 1
P:  Vendor=1d6b ProdID=0002 Rev= 6.01
S:  Product=EHCI Host Controller
S:  SerialNumber=fd880000.usb

T:  Bus=04 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=12   MxCh= 1
P:  Vendor=1d6b ProdID=0001 Rev= 6.01
S:  Product=Generic Platform OHCI controller
S:  SerialNumber=fd8c0000.usb
```

| Line | Meaning |
| --- | --- |
| `T:` (topology) | Bus, level, port, `Spd=` speed in Mbit/s, `MxCh=` number of ports (for hubs) |
| `D:` (device descriptor) | USB version, class (`09` = hub), `Prot=03` on a USB 3 hub |
| `P:` (product) | Vendor/product ID. Root hubs use `1d6b` (Linux Foundation): `0001` = 1.1, `0002` = 2.0, `0003` = 3.x root hub |
| `S:` (strings) | Controller name, and its platform device (`fd880000.usb` = the register address in the device tree) |
| `C:`, `I:`, `E:` | Configuration, interfaces (with the bound `Driver=`), endpoints |

Here, buses 1 and 2 are the two root hubs of the DWC3's xHCI (one USB 3.0 port, 5000M).
Buses 3–6 are EHCI/OHCI pairs for the USB 2.0-only host ports.

## 5. Controller drivers

```shell
adb shell ls /sys/bus/platform/drivers/ | grep -E 'hci|dwc'
```

```text
dwc3
ehci-platform
ohci-platform
xhci-hcd
```

A driver directory only shows that the driver is built in or loaded. The device links inside it (`ls /sys/bus/platform/drivers/xhci-hcd/`) show the controllers it is bound to.

## Related notes

+ [../USB_OTG.md](../USB_OTG.md): host, device, and dual-role ports
+ [../USB_CDC.md](../USB_CDC.md): USB serial (CDC-ACM)
+ [../Linux/sysfs_intro.md](../Linux/sysfs_intro.md), [adb_intro.md](adb_intro.md)

## Reference

+ [The Linux-USB host side API, incl. the `usb/devices` format (kernel docs)](https://docs.kernel.org/driver-api/usb/usb.html)
+ [Use DebugFS in Android 12 (AOSP)](https://source.android.com/docs/core/architecture/kernel/using-debugfs-12)
+ [xHCI specification (Intel)](https://www.intel.com/content/www/us/en/products/docs/io/universal-serial-bus/extensible-host-controler-interface-usb-xhci.html)
+ `man 8 lsusb`
