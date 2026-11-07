# RF and IR remote control

A remote control sends short commands (a button, a joystick position, a mouse movement) from a handheld unit to a receiver.
The two common carriers are **radio (RF)**, which passes through walls and needs no aiming,
and **infrared (IR) light**, which is cheap and simple but needs a line of sight.
This note covers 2.4 GHz links (wireless mice, nRF24L01, Pico W), sub-GHz 433/315 MHz remotes, and IR remotes, and compares them.

## 1. Overview

| Link | Frequency | Range (typical) | Direction | Typical use |
| --- | --- | --- | --- | --- |
| 2.4 GHz proprietary (mouse dongle, nRF24L01) | 2.400–2.4835 GHz ISM | 10 m (mouse) to 100+ m (nRF24 in open air) | Two-way, with acknowledgment | Mice, keyboards, game pads, RC models, DIY remotes |
| Bluetooth / BLE | 2.4 GHz ISM | ~10 m | Two-way | Mice, keyboards, phone-controlled devices |
| Wi-Fi (e.g. Pico W) | 2.4 GHz (also 5 GHz) | Network range | Two-way, IP | Control from a phone or PC via a web page or UDP |
| Sub-GHz OOK/ASK | 433.92 MHz (Europe/Asia), 315 MHz (US) | 20–100 m, through walls | Mostly one-way | Garage doors, RF power sockets, doorbells, car key fobs |
| Infrared | ~940 nm light, 36–40 kHz carrier | 5–10 m, line of sight | One-way | TV, air conditioner, set-top box remotes |

## 2. Wireless mice and keyboards (2.4 GHz)

How it works:

1. The mouse reads its sensor (optical or laser) and buttons, packs the data, and transmits it on a 2.4 GHz channel.
2. The USB receiver (dongle) receives the packets and presents itself to the computer as a standard USB **HID** device.
3. The operating system sees an ordinary USB mouse or keyboard, so no special driver is needed for basic use.

Proprietary 2.4 GHz vs. Bluetooth:

| | Proprietary 2.4 GHz dongle | Bluetooth / BLE |
| --- | --- | --- |
| Receiver | Dedicated USB dongle | Computer's built-in Bluetooth (or a generic adapter) |
| Works before the OS starts (BIOS/UEFI, boot menu) | Yes: the dongle is a plain USB HID device | Usually not: it needs the OS Bluetooth stack |
| Latency | Low; gaming mice poll at 1000 Hz (1 ms), office mice often 125 Hz (8 ms) | Higher and less constant (connection interval, typically 7.5–15 ms or more) |
| Pairing | Dongle accepts only the paired device ID | Standard Bluetooth pairing |

Notes:

+ To cope with Wi-Fi, microwave ovens and other 2.4 GHz devices, the links **change channel**:
  Bluetooth uses frequency hopping, and many proprietary mice hop or switch to a clearer channel when packets are lost.
+ Pairing (binding the mouse ID to its receiver) prevents mix-ups with nearby mice of the same model.
  It doesn't make the link secure: some older proprietary dongles accepted unencrypted or injected keystrokes
  (the "MouseJack" vulnerabilities, 2016). Use current firmware and devices with encrypted links for keyboards.
+ Typical range is up to about 10 m. Plugging the dongle into a front USB port or an extension cable helps,
  since USB 3.0 ports and cables emit noise in the 2.4 GHz band.

## 3. nRF24L01+ transceiver

The Nordic nRF24L01+ is a low-cost 2.4 GHz transceiver on an SPI bus, widely sold as small modules
(PCB antenna, or with PA + LNA and an external antenna). It is a proprietary radio: it can't talk to Wi-Fi or Bluetooth devices.

