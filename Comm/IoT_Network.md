# IoT network interfaces

An IoT device usually has more than one interface. A typical sensor node talks to its sensors over an on-board bus (I2C, SPI, UART),
sends data over a radio or a cable to a gateway or the internet, and carries that data with an application protocol such as MQTT.
This note sorts the options by layer and range, and compares them by range, data rate, and power.

```text
 sensor/actuator ──(I2C/SPI/UART)── MCU/SoC ──(radio or cable)── gateway / router ──(IP)── cloud / server
    on-board bus (section 1)            local or wide-area link (sections 2-5)          app protocol (section 6)
```

## 1. On-board buses (chip to chip)

These connect a microcontroller or SoC to sensors, memories, displays, and radio modules on the same board or over a short cable.
They are not networks in the IP sense, but every IoT device uses them.

| Bus | Wires | Sync | Duplex | Typical speed | Typical use |
| --- | --- | --- | --- | --- | --- |
| I2C | 2 (SDA, SCL) + GND | Yes | Half | 100 kHz, 400 kHz, 1 MHz | Many slow peripherals on one bus, selected by 7-bit address (temperature sensors, RTCs, EEPROMs) |
| SPI | 4 (SCLK, MOSI, MISO, CS) + one CS per extra device | Yes | Full | Several to tens of MHz | Fast peripherals: flash, displays, ADCs, radio chips |
| UART | 2 (TX, RX) + GND | No (both sides agree on the baud rate) | Full | 9600 to ~1 Mbit/s | Debug console, GPS modules, cellular/Wi-Fi/BLE modules (AT commands) |

+ I2C and SPI are for short distances (centimeters, on one board). For longer cables use a differential bus (section 5).
+ UART is only the framing. RS-232 and RS-485 are physical layers that carry UART frames over longer distances.
+ On Linux these appear as `/dev/i2c-N`, `/dev/spidevB.C`, and `/dev/ttyS*` / `/dev/ttyAMA*` / `/dev/ttyUSB*`, and are usually enabled in the device tree.

## 2. Short-range wireless (PAN / LAN)

For devices that talk to a phone, a hub, or a router within a home, office, or factory floor.

| Technology | Band | Typical range | Data rate | Topology | Power | Typical use |
| --- | --- | --- | --- | --- | --- | --- |
| Wi-Fi (IEEE 802.11) | 2.4 / 5 / 6 GHz | ~10–50 m indoors | Mbit/s to Gbit/s | Star (access point) | High | Cameras, appliances, anything mains-powered that needs direct IP |
| Bluetooth LE | 2.4 GHz | ~10–100 m | Up to 2 Mbit/s (PHY) | Star, broadcast; mesh optional | Very low | Wearables, beacons, phone-configured devices |
| Zigbee (IEEE 802.15.4) | 2.4 GHz (sub-GHz variants exist) | ~10–100 m per hop | 250 kbit/s | Mesh | Low | Lighting, sensors, smart home |
| Thread (IEEE 802.15.4) | 2.4 GHz | ~10–100 m per hop | 250 kbit/s | IPv6 mesh | Low | Smart home, the main low-power transport for Matter |
| Z-Wave | Sub-GHz (868 MHz EU, 908 MHz US) | ~30–100 m per hop | Up to 100 kbit/s | Mesh | Low | Locks, sensors, home security |
| NFC | 13.56 MHz | A few cm | Up to 424 kbit/s | Point-to-point | Very low (passive tags need no battery) | Pairing, commissioning, access cards |
| RFID | LF / HF / UHF | cm (LF/HF) to ~10 m (UHF passive) | Low | Reader to tag | Passive tags need no battery | Asset and inventory tracking |

+ **Wi-Fi** gives direct IP and high bandwidth, but costs the most power. Low-power variants exist (Wi-Fi HaLow, IEEE 802.11ah, sub-GHz; target wake time in Wi-Fi 6),
  but battery devices still usually choose BLE, Zigbee, or Thread.
+ **BLE** is not Classic Bluetooth. It sends short bursts and sleeps in between, so it can run for months or years on a coin cell.
  Every phone supports it, which makes the phone the configuration tool or gateway. See [BLE_intro.md](BLE_intro.md).
+ **Zigbee, Thread, and Z-Wave** are mesh networks: mains-powered nodes relay traffic, so coverage grows with the number of devices.
  Zigbee and Thread share the same IEEE 802.15.4 radio but use different upper layers. Thread is IP-based (IPv6/6LoWPAN), Zigbee is not.
  All three need a hub or border router to reach the internet.
