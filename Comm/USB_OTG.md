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

# Rockchip BSP kernels (RK3566/RK3568, 4.19/5.10): mode attribute of the USB 2 PHY
echo host | sudo tee /sys/devices/platform/fe8a0000.usb2-phy/otg_mode   # host | peripheral | otg
```

Which of these exist depends on the controller driver, the kernel version, and the device tree; `find /sys -name otg_mode -o -name role` helps.
In host role, the VBUS regulator (`vbus-supply` / `phy-supply` in the device tree) must turn on as well.

### 3.3 Android

+ Device role is the default: adb, MTP, and USB tethering are gadget functions ([USB_CDC.md](USB_CDC.md#5-linux-or-android-as-the-usb-device-gadget)).
+ With a USB-C port and a PD controller: **Settings → Connected devices → USB → "USB controlled by"**: "Connected device" or "This device" swaps the data role.
+ On development boards, the BSP often offers a property or a Settings toggle that writes the kernel attribute above.
  A development board with only one OTG port can't do adb over USB while it acts as a host; use adb over TCP ([../Android/adb_intro.md](../Android/adb_intro.md)).

## Related notes

+ [USB_CDC.md](USB_CDC.md): CDC-ACM serial ports, gadget setup
+ [../Android/USB_port_speed.md](../Android/USB_port_speed.md): USB 2.0 vs 3.0 host controllers
+ [../Linux/dts_node_regulator_fixed.md](../Linux/dts_node_regulator_fixed.md): a GPIO-switched 5 V VBUS regulator
+ [../Linux/sysfs_intro.md](../Linux/sysfs_intro.md)

## Reference

+ [USB role switch class (kernel ABI)](https://docs.kernel.org/admin-guide/abi-testing.html)
+ [USB Type-C connector class (kernel docs)](https://docs.kernel.org/driver-api/usb/typec.html)
+ [USB dual-role device tree binding (`dr_mode`)](https://www.kernel.org/doc/Documentation/devicetree/bindings/usb/usb-drd.yaml)
+ [USB-IF documents: OTG and Type-C specifications](https://www.usb.org/documents)
+ [USB host and accessory (Android developers)](https://developer.android.com/develop/connectivity/usb)
