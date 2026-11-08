# USB CDC: serial ports and networking over USB

**CDC (Communications Device Class)** is a USB-IF class specification for communication devices: serial ports, modems, and network adapters.
Operating systems ship generic CDC drivers, so a device that follows the class works without a vendor driver.

## 1. CDC subclasses

| Subclass | Emulates | Linux host driver → node | Typical devices |
| --- | --- | --- | --- |
| **ACM** (Abstract Control Model) | A serial port (originally an AT-command modem) | `cdc_acm` → `/dev/ttyACM*` | MCUs with native USB (STM32, RP2040, ESP32-S2/S3/C3), Arduino Uno's ATmega16U2, ST-LINK virtual COM port, cellular modems |
| **ECM** (Ethernet Control Model) | An Ethernet adapter | `cdc_ether` → `usb0` / `enx<MAC>` | USB Ethernet adapters, Linux gadgets |
| **NCM** (Network Control Model) | Ethernet, with several frames per USB transfer (faster than ECM) | `cdc_ncm` | Newer adapters and phones, Linux gadgets |
| **EEM** (Ethernet Emulation Model) | Ethernet, simpler framing | `cdc_eem` | Some Linux gadgets |
| **MBIM** (Mobile Broadband Interface Model) | A mobile broadband (LTE/5G) modem | `cdc_mbim` → `wwan0` (with ModemManager) | Cellular modules |
| OBEX, WMC, ATM networking, ... | Object exchange, wireless handsets, ATM networks | | Rare today |

+ **RNDIS** is Microsoft's own protocol, not part of CDC, although it uses CDC-like descriptors (`rndis_host` on Linux).
  Android USB tethering has traditionally used RNDIS; newer devices can use NCM.
+ **USB-to-UART bridge chips** (FTDI, CP210x, CH340, PL2303) are usually **not** CDC: they use vendor-specific protocols,
  and Linux has a driver for each (`ftdi_sio`, `cp210x`, `ch341`, `pl2303`) that creates `/dev/ttyUSB*`.
  Boards such as the original ESP32 DevKit and many Arduino Nano clones use them.

## 2. How CDC-ACM works

A CDC-ACM function has two interfaces, grouped by an Interface Association Descriptor (IAD) when the device has other functions too:

| Interface | Endpoints | Carries |
| --- | --- | --- |
| Communication (class `02`, subclass `02`) | 1 interrupt IN | Notifications such as `SERIAL_STATE` (carrier detect, errors) |
| Data (class `0A`) | 1 bulk IN + 1 bulk OUT | The byte stream |

The serial settings are **class requests on the control endpoint (EP0)**:

+ `SET_LINE_CODING`: baud rate, stop bits, parity, data bits (what `stty` or a terminal program sets).
+ `SET_CONTROL_LINE_STATE`: DTR and RTS. Many firmwares send data only while DTR is set, that is, while a terminal has the port open.

There is no real UART between the host and an MCU with native USB, so the **baud rate is ignored**.
Data moves at USB bulk speed: up to about 1 MB/s at Full Speed (12 Mbit/s).
The baud rate only matters when the device forwards the data to a real UART (USB-UART bridges, debug probes).

The OS names the port: `/dev/ttyACM0` on Linux, `/dev/cu.usbmodem*` on macOS, and `COMn` on Windows
(Windows 10 and later load the inbox `usbser.sys` driver automatically; older versions need an INF file).

## 3. Linux host

```shell
sudo dmesg | grep -i acm                  # cdc_acm 1-2:1.0: ttyACM0: USB ACM device
ls -l /dev/serial/by-id/                  # stable names (vendor, product, serial number) -> ../../ttyACM0
sudo usermod -aG dialout "$USER"          # access to ttyACM*/ttyUSB* without sudo (log in again)
picocom -b 115200 /dev/ttyACM0            # terminal; exit with Ctrl-A Ctrl-X
```

ModemManager probes new `ttyACM` ports with AT commands, which can confuse an MCU or a bootloader.
To exclude a device, use a udev rule:

```text
# /etc/udev/rules.d/99-mydevice.rules
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", ENV{ID_MM_DEVICE_IGNORE}="1"
```

## 4. Android as the USB host

When a CDC-ACM device is plugged into an Android phone or tablet (through an OTG adapter or a USB-C port), apps can't open `/dev/ttyACM*`:
the node, if the kernel creates it, is owned by root and blocked by SELinux.

+ Apps use the **USB Host API** (`android.hardware.usb`: `UsbManager`, `UsbDeviceConnection`) and talk to the bulk endpoints themselves.
  The user grants access in a permission dialog, or the app declares a `USB_DEVICE_ATTACHED` intent filter with a `device_filter.xml`.
+ The open-source library **usb-serial-for-android** implements CDC-ACM and the common bridge chips (FTDI, CP210x, CH34x, PL2303) on top of this API, without root.
+ On a custom board where a device is permanently attached, a system service or HAL can own the tty node instead,
  with explicit SELinux rules. Apps then reach it through that service, not through the node.

## 5. Linux or Android as the USB device (gadget)

A board whose USB controller runs in **peripheral** mode ([USB_OTG.md](USB_OTG.md)) can present a CDC function to a PC.
The ACM function creates **`/dev/ttyGS0`** on the board and `/dev/ttyACM0` (or `COMn`) on the PC.
Gadgets are configured through **configfs** (the old way: `modprobe g_serial`):

```shell
sudo modprobe libcomposite
cd /sys/kernel/config/usb_gadget
sudo mkdir g1 && cd g1
echo 0x1d6b | sudo tee idVendor            # Linux Foundation IDs: for testing only
echo 0x0104 | sudo tee idProduct           # "Multifunction Composite Gadget"
sudo mkdir strings/0x409
echo "my-board" | sudo tee strings/0x409/product
sudo mkdir configs/c.1
sudo mkdir functions/acm.usb0              # -> /dev/ttyGS0; ecm.usb0 / ncm.usb0 for networking
sudo ln -s functions/acm.usb0 configs/c.1/
ls /sys/class/udc | sudo tee UDC           # bind the gadget to the device controller
```

+ For a login console on the PC: `sudo systemctl enable --now serial-getty@ttyGS0.service` on the board.
+ Android sets up its gadget the same way (configfs mounted at `/config/usb_gadget/g1`), from the device's `init.*.usb.rc`
  and the USB gadget HAL, for adb, MTP, tethering, and so on. Adding an ACM function there is a vendor change in those files.

## Related notes

+ [USB_OTG.md](USB_OTG.md): host, device, and dual-role ports
+ [../Android/Debug/USB_port_speed.md](../Android/Debug/USB_port_speed.md): USB 2.0 vs 3.0 ports
+ [Modbus_RTU.md](Modbus_RTU.md): RS-485 over USB serial adapters
+ [../Embedded/RPi_pico_Cxx_SDK.md](../Embedded/RPi_pico_Cxx_SDK.md): `stdio` over USB CDC on the Pico
+ [../Linux/sysfs_intro.md](../Linux/sysfs_intro.md): configfs

## Reference

+ [USB-IF class specifications (CDC)](https://www.usb.org/documents)
+ [Linux USB gadget configfs (kernel docs)](https://docs.kernel.org/usb/gadget_configfs.html)
+ [Linux CDC ACM driver (kernel docs)](https://docs.kernel.org/usb/acm.html)
+ [USB host overview (Android developers)](https://developer.android.com/develop/connectivity/usb/host)
+ [usb-serial-for-android (GitHub)](https://github.com/mik3y/usb-serial-for-android)