| Property | Value |
| --- | --- |
| Modulation | GFSK |
| Data rate | 250 kbit/s, 1 Mbit/s, 2 Mbit/s (250 kbit/s only on the "+" version; best range) |
| Channels | 126 (2400–2525 MHz in 1 MHz steps). Only channels 0–83 are inside the 2.4 GHz ISM band; don't use higher ones |
| Payload | Up to 32 bytes per packet; 6 receive "pipes" (addresses) per receiver |
| Link layer | Enhanced ShockBurst: automatic acknowledgment and retransmission; the ACK can carry a reply payload |
| Supply | 1.9–3.6 V (3.3 V). The data pins tolerate 5 V, VCC does not |
| Range | PCB antenna: tens of meters, up to ~100 m in open air. PA + LNA modules: several hundred meters in open air (vendor claims; much less indoors) |

Practical points:

+ Put a 10–100 µF capacitor directly across the module's VCC and GND. Unstable power is the most common cause of failures,
  especially with PA + LNA modules, which draw current peaks a weak 3.3 V regulator can't deliver.
+ Many modules carry clone chips (e.g. Si24R1) that are mostly, but not always, compatible.
+ Libraries: [RF24](https://nrf24.github.io/RF24/) (C++ for Arduino, Linux and the Pico SDK),
  and an `nrf24l01` driver in micropython-lib for MicroPython.

## 4. Sub-GHz remotes (433 / 315 MHz)

Simple key fobs, garage door openers and remote-controlled power sockets use **OOK/ASK** at 433.92 MHz (Europe, Asia) or 315 MHz (US):
the transmitter just switches the carrier on and off to send a short code.

+ Lower frequency than 2.4 GHz, so it passes walls better and reaches farther at the same power.
+ Cheap modules: transmitters like FS1000A; receivers like XY-MK-5V (super-regenerative, poor selectivity)
  or RXB6 (superheterodyne, much better). Transceivers such as the TI CC1101 also do FSK and work on several bands.
+ **Fixed-code** remotes (encoder chips like EV1527 or PT2262) send the same code every time and can be recorded and replayed.
  Garage doors and cars use **rolling codes** (e.g. KeeLoq), which change on every press.
+ Transmit power and duty cycle are regulated per region; check the local rules.

For long-range, low-rate sensor links in the same bands, see LoRa in [IoT_Network.md](IoT_Network.md).

## 5. Infrared (IR) remotes

An IR remote flashes an IR LED (about 940 nm) on and off at a carrier frequency, usually **38 kHz** (36, 40 and 56 kHz also exist).
The command is encoded in the timing of the bursts.

+ **Transmitter**: an IR LED driven through a transistor (a GPIO pin can't supply the 50–100 mA+ pulses for good range),
  with the carrier generated by PWM.
+ **Receiver**: an integrated receiver module (e.g. TSOP38238, VS1838B) containing a photodiode, amplifier, band-pass filter and demodulator.
  Its output pin gives the demodulated bursts directly (active low), so the MCU only measures pulse lengths.
+ **Protocols**: NEC, Sony SIRC, Philips RC-5/RC-6, and many vendor-specific ones (air conditioners send long state frames).
  Example, NEC:

```text
 9 ms burst | 4.5 ms space | 32 bits: address, ~address, command, ~command | final burst
 bit 0 = 562.5 us burst + 562.5 us space    bit 1 = 562.5 us burst + 1687.5 us space
 holding the button sends a short "repeat" frame every ~108 ms
```

+ Consumer remote protocols send only a few hundred bits per second, enough for command codes.
  (IrDA, the old laptop/phone IR data link, reached several Mbit/s, but uses a different scheme.)
+ Sunlight and some lamps contain a lot of IR. The modulated carrier and the receiver's filter reject most of it,
  but range drops strongly outdoors in bright sun.
+ On a Raspberry Pi running Linux, IR is handled by the kernel's rc-core:
  the `gpio-ir` (receive) and `gpio-ir-tx` (transmit) device tree overlays, plus `ir-keytable` and `ir-ctl` from v4l-utils.

## 6. RF vs. IR

| | 2.4 GHz RF (nRF24L01) | Infrared |
| --- | --- | --- |
| Line of sight | Not needed; passes through thin walls and around obstacles to a degree | Required (reflections off walls help a little indoors) |
| Range | Tens to hundreds of meters | 5–10 m indoors |
| Direction | Two-way, with ACK and retransmission | Typically one-way |
| Data rate | 250 kbit/s – 2 Mbit/s | A few hundred bit/s for remote protocols |
| Interference | Wi-Fi, Bluetooth, microwaves (mitigated by channel choice and retries) | Sunlight, some lamps; no radio interference |
| Hardware | SPI module, 3.3 V supply, library | IR LED + transistor, receiver module, one GPIO each |
| Containment | Leaks through walls, so several setups in one building need different channels/addresses | Stays in the room |

Choose **RF** for two-way links, telemetry, longer distances, or when obstacles block the line of sight.
Choose **IR** for simple point-and-press remotes, controlling existing TVs and air conditioners, or when the signal should stay in one room.

## 7. Example: remote control with a Raspberry Pi Pico

| Option | Hardware | How |
| --- | --- | --- |
| Wi-Fi | Pico W / Pico 2 W (CYW43439 chip, 2.4 GHz Wi-Fi) | One board (or a phone/PC) sends UDP packets or HTTP requests; the receiving Pico W drives motors or LEDs with PWM. Needs a network or one Pico W as access point; latency is higher and less constant than a dedicated radio |
| Bluetooth | Pico W / Pico 2 W (Bluetooth 5.2, supported by the Pico SDK) | BLE GATT service controlled from a phone app or another Pico W, see [BLE_intro.md](BLE_intro.md) |
| nRF24L01+ | Any Pico + nRF24L01+ module | Direct, low-latency point-to-point radio; no network needed |
| IR | Any Pico + IR LED/receiver | Receive codes from an existing TV remote, or send codes to a TV/AC. PIO generates and decodes the timing well (see the `pio/ir_nec` example in pico-examples) |

nRF24L01+ wiring to the Pico's default SPI0 pins (any free GPIO can serve as CE and CSN, since the driver toggles them in software):

| nRF24L01+ | Pico |
| --- | --- |
| VCC | 3V3 (pin 36), plus the capacitor from section 3 |
| GND | GND |
| SCK | GP18 (SPI0 SCK) |
| MOSI | GP19 (SPI0 TX) |
| MISO | GP16 (SPI0 RX) |
| CSN | GP17 |
| CE | GP20 (any free GPIO) |
| IRQ | Optional, any GPIO |

A typical handheld unit reads a joystick (ADC) and buttons, sends a small packet (e.g. 4–8 bytes) every 20–50 ms,
and the receiver stops the motors if no packet arrives for a while (a failsafe timeout).

## Related notes

+ [BLE_intro.md](BLE_intro.md): Bluetooth Low Energy, the standard 2.4 GHz alternative
+ [IoT_Network.md](IoT_Network.md): Wi-Fi, Zigbee, Thread, LoRa and other IoT radios compared
+ [Antenna_FPC.md](Antenna_FPC.md), [Antenna_SMD.md](Antenna_SMD.md): 2.4 GHz antennas
+ [RPi_pico_Cxx_SDK.md](RPi_pico_Cxx_SDK.md): Pico C/C++ SDK, including Wi-Fi on the Pico W
+ [RPi_pico_PIO.md](RPi_pico_PIO.md): PIO state machines, useful for IR timing

## Reference

+ [Nordic Semiconductor: nRF24 series](https://www.nordicsemi.com/Products/nRF24-series)
+ [RF24 library documentation](https://nrf24.github.io/RF24/)
+ [Raspberry Pi Pico documentation](https://www.raspberrypi.com/documentation/microcontrollers/)
+ [pico-examples (GitHub)](https://github.com/raspberrypi/pico-examples)
+ [Linux kernel: Remote Controller devices (rc-core)](https://docs.kernel.org/userspace-api/media/rc/index.html)
