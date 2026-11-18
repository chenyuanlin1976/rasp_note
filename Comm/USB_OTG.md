# USB OTG and dual-role ports

A USB link always has one **host** (it powers the bus, enumerates, and schedules every transfer) and one **device** (peripheral).
A **dual-role** port can be either, and **USB OTG (On-The-Go)** is the USB 2.0 supplement that defined it for Micro-USB and Mini-USB.
MCUs (STM32 `OTG_FS`/`OTG_HS`), phones, and SoCs (RK3566's DWC3 port) all have such ports.

| Term | Meaning |
| --- | --- |
| Host-only / device-only controller | Fixed role (EHCI/OHCI/xHCI host ports, or a device-only controller) |
| **OTG / DRD** (dual-role device) | One controller and connector, either role. The role is chosen when something is plugged in, or by software |
| HNP, SRP, ADP (OTG protocols) | Host Negotiation (swap roles without re-plugging), Session Request, Attach Detection. Rarely implemented; in practice "OTG" usually just means dual-role with ID-pin detection |
| USB-C: **DFP / UFP / DRP** | Downstream-facing port (host side), upstream-facing port (device side), dual-role port |

## 1. Use cases on embedded devices

| Device role (to a PC) | Host role (to a peripheral) |
| --- | --- |
| Firmware update through DFU, a CDC-ACM bootloader, or mass storage | Firmware update from a USB flash drive (MSC host reads `firmware.bin`) |
| Configuration and live diagnostics over a virtual COM port ([USB_CDC.md](USB_CDC.md)) | Exporting logged data to a flash drive |
| Factory provisioning: a test fixture writes keys, MAC addresses, calibration data | Keyboards, barcode scanners (HID), printers, cameras, USB-serial adapters |
| The product acts as a HID (macro pad, controller, instrument) | |

One dual-role connector also saves board space: the same port carries adb during development and takes a flash drive in the field.

In host role, the board must **supply 5 V on VBUS** (up to 500 mA for USB 2.0), usually through a switched regulator.

## 2. How the role is chosen

### 2.1 Micro-USB / Mini-USB: the ID pin

The 5-pin connectors add an **ID pin** (pin 4: VBUS, D−, D+, **ID**, GND):

| Plug inserted | ID pin | Role of this port |
| --- | --- | --- |
| Micro-**A** plug (the phone end of an OTG adapter) | Grounded | **Host** (A-device): turns on VBUS and enumerates |
| Micro-**B** plug (a normal cable to a PC or charger) | Floating | **Device** (B-device): waits for VBUS from the other side |

The controller (or a GPIO / extcon driver on Linux) reads the ID pin and VBUS and switches roles.

### 2.2 USB-C: the CC pins

USB-C has no ID pin. The roles come from the **CC (Configuration Channel)** pins:

+ A host (source, DFP) pulls CC up with **Rp**; a device (sink, UFP) pulls it down with **Rd**.
  A dual-role port (DRP) alternates between Rp and Rd until it sees the opposite on the other side.
  This also tells which way the plug is inserted.
+ After that, the two ports can swap roles with **USB Power Delivery** messages over CC: `DR_Swap` (data role) and `PR_Swap` (power role).
  The data role and the power role are separate: a laptop can be the USB host while it charges from a monitor.
+ Without a PD controller, the role is fixed by the resistors when the cable is plugged in.

## 3. Switching roles in software

### 3.1 MCU (STM32)

The firmware chooses the role. An STM32 OTG controller can force its mode in the `OTG_GUSBCFG` register (`FHMOD` = force host, `FDMOD` = force device),
or follow the ID pin. The application then starts the matching stack: the device side (`PCD` in the STM32 HAL) or the host side (`HCD`).
The STM32Cube USB Device/Host libraries and TinyUSB provide the class drivers (CDC, MSC, HID, DFU, ...).

### 3.2 Linux (DWC3, ChipIdea, MUSB, ...)

The device tree sets which roles the hardware may take:

```dts
&usb_host0_xhci {               /* RK356x DWC3 port; the Rockchip BSP names this node usbdrd_dwc3 */
	dr_mode = "otg";            /* "host", "peripheral", or "otg" */
	usb-role-switch;            /* the role comes from a role-switch provider (Type-C chip, sysfs) */
	status = "okay";
};
```

```shell
# USB role switch class (when the controller registers a role switch)
cat /sys/class/usb_role/*/role              # none | host | device
echo device | sudo tee /sys/class/usb_role/<switch>/role

# USB-C port with a Type-C / PD controller
cat /sys/class/typec/port0/data_role        # [host] device
echo device | sudo tee /sys/class/typec/port0/data_role    # sends DR_Swap; the partner must accept

# DWC3 debug interface (debugfs, dr_mode = "otg")
echo host | sudo tee /sys/kernel/debug/usb/<dwc3-device>/mode   # host | device | otg (e.g. fcc00000.usb)

# Rockchip BSP kernels (RK3566/RK3568, 4.19/5.10): mode attribute of the USB 2 PHY (section 3.3)
echo host | sudo tee /sys/devices/platform/fe8a0000.usb2-phy/otg_mode   # host | peripheral | otg
```

Which of these exist depends on the controller driver, the kernel version, and the device tree; `find /sys -name otg_mode -o -name role` helps.
In host role, the VBUS regulator (`vbus-supply` / `phy-supply` in the device tree) must turn on as well.

### 3.3 RK3566 with the Rockchip BSP kernel

The RK3566 dual-role port is the DWC3 controller (`fcc00000.usb`) together with the OTG port of USB 2 PHY 0 (`fe8a0000.usb2-phy`).
The device tree property `dr_mode` sets the role at boot. The PHY's `otg_mode` sysfs attribute, which exists only in Rockchip BSP kernels (not mainline), changes it at run time.
Both take the same three values:

| Mode | Role | What works on this port |
| --- | --- | --- |
| `otg` | Follows ID-pin / VBUS detection (or a Type-C controller) | Device role with a cable to a PC, host role with an OTG adapter |
| `host` | Host only | VBUS on; flash drives, keyboards, Wi-Fi dongles. No adb, MTP, or fastbootd over this port |
| `peripheral` | Device only | adb, MTP, fastbootd, other gadget functions. No VBUS output, so no peripherals |

`dr_mode` accepts only `"host"`, `"peripheral"`, and `"otg"` (`usb-drd.yaml`). Strings such as `"device"`, `"auto"`, or `"drd"` aren't valid.
Maskrom flashing runs from the boot ROM, so it works no matter which mode the kernel device tree sets.

**Device tree (permanent).** The node names below are the ones in the Rockchip BSP `rk3568.dtsi` and EVB board files. Check them against your SDK:

```dts
&usbdrd30 {                         /* DWC3 glue/wrapper node */
	status = "okay";
};

&usbdrd_dwc3 {
	dr_mode = "otg";                /* "host", "peripheral", or "otg" */
	extcon = <&usb2phy0>;           /* role from the PHY's ID/VBUS detection */
	status = "okay";
};

&u2phy0_otg {
	vbus-supply = <&vcc5v0_otg>;    /* GPIO-switched 5 V, turned on in host role */
	status = "okay";
};
```

Rebuild the kernel with the SDK build script (option names differ between SDK releases).
Then flash the image that carries the DTB, usually `boot.img`.

**Run time (lost at reboot).** These commands need root: `adb root` on a userdebug build, or the serial console:

```shell
P=/sys/devices/platform/fe8a0000.usb2-phy/otg_mode   # find /sys/devices/platform -name otg_mode
cat $P                  # current mode
echo host > $P          # host role: VBUS on; adb over this port disconnects
echo peripheral > $P    # device role
echo otg > $P           # back to automatic detection
cat $P                  # verify
```

If adb runs over the same port, switch to host from the serial console or from adb over TCP. Otherwise the `echo host` cuts your own session.
To apply a mode at every boot without rebuilding the kernel, an init `.rc` file in the vendor image can write it:

```text
on boot
    write /sys/devices/platform/fe8a0000.usb2-phy/otg_mode host
```

Changing `dr_mode` in the device tree is the cleaner fix for a product. Use the `.rc` write for a quick override.

### 3.4 Android

+ Device role is the default: adb, MTP, and USB tethering are gadget functions ([USB_CDC.md](USB_CDC.md#5-linux-or-android-as-the-usb-device-gadget)).
+ With a USB-C port and a PD controller: **Settings → Connected devices → USB → "USB controlled by"**: "Connected device" or "This device" swaps the data role.
+ On development boards, the BSP often offers a property or a Settings toggle that writes the kernel attribute in section 3.3.
  A development board with only one OTG port can't do adb over USB while it acts as a host; use adb over TCP ([../Android/Debug/adb_intro.md](../Android/Debug/adb_intro.md)).

## Related notes

+ [USB_CDC.md](USB_CDC.md): CDC-ACM serial ports, gadget setup
+ [../Android/Debug/USB_port_speed.md](../Android/Debug/USB_port_speed.md): USB 2.0 vs 3.0 host controllers
+ [../Linux/DeviceTree/dts_node_regulator_fixed.md](../Linux/DeviceTree/dts_node_regulator_fixed.md): a GPIO-switched 5 V VBUS regulator
+ [../Android/HW/gpio_control.md](../Android/HW/gpio_control.md): `vcc5v0-otg-regulator` in the RK3566 GPIO list
+ [../Android/Debug/uart_console.md](../Android/Debug/uart_console.md): serial console, for switching roles without losing adb
+ [../Linux/HW/sysfs_intro.md](../Linux/HW/sysfs_intro.md)

## Reference

+ [USB role switch class (kernel ABI)](https://docs.kernel.org/admin-guide/abi-testing.html)
+ [USB Type-C connector class (kernel docs)](https://docs.kernel.org/driver-api/usb/typec.html)
+ [USB dual-role device tree binding (`dr_mode`)](https://www.kernel.org/doc/Documentation/devicetree/bindings/usb/usb-drd.yaml)
+ [USB-IF documents: OTG and Type-C specifications](https://www.usb.org/documents)
+ [USB host and accessory (Android developers)](https://developer.android.com/develop/connectivity/usb)