+ **Matter** is not a radio. It is an application-layer standard (from the Connectivity Standards Alliance, which also maintains Zigbee)
  that runs over Wi-Fi, Thread, or Ethernet, and uses BLE for commissioning.

## 3. LPWAN (low-power wide-area networks)

For battery-powered sensors that send a few small packets per hour or per day over kilometers.
They trade data rate and latency for range and battery life (years).

| Technology | Spectrum | Typical range | Data rate | Network | Mobility | Typical use |
| --- | --- | --- | --- | --- | --- | --- |
| LoRaWAN | Unlicensed sub-GHz (868 MHz EU, 915 MHz US, ...) | ~2–5 km urban, 10–15 km rural (line of sight) | ~0.3–50 kbit/s | Private gateways or public operators | Limited | Agriculture, metering, smart city, campus sensors |
| NB-IoT | Licensed LTE (cellular operator) | Cellular coverage, good deep-indoor | Tens of kbit/s | Mobile operator | Limited (no seamless handover in early releases) | Smart meters, fixed sensors in basements |
| LTE-M (LTE Cat-M1) | Licensed LTE (cellular operator) | Cellular coverage | Up to ~1 Mbit/s | Mobile operator | Yes (handover, VoLTE possible) | Asset tracking, wearables, fleet telematics |
| Sigfox | Unlicensed sub-GHz | ~3–10 km urban, more rural | ~100 bit/s, ~140 uplink messages/day of 12 bytes | Operator network only | Limited | Very cheap, very infrequent status messages |

+ **LoRa vs LoRaWAN**: LoRa is the physical-layer modulation (chirp spread spectrum, Semtech chips). LoRaWAN is the open MAC and network
  specification from the LoRa Alliance that runs on top (end device → gateway → network server). You can also use raw LoRa point-to-point without LoRaWAN.
+ Unlicensed bands have regional **duty-cycle** or dwell-time limits (for example 1% on many EU 868 MHz sub-bands), which caps how often a device can send.
+ **NB-IoT vs LTE-M**: both are 3GPP cellular standards and need a SIM and a carrier plan. Choose NB-IoT for fixed, deep-indoor, very low-rate devices,
  LTE-M for moving devices or when you need more bandwidth or lower latency. Availability depends on the country and carrier; check before you choose.
+ **Sigfox**: the original company went into receivership in 2022 and the network was taken over by UnaBiz. Coverage varies by country; check it before designing it in.

## 4. Cellular and satellite (WAN)

For devices that need a wide-area link with more bandwidth than LPWAN, or that work where no local network exists.

+ **LTE Cat 1 / Cat 1 bis**: about 10 Mbit/s down, 5 Mbit/s up. A common middle ground for payment terminals, alarm panels, and trackers
  that need more than LTE-M but not full LTE speeds. Cat 1 bis uses a single antenna.
+ **4G LTE (Cat 4 and above) / 5G**: high throughput and low latency for gateways, industrial routers, cameras, dashcams, and vehicles.
  5G RedCap (3GPP Release 17) is a reduced-capability 5G profile for mid-range IoT devices.
+ **Satellite IoT**: for assets beyond cellular coverage (ships, pipelines, remote farms, oil rigs). Options range from dedicated low-data-rate
  satellite services to 3GPP non-terrestrial networks (NTN, NB-IoT/LTE-M over satellite, from Release 17). Higher latency and cost per byte.

## 5. Wired interfaces and fieldbuses

Wired links are preferred when power is available at the device, when the environment is electrically noisy, or when reliability matters more than installation cost.

| Interface | Physical layer | Max distance | Speed | Topology | Typical use |
| --- | --- | --- | --- | --- | --- |
| RS-485 | Differential pair, half duplex | ~1200 m (at low baud rates) | Up to ~10 Mbit/s (short cables) | Multi-drop bus, 32 unit loads | Modbus RTU, meters, inverters, building automation |
| CAN / CAN FD | Differential pair (CAN_H, CAN_L) | ~40 m at 1 Mbit/s, longer at lower rates | CAN: 1 Mbit/s; CAN FD: several Mbit/s in the data phase | Multi-master bus with message priority | Vehicles, machines, robots, battery systems |
| Ethernet (RJ45) | Twisted pair | 100 m per segment | 10 Mbit/s to 10 Gbit/s | Star (switch) | Gateways, PLCs, cameras, anything needing IP |
| Single Pair Ethernet (10BASE-T1L) | One twisted pair | Up to ~1000 m | 10 Mbit/s | Point-to-point | Field instruments in process plants |

