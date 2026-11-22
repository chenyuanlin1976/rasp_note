# USB Type-C and Power Delivery: kernel driver (TCPC/TCPM), device tree, bring-up on Android

A USB-C port with a Power Delivery (PD) controller is driven by the Linux kernel's **Type-C subsystem** (`drivers/usb/typec/`).
It detects plug orientation, chooses the power role (source/sink) and data role (host/device), switches VBUS and VCONN,
and negotiates the PD voltage/current contract and alternate modes (e.g. DisplayPort).
On Android, the **USB HAL** (`android.hardware.usb`) reads the result from sysfs and reports it to the framework (`UsbService`, Settings).

CC pins, DRP, and role swaps from the protocol side: [../../Comm/USB_OTG.md](../../Comm/USB_OTG.md#22-usb-c-the-cc-pins).

## 1. Architecture: TCPC, TCPCI, TCPM

```text
+------------------------------------------------------------------+
| Android: Settings / UsbManager -> UsbService (system_server)     |
|          -> USB HAL (vendor) reads /sys/class/typec, power_supply |
+------------------------------------------------------------------+
                               | sysfs
+------------------------------------------------------------------+
| Kernel Type-C class (/sys/class/typec), usb_power_delivery class |
+------------------------------------------------------------------+
| TCPM (tcpm.c): Type-C state machine + PD policy/protocol engine  |
|   -> USB role switch (DWC3: host/device)                         |
|   -> power_supply "tcpm-source-psy-*" (negotiated contract)      |
|   -> muxes / alt modes (orientation switch, DisplayPort)         |
+------------------------------------------------------------------+
| TCPC driver: fusb302.c, or tcpci.c + vendor glue (rt1711h, ...)  |
+------------------------------------------------------------------+
                               | I2C + ALERT/INT_N interrupt
+------------------------------------------------------------------+
| TCPC chip: CC detection, Rp/Rd, VBUS/VCONN switches, BMC PHY     |
+------------------------------------------------------------------+
```

| Term | What it is |
| --- | --- |
| **TCPC** (Type-C Port Controller) | The chip: CC detection and orientation, Rp/Rd, VBUS/VCONN switches, PD messages on CC (BMC physical layer). Raises an interrupt on events. Standalone I2C part (FUSB302, RT1711H, HUSB311) or inside a PMIC |
| **TCPCI** (TCPC Interface) | USB-IF standard register map for a TCPC over I2C plus an `ALERT` line. A compliant chip can use the generic `tcpci.c` driver with a little glue |
| **TCPM** (Type-C Port Manager) | Kernel code (`drivers/usb/typec/tcpm/tcpm.c`) that runs the Type-C and PD state machines on behalf of a "dumb" TCPC |
| Type-C class | Exposes ports, partners, cables and roles in `/sys/class/typec/` |

Some PD controllers (TI TPS6598x, Cypress CCGx) run the PD policy in their own firmware. Their drivers don't use TCPM;
they register with the Type-C class directly and only report what the firmware negotiated.

## 2. Common chips and their drivers

| Chip | Vendor | Type | Mainline driver |
| --- | --- | --- | --- |
| FUSB302 / FUSB302B | onsemi (Fairchild) | TCPC, not TCPCI-compliant; very common on RK3399/RK356x boards | `drivers/usb/typec/tcpm/fusb302.c` (`CONFIG_TYPEC_FUSB302`, compatible `fcs,fusb302`) |
| PTN5110 and other TCPCI chips | NXP, others | TCPCI-compliant TCPC | `drivers/usb/typec/tcpm/tcpci.c` (`CONFIG_TYPEC_TCPCI`) |
| RT1711H / RT1715 | Richtek | TCPCI + vendor glue | `drivers/usb/typec/tcpm/tcpci_rt1711h.c` |
| HUSB311 | Hynetek | TCPCI-compatible; used on RK3566/RK3568 boards | Rockchip BSP kernel glue driver (check your SDK) |
| RT1719 | Richtek | Sink-only PD controller with its own policy | `drivers/usb/typec/rt1719.c` |
| TPS6598x (TPS65982/TPS65987/TPS65988) | TI | Full PD controller with firmware; docks, laptops | `drivers/usb/typec/tipd/` |
| TUSB320 | TI | CC logic only, no PD (advertises up to 3 A) | `drivers/extcon/extcon-usbc-tusb320.c` |
| PMIC-integrated Type-C/PD | Qualcomm, MediaTek, ... | Part of the PMIC | Vendor (or newer mainline) PMIC drivers |

Before writing a driver, search `drivers/usb/typec/` and the BSP for the chip and for a chip with the same register layout.
For a TCPCI-compliant chip, the glue is usually only chip ID check, vendor init, and quirks ([driver_porting.md](driver_porting.md)).

## 3. Device tree

Example for a FUSB302 on I2C, as a dual-role port that prefers sink. It follows the mainline `fcs,fusb302` and `usb-c-connector` bindings;
check the binding YAML files of your kernel, and the node and pin names of your board.

```dts
#include <dt-bindings/usb/pd.h>          /* PDO_FIXED(), PDO_VAR(), PDO_FIXED_* flags */

&i2c3 {
	status = "okay";

	typec: usb-typec@22 {
		compatible = "fcs,fusb302";
		reg = <0x22>;
		interrupt-parent = <&gpio1>;
		interrupts = <RK_PA2 IRQ_TYPE_LEVEL_LOW>;    /* GPIO1_A2 = INT_N, active low (rockchip.h) */
		pinctrl-names = "default";
		pinctrl-0 = <&fusb302_int>;
		vbus-supply = <&vcc5v0_otg>;                 /* switched 5 V for source role */

		connector {
			compatible = "usb-c-connector";
			label = "USB-C";
			data-role = "dual";
			power-role = "dual";
			try-power-role = "sink";
			source-pdos = <PDO_FIXED(5000, 1500, PDO_FIXED_USB_COMM)>;
			sink-pdos = <PDO_FIXED(5000, 2000, PDO_FIXED_USB_COMM)
				     PDO_VAR(5000, 12000, 2000)>;
			op-sink-microwatt = <10000000>;          /* 10 W: needed for sink and dual power roles */

			ports {
				#address-cells = <1>;
				#size-cells = <0>;

				port@0 {                             /* USB 2.0 / high-speed data */
					reg = <0>;
					typec_hs: endpoint {
						remote-endpoint = <&usb_role_switch>;
					};
				};
			};
		};
	};
};

&usbdrd_dwc3 {
	dr_mode = "otg";
	usb-role-switch;                    /* TCPM sets host/device through this role switch */
	status = "okay";

	port {
		usb_role_switch: endpoint {
			remote-endpoint = <&typec_hs>;
		};
	};
};
```

+ `PDO_FIXED(mV, mA, flags)`, `PDO_VAR(min_mV, max_mV, mA)`, `PDO_BATT(...)`, `PDO_PPS_APDO(...)` come from `dt-bindings/usb/pd.h`.
+ `sink-pdos` lists what this board can accept; TCPM requests the best match from the charger's source capabilities.
+ Without the role-switch link, PD works but the USB controller doesn't follow data-role changes.
+ The 5 V switch and regulator: [../DeviceTree/dts_node_regulator_fixed.md](../DeviceTree/dts_node_regulator_fixed.md).

## 4. Writing a TCPC driver for TCPM

A chip that does CC detection, VBUS/VCONN switching and PD message TX/RX, but leaves the state machine to the host, needs a TCPC driver:

1. **Probe**: read the chip ID over I2C (fail early on NACK), reset the chip, and get supplies, GPIOs and the connector `fwnode`.
2. **Fill `struct tcpc_dev`** (`include/linux/usb/tcpm.h`) with the connector `fwnode` and the callbacks:

| Callback | Job |
| --- | --- |
| `init` | Default registers and interrupt masks |
| `get_cc`, `set_cc` | Read CC1/CC2 state (`TYPEC_CC_OPEN`, `_RA`, `_RD`, `_RP_DEF`, ...); apply Rp/Rd |
| `start_toggling` | DRP toggling while unattached (Rp/Rd alternating in hardware) |
| `set_polarity` | Which CC line carries PD after attach (plug orientation) |
| `get_vbus`, `set_vbus`, `set_vconn` | VBUS present?; source/sink VBUS paths; VCONN power to the cable |
| `set_pd_rx`, `pd_transmit` | Enable PD receive; send a message or hard reset, then report with `tcpm_pd_transmit_complete()` |
| `set_roles` | Apply power and data role (and the PD message header roles) |

3. **Register**: `port = tcpm_register_port(dev, &chip->tcpc_dev)` (returns an `ERR_PTR` on failure);
   call `tcpm_unregister_port()` in `remove`. For a TCPCI chip, fill `struct tcpci_data` and call `tcpci_register_port()` instead.
4. **Threaded IRQ** (`devm_request_threaded_irq(..., IRQF_ONESHOT ...)`): read and clear the alert/status registers over I2C,
   then notify TCPM with `tcpm_cc_change()`, `tcpm_vbus_change()`, `tcpm_pd_receive()`, `tcpm_pd_hard_reset()`.
   I2C can sleep, so this can't run in hard-IRQ context.
   Don't call back into TCPM while holding a lock that your `tcpc_dev` callbacks also take: TCPM calls them with its own lock held.
5. Check the exact signatures in your kernel's `tcpm.h`; some changed between versions (e.g. `tcpm_pd_receive()` gained an SOP-type argument in 6.x).

`fusb302.c` is a compact real example of all of this.

## 5. Inspecting a port

The sysfs nodes, the TCPM power supply, and `dumpsys usb` with sample output are in
[../../Android/Debug/check_peripherals.md](../../Android/Debug/check_peripherals.md#6-usb-c-and-power-delivery-pd). In short:

```text
/sys/class/typec/port0/power_role             [source] sink   (brackets: current role)
/sys/class/typec/port0/data_role              [host] device
/sys/class/typec/port0/port_type              dual | source | sink (writable on DRP ports)
/sys/class/typec/port0/vconn_source           yes | no
/sys/class/typec/port0/power_operation_mode   default | 1.5A | 3.0A | usb_power_delivery
/sys/class/typec/port0/orientation            normal | reverse | unknown (newer kernels)
/sys/class/typec/port0-partner/               exists while something is attached
/sys/class/typec/port0-cable/                 cable, with e-marker identity if present
/sys/class/usb_power_delivery/                PD capabilities and PDOs (6.0+, if the driver registers them)

/sys/class/power_supply/tcpm-source-psy-<dev>/
    online, voltage_now, current_max          negotiated contract (µV, µA), not a measurement
    usb_type                                  e.g. C [PD] PD_PPS
```

+ TCPM and TCPC messages are **kernel** logs: `adb shell dmesg` or `adb logcat -b kernel`, not the main logcat buffer.
+ The TCPM state-machine log is in debugfs: `/sys/kernel/debug/usb/tcpm-<dev>` (`CONFIG_DEBUG_FS`, root).
  Since Android 12, GKI production builds don't mount debugfs; use a userdebug/eng build or a development kernel.
+ Framework side: `adb shell dumpsys usb` shows the ports as the USB HAL reports them (`UsbPortStatus`: current power role, data role, supported modes).
  Logcat tags: `UsbPortManager`, `UsbDeviceManager`, and the vendor USB HAL service.
+ Other `power_supply` names (`usb`, `battery`, PMIC-specific) show charger type and measured values, depending on the SoC.

## 6. Bring-up checklist

1. **I2C and interrupt**
   + The driver probes without I2C NACK/timeout errors and reads a valid chip ID (`dmesg`).
   + The interrupt count in `/proc/interrupts` rises on plug and unplug.
2. **CC detection and PD negotiation** (watch `dmesg` and the debugfs TCPM log)
   + With a USB-C sink, a PC (host), and a PD charger in turn, TCPM moves from unattached to attached source/sink states.
   + With a PD charger: `Source_Capabilities` → `Request` → `Accept` → `PS_RDY`, and `power_operation_mode` becomes `usb_power_delivery`.
   + `voltage_now` of the TCPM power supply shows the requested voltage (e.g. `9000000` for 9 V). `default` with a PD charger means PD failed and the port fell back to 5 V.
   + Use chargers offering 5/9/12/15 V and a PD-capable USB-C meter between charger and board.
3. **Roles and Android**
   + Flash drive: data role host, power role source, VBUS on, the drive enumerates (`lsusb` or `/sys/bus/usb/devices`).
   + PC: data role device, power role sink, adb/MTP work.
   + Role swap from Settings → USB ("USB controlled by"), or `echo device > /sys/class/typec/port0/data_role`; the partner must accept `DR_Swap`.
   + `dumpsys usb` matches the sysfs roles.

## Related notes

+ [../../Comm/USB_OTG.md](../../Comm/USB_OTG.md): dual-role ports, CC pins, `dr_mode`, role switching on RK3566
+ [../../Android/Debug/check_peripherals.md](../../Android/Debug/check_peripherals.md): checking USB-C/PD and the battery from adb
+ [../../Android/Debug/USB_port_speed.md](../../Android/Debug/USB_port_speed.md): USB 2.0 vs. 3.0 controllers
+ [driver_porting.md](driver_porting.md): enabling an existing driver on a board
+ [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md), [../DeviceTree/dts_node_regulator_fixed.md](../DeviceTree/dts_node_regulator_fixed.md)
+ [../Power/regulators.md](../Power/regulators.md)

## Reference

+ [USB Type-C connector class (kernel docs)](https://docs.kernel.org/driver-api/usb/typec.html)
+ [USB Type-C ABI: sysfs-class-typec (kernel docs)](https://docs.kernel.org/admin-guide/abi-testing.html)
+ [USB connector binding `usb-c-connector` (kernel source)](https://www.kernel.org/doc/Documentation/devicetree/bindings/connector/usb-connector.yaml)
+ [Linux power supply class (kernel docs)](https://docs.kernel.org/power/power_supply_class.html)
+ [USB HAL AIDL interface (AOSP source)](https://cs.android.com/android/platform/superproject/+/main:hardware/interfaces/usb/aidl/)
+ [USB-IF: USB Type-C and USB Power Delivery specifications](https://www.usb.org/documents)
