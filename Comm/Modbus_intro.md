# Modbus

Modbus is a request/response protocol for industrial devices: PLCs, sensors, power meters, inverters, drives.
Modicon (now Schneider Electric) published it in 1979. Today the Modbus Organization maintains it,
and the specifications are free to download and implement without royalties.

+ **Client** (formerly "master"): sends requests. A PLC, SCADA/HMI, gateway, or your Linux board.
+ **Server** (formerly "slave"): answers. A server never sends anything on its own, so the client has to **poll**.

The Modbus Organization switched to client/server terminology in 2020. Serial-line documents and many devices still say master/slave.

## 1. Layers and variants

The same **PDU** (function code + data) travels in different envelopes (ADU):

```text
PDU (≤ 253 bytes):                       [function code][data]
RTU (serial, binary):        [address][  function code  ][data][CRC-16]           <= 256 bytes
TCP (port 502):  [MBAP header 7 bytes][  function code  ][data]                   <= 260 bytes
```

| Variant | Transport | Framing / error check | Notes |
| --- | --- | --- | --- |
| **Modbus RTU** | RS-485 (or RS-232) | Silent gaps of 3.5 characters, CRC-16 | The most common serial form; see [Modbus_RTU.md](Modbus_RTU.md) |
| Modbus ASCII | Serial | `:` ... CR LF, hex characters, LRC | Rare; readable but about 2× slower |
| **Modbus TCP** | TCP, port 502 | MBAP header; TCP does error checking | No address byte and no CRC: the IP address selects the device |
| "RTU over TCP" | TCP or UDP socket | The complete RTU frame (address + CRC) inside the socket | Not in the specification, but common in serial-to-Ethernet converters. Both sides must use the same mode |
| Modbus TCP Security | TLS, port 802 | MBAP over TLS with certificates | Newer; supported by few devices |

### 1.1 Modbus TCP: the MBAP header

| Field | Size | Meaning |
| --- | --- | --- |
| Transaction ID | 2 | Chosen by the client, echoed by the server, to pair responses with requests |
| Protocol ID | 2 | `0` = Modbus |
| Length | 2 | Number of bytes that follow: Unit ID + PDU |
| Unit ID | 1 | Serial address of a device **behind a gateway**. For a device addressed directly by IP, usually `0xFF` (or `1`, as the device documents) |

Example: read 2 holding registers starting at offset 0:

```text
request:  00 01  00 00  00 06  FF  03  00 00  00 02
          trans  proto  len    uid fc  start  quantity
response: 00 01  00 00  00 07  FF  03  04  00 FA  01 2C        (2 registers: 250, 300)
```

Several clients can connect to one TCP server at the same time.
On a serial line, only one client may be active.

## 2. Data model

| Table | Element | Access | Read | Write single / multiple | Typical use |
| --- | --- | --- | --- | --- | --- |
| Coils | 1 bit | Read/write | `0x01` | `0x05` / `0x0F` | Relays, run/stop commands |
| Discrete inputs | 1 bit | Read-only | `0x02` | — | Limit switches, alarms |
| Input registers | 16 bit | Read-only | `0x04` | — | Measurements |
| Holding registers | 16 bit | Read/write | `0x03` | `0x06` / `0x10` | Setpoints, configuration, and in practice most data |

Other useful function codes: `0x17` read/write multiple registers in one transaction, `0x2B`/`0x0E` read device identification,
`0x08` diagnostics and `0x07`/`0x11` (serial only).

### 2.1 Addresses: documentation vs wire

Each table has addresses **0–65535** in the PDU (the "offset").
Manuals often use the old 1-based **reference numbers** with a table prefix instead:

| Reference | Table | Wire offset |
| --- | --- | --- |
| `00001`… | Coil | reference − 1 |
| `10001`… | Discrete input | reference − 10001 |
| `30001`… | Input register | reference − 30001 |
| `40001`… | Holding register | reference − 40001 (`40001` → `0x0000`, `40108` → `0x006B`) |

6-digit forms (`400001`) exist for addresses above 9999.
Some manuals list raw offsets instead, and others are off by one, so check with a known register (for example a serial number).

### 2.2 Limits per request

| Function | Max quantity |
| --- | --- |
| Read coils / discrete inputs (`0x01`, `0x02`) | 2000 bits |
| Read holding / input registers (`0x03`, `0x04`) | 125 registers |
| Write multiple coils (`0x0F`) | 1968 bits |
| Write multiple registers (`0x10`) | 123 registers |

Read larger blocks in several requests. Many devices allow even less, or don't allow a read across unmapped gaps.

### 2.3 Values larger than 16 bits

A register is 16 bits, sent **big-endian** (high byte first). Larger values use consecutive registers,
but the **word order** isn't standardized:

| Value | Registers (most common, "big-endian / ABCD") | Swapped words ("CDAB"), also common |
| --- | --- | --- |
| `float32 23.5` = `0x41BC0000` | `0x41BC`, `0x0000` | `0x0000`, `0x41BC` |
| `uint32 70000` = `0x00011170` | `0x0001`, `0x1170` | `0x1170`, `0x0001` |

Scaled integers are also common: `2345` with a documented scale of 0.01 = 23.45 °C.
SunSpec defines this formally with scale-factor registers ([Modbus_SunSpec.md](Modbus_SunSpec.md)).

## 3. Exceptions

On an error, the server answers with the function code + `0x80` and one exception code
(for example request `0x03` → response `0x83 0x02`):

| Code | Name | Usual cause |
| --- | --- | --- |
| `0x01` | Illegal function | The device doesn't support this function code |
| `0x02` | Illegal data address | Register not mapped, or the range crosses an unmapped gap |
| `0x03` | Illegal data value | Quantity out of range, or a value the device rejects |
| `0x04` | Server device failure | Internal error while executing |
| `0x05` / `0x06` | Acknowledge / server busy | Long operation started / try again later |
| `0x0A` / `0x0B` | Gateway path unavailable / target failed to respond | From a gateway: the serial device behind it didn't answer |

**No answer at all** (timeout) usually means a wrong address, wrong serial settings, a CRC error, or a broadcast. It's not an exception.

## 4. Limitations

+ **Polling only**: a server can't report events. The client must read often enough to catch changes.
+ **No security** in classic Modbus: no authentication and no encryption. Anyone who can reach port 502 can write registers.
  Keep it on isolated networks or behind a firewall or VPN.
  Modbus/TCP Security (TLS, port 802) exists, but few devices support it.
+ **No standard register map**: every vendor defines its own, except for profiles such as SunSpec.
+ Small payloads (≤ 125 registers per request): fine for process data, unsuitable for files or streams.

## Related notes

+ [Modbus_RTU.md](Modbus_RTU.md): serial framing, timing, CRC, RS-485 wiring, testing tools
+ [Modbus_SunSpec.md](Modbus_SunSpec.md): standardized register maps for solar inverters and DER
+ [IoT_Network.md](IoT_Network.md), [MQTT_intro.md](MQTT_intro.md)

## Reference

+ [Modbus Organization: specifications (Application Protocol V1.1b3, Messaging on TCP/IP, Serial Line V1.02)](https://www.modbus.org/specs.php)