+ **RS-485 vs Modbus**: RS-485 is only the electrical layer; Modbus is a protocol. Modbus RTU runs over RS-485 (or RS-232),
  Modbus TCP runs over Ethernet. See [Modbus_intro.md](Modbus_intro.md) and [Modbus_RTU.md](Modbus_RTU.md).
+ **CAN** frames carry an identifier instead of a destination address. The identifier also sets the priority during bus arbitration.
  Linux supports CAN through SocketCAN (`can0` network interfaces).
+ **Power over Ethernet** (IEEE 802.3af / at / bt) sends power and data over the same cable, which is common for cameras, access points, and building sensors.
+ **Industrial Ethernet** protocols (PROFINET, EtherNet/IP, EtherCAT, Modbus TCP) run on Ethernet hardware and add real-time behavior or industrial data models.

## 6. Application protocols on top

The interfaces above move bytes. An application protocol decides how devices publish and request data:

| Protocol | Transport | Model | Typical use |
| --- | --- | --- | --- |
| MQTT | TCP (TLS optional) | Publish/subscribe through a broker | Telemetry from many devices to a server. See [MQTT_intro.md](MQTT_intro.md) |
| CoAP | UDP | Request/response (REST-like) | Constrained devices, Thread networks |
| HTTP / REST | TCP | Request/response | Gateways and Wi-Fi/Ethernet devices calling cloud APIs |
| Modbus TCP | TCP | Client/server polling | Industrial devices. See [Modbus_intro.md](Modbus_intro.md) |

Non-IP links (BLE, Zigbee, Z-Wave, LoRaWAN, Sigfox, Modbus RTU, CAN) need a **gateway** that translates them to IP and usually to one of these protocols.

## 7. Choosing an interface

| Need | Good candidates |
| --- | --- |
| Mains power, high bandwidth, existing Wi-Fi | Wi-Fi, Ethernet |
| Battery, phone as the user interface | BLE |
| Battery, many devices in one building | Zigbee, Thread (Matter), Z-Wave |
| Battery, kilometers, few bytes per hour, own infrastructure | LoRaWAN (private gateway) |
| Battery, kilometers, no own infrastructure | NB-IoT, LTE-M, public LoRaWAN |
| Moving asset with cellular coverage | LTE-M, LTE Cat 1 |
| No terrestrial coverage | Satellite IoT |
| Noisy industrial environment, long cables | RS-485 (Modbus RTU), CAN, Industrial Ethernet |

Check these before deciding: range in the real environment (walls, metal, terrain), how much data and how often, power budget,
regional frequency rules, module and subscription cost, and whether you control the infrastructure or depend on an operator.

## Related notes

+ [BLE_intro.md](BLE_intro.md): BLE concepts (GAP, GATT) and IoT workflow
+ [MQTT_intro.md](MQTT_intro.md): MQTT broker, topics, QoS, C examples
+ [Modbus_intro.md](Modbus_intro.md), [Modbus_RTU.md](Modbus_RTU.md), [Modbus_SunSpec.md](Modbus_SunSpec.md): Modbus protocol, RS-485 serial line, SunSpec models
+ [RF_IR_remote_ctrl.md](RF_IR_remote_ctrl.md): simple remote-control links (2.4 GHz, sub-GHz, infrared)
+ [../HW/Antenna_FPC.md](../HW/Antenna_FPC.md), [../HW/Antenna_SMD.md](../HW/Antenna_SMD.md): antennas for IoT radios

## Reference

+ Linux I2C: <https://docs.kernel.org/i2c/>
+ Linux SPI: <https://docs.kernel.org/spi/>
+ Linux SocketCAN: <https://docs.kernel.org/networking/can.html>
+ Bluetooth SIG: <https://www.bluetooth.com/>
+ Connectivity Standards Alliance (Zigbee, Matter): <https://csa-iot.org/>
+ Thread Group: <https://www.threadgroup.org/>
+ Z-Wave Alliance: <https://z-wavealliance.org/>
+ LoRa Alliance (LoRaWAN): <https://lora-alliance.org/>
+ 3GPP (NB-IoT, LTE-M, 5G, NTN): <https://www.3gpp.org/>
+ Modbus Organization: <https://modbus.org/>
+ MQTT: <https://mqtt.org/>
