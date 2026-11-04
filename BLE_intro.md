# Bluetooth Low Energy (BLE)

Bluetooth Low Energy (BLE) is a short-range, low-power radio in the 2.4 GHz band. It was introduced in Bluetooth 4.0 (2010).
Classic Bluetooth (BR/EDR) is built for continuous streams such as audio. BLE is built for short, infrequent bursts of small data,
such as a sensor reading or a switch state, so a device can sleep most of the time. That makes it one of the main radios for IoT devices.

Both radios share the "Bluetooth" name and often the same chip, but they are different protocols. A BLE-only device cannot talk to a Classic-only device.

## 1. BLE vs Classic Bluetooth

| | Classic (BR/EDR) | BLE |
| --- | --- | --- |
| Typical use | Audio, file transfer, serial port profile (SPP) | Sensors, wearables, beacons, device control |
| Data rate (PHY) | 1–3 Mbit/s | 1 Mbit/s; 2 Mbit/s and Coded PHY (long range) since Bluetooth 5 |
| Connection | Kept open, continuous | Short connection events, or no connection at all (advertising) |
| Power | Higher | Months to years on a coin cell, depending on the duty cycle |
| Data model | Profiles (A2DP, HFP, SPP, ...) | GATT services and characteristics |

Since Bluetooth 5.2, LE Audio (LC3 codec) also carries audio over BLE, but most IoT use is still small data.

## 2. Why BLE fits IoT

+ **Low power**: the radio is on only for short advertising or connection events (milliseconds), then the device sleeps.
+ **Phone support**: practically every phone, tablet, and laptop has BLE, so a phone app can configure or control the device, or act as its gateway.
+ **Cheap, small modules**: SoCs such as the nRF52, ESP32, or CC26xx integrate the radio and an MCU.
+ **Topologies**: point-to-point connections, one-to-many broadcast (beacons), and Bluetooth Mesh (many-to-many relaying built on BLE advertising, for lighting and building automation).

## 3. GAP: roles and discovery

The Generic Access Profile (GAP) defines how devices find each other and connect.

| Role | What it does | Example |
| --- | --- | --- |
| Peripheral | Advertises and accepts a connection | Sensor, smart plug, heart-rate strap |
| Central | Scans and starts the connection | Phone, Raspberry Pi, gateway |
| Broadcaster | Advertises only, never connects | Beacon (iBeacon, Eddystone) |
| Observer | Scans only, never connects | Beacon receiver |

+ **Advertising**: the peripheral sends small packets (31 bytes of payload in legacy advertising, more with Bluetooth 5 extended advertising)
  on three advertising channels at a fixed interval, for example every 100 ms to a few seconds. A longer interval saves power but makes discovery slower.
+ A central can request more data with a **scan request**; the peripheral answers with a **scan response**.
+ Many sensors put their readings directly in the advertising data, so receivers get them without connecting.

## 4. GATT: the data model

After a connection, data is exchanged with the Attribute Protocol (ATT), organized by the Generic Attribute Profile (GATT).

```text
GATT server (usually the peripheral)
└── Service            e.g. Battery Service (0x180F)
    └── Characteristic e.g. Battery Level (0x2A19), properties: read, notify
        ├── Value      e.g. 87 (%)
        └── Descriptor e.g. CCCD (0x2902): client turns notifications on/off
```

+ **GATT server** holds the data; **GATT client** reads and writes it. GATT roles are separate from GAP roles.
  Usually the peripheral is the server and the central is the client, but either side can be both.
+ **Service**: a group of related characteristics (Battery Service, Heart Rate Service, or a custom "Plug Control" service).
+ **Characteristic**: one value with **properties**: read, write, write without response, notify, indicate.
  - **Notify**: the server pushes the value without an acknowledgment.
  - **Indicate**: same, but the client acknowledges each one.
  - The client enables either one by writing to the characteristic's **CCCD** descriptor.
+ **UUIDs**: services and characteristics defined by the Bluetooth SIG use 16-bit UUIDs (`0x180F`). Custom ones use random 128-bit UUIDs.
+ **MTU**: the default ATT MTU is 23 bytes, so one notification or write carries 20 bytes of data. Both sides can negotiate a larger MTU after connecting.

## 5. Security

A BLE link is **not** encrypted by default. It becomes encrypted after **pairing** (key exchange); **bonding** stores the keys so the next connection is encrypted without pairing again.

+ Use **LE Secure Connections** (Bluetooth 4.2+, ECDH key exchange). The older Legacy Pairing can be broken by a passive sniffer when "Just Works" or a weak passkey is used.
+ The pairing method (Just Works, Passkey Entry, Numeric Comparison, Out of Band) depends on the I/O each device has.
  Just Works gives no protection against man-in-the-middle attacks.
+ Characteristics can require an encrypted or authenticated link before they can be read or written.
+ Advertising data is always plain text. Don't put secrets in it.

## 6. Typical control workflow

1. **Advertise**: the smart plug advertises its name and service UUID.
2. **Scan and connect**: the phone app scans, filters by the service UUID, and connects.
3. **Pair** (if needed): the first time, the devices pair and bond so the link is encrypted.
4. **Discover**: the app discovers the services and characteristics on the plug.
5. **Command**: the app writes `1` to the plug's "relay" characteristic; the plug switches the relay.
6. **Status**: the app subscribes (CCCD) to a "power" characteristic and receives notifications.
7. **Disconnect or stay connected**: a battery device usually disconnects and goes back to slow advertising;
   a mains-powered device can stay connected with a long connection interval.

## 7. BLE on Linux

Linux uses the **BlueZ** stack. Applications talk to the `bluetoothd` daemon over D-Bus.

```shell
bluetoothctl                  # interactive tool
[bluetooth]# power on
[bluetooth]# scan le          # scan for BLE devices (older versions: "scan on")
[bluetooth]# connect AA:BB:CC:DD:EE:FF
[bluetooth]# menu gatt
[bluetooth]# list-attributes
[bluetooth]# select-attribute /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/service000c/char000d
[bluetooth]# read
[bluetooth]# notify on
```

+ `btmon` shows the HCI traffic between the host and the controller, which helps when debugging connections and pairing.
+ `hcitool` and `gatttool` are deprecated in BlueZ; use `bluetoothctl` and `btmon` instead.
+ For scripts, use a D-Bus based library (for example `bleak` in Python) instead of raw HCI sockets.

## Related notes

+ [IoT_Network.md](IoT_Network.md): BLE compared with Wi-Fi, Zigbee, Thread, LoRaWAN, and others
+ [MQTT_intro.md](MQTT_intro.md): forwarding BLE sensor data to a server through a gateway
+ [Antenna_FPC.md](Antenna_FPC.md), [Antenna_SMD.md](Antenna_SMD.md): 2.4 GHz antennas
+ [remoteCtrl_RF.md](remoteCtrl_RF.md): proprietary 2.4 GHz links compared with BLE

## Reference

+ Bluetooth SIG specifications: <https://www.bluetooth.com/specifications/specs/>
+ Bluetooth SIG assigned numbers (16-bit UUIDs): <https://www.bluetooth.com/specifications/assigned-numbers/>
+ BlueZ: <http://www.bluez.org/>
+ Android BLE overview: <https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview>
