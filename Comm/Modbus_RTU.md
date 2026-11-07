# Modbus RTU (serial line)

Modbus RTU sends the Modbus PDU as **binary** bytes over a serial line, usually **RS-485**.
The protocol layer (function codes, data model, exceptions) is in [Modbus_intro.md](Modbus_intro.md).
This note covers the serial framing, timing, CRC, wiring, and testing on Linux.

## 1. Frame

```text
[address 1][function code 1][data 0..252][CRC 2, low byte first]       max 256 bytes
```

| Field | Size | Notes |
| --- | --- | --- |
| Address | 1 byte | Server address **1–247**. `0` = broadcast (writes only; no server answers). 248–255 are reserved |
| Function code | 1 byte | `0x03` read holding registers, `0x10` write multiple registers, ... |
| Data | 0–252 bytes | Function-specific: start address, quantity, byte count, values (all 16-bit values big-endian) |
| CRC | 2 bytes | CRC-16/MODBUS, sent **low byte first** |

There is no length field and no start character. A frame is delimited by **silence** on the line.

Example: read 2 holding registers at offset 0 from server 1 (CRC values computed with the code in section 3):

```text
request:   01 03 00 00 00 02 C4 0B                 addr fc start=0 qty=2 crc
response:  01 03 04 00 FA 01 2C DA 4F              4 data bytes: 250, 300
exception: 01 83 02 C0 F1                          0x80|fc, code 02 = illegal data address
```

## 2. Serial settings and timing

+ **Character format**: 8 data bits, 1 start bit, **even parity**, 1 stop bit (8E1) is the default in the specification.
  Without parity, the spec asks for 2 stop bits (8N2). Many devices use 8N1 anyway.
  Every device on the bus must use the same settings.
+ **Baud rate**: 9600 and 19200 are the most common (19200 is the spec's default).
+ **Frame gap**: at least **3.5 character times** of silence between frames.
  Inside a frame, a gap longer than 1.5 characters makes the frame invalid.
+ Above 19200 baud, the spec fixes the gaps at **1.75 ms** (frame) and **750 µs** (inter-character).

| Baud (11 bits per character) | 1 character | 3.5 characters |
| --- | --- | --- |
| 9600 | 1.15 ms | 4.0 ms |
| 19200 | 0.57 ms | 2.0 ms |
| 115200 | 0.095 ms | 1.75 ms (fixed) |

On Linux, user space can't time these gaps precisely. Libraries (libmodbus, pymodbus) detect the end of a frame by a short timeout
and by the expected response length. USB-serial adapters add latency; FTDI's latency timer defaults to 16 ms.

A server that receives a frame with a **wrong CRC** discards it and doesn't answer, so the client sees a **timeout**, not an exception.

## 3. CRC-16/MODBUS

Polynomial `0x8005` processed bit-reversed (`0xA001`), initial value `0xFFFF`, no final XOR.
The check value for the ASCII string `"123456789"` is `0x4B37`.

```c
#include <stddef.h>
#include <stdint.h>

/* CRC-16/MODBUS. Append the result as (crc & 0xFF), then (crc >> 8). */
uint16_t modbus_crc16(const uint8_t *buf, size_t len)
{
    uint16_t crc = 0xFFFF;

    for (size_t i = 0; i < len; i++) {
        crc ^= buf[i];
        for (int bit = 0; bit < 8; bit++)
            crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
    return crc;
}
```

For `01 03 00 00 00 02` it returns `0x0BC4`, which is sent as `C4 0B`.
Running the CRC over a whole received frame including its CRC bytes gives `0` when the frame is intact.

## 4. RS-485 wiring

| Topic | Rule |
| --- | --- |
| Topology | **Daisy chain** (bus) with short stubs. No star wiring |
| Pairs | A/B (D−/D+) on a twisted pair, plus a common/ground reference wire |
| Termination | 120 Ω across A/B at **both ends** of the cable only |
| Biasing | Pull-up/pull-down resistors at **one** point keep the idle line in a defined state |
| Length / speed | Up to about 1200 m at low rates (≤ 100 kbit/s); shorter at higher baud rates |
| Load | 32 standard unit loads per segment; more with 1/4 or 1/8 unit-load transceivers, or with repeaters |
| Naming | A/B labels are swapped between some vendors: if nothing answers, try swapping A and B |

RS-485 is **half-duplex**: the transmitter must be enabled (DE) only while sending.
Either the transceiver or the USB adapter switches automatically, or the UART driver does it with RTS:

```c
#include <linux/serial.h>
#include <sys/ioctl.h>

struct serial_rs485 rs485 = { 0 };
rs485.flags = SER_RS485_ENABLED | SER_RS485_RTS_ON_SEND;   /* RTS high while transmitting */
if (ioctl(fd, TIOCSRS485, &rs485) < 0)
    perror("TIOCSRS485");                                   /* driver has no RS-485 support */
```

In the device tree, the UART node can enable it at boot: `linux,rs485-enabled-at-boot-time;`, plus `rs485-rts-active-low;` / `rs485-rts-delay` as needed.

## 5. Testing on Linux

`mbpoll` is a command-line Modbus client (`apt install mbpoll`):

```shell
# read 2 holding registers, references 1-2 (= offsets 0-1), once
mbpoll -m rtu -a 1 -b 9600 -P even -t 4 -r 1 -c 2 -1 /dev/ttyUSB0
mbpoll -m rtu -a 1 -b 9600 -P none -s 2 -t 4 -r 1 -c 2 -1 /dev/ttyUSB0   # 8N2 device
mbpoll -m rtu -a 1 -b 9600 -t 4 -r 10 /dev/ttyUSB0 1234                  # write 1234 to reference 10
mbpoll -m tcp -a 1 -t 4:float -r 1 -c 2 -1 192.168.1.50                  # Modbus TCP, two floats
```

`mbpoll` counts references from **1** by default. Use `-0` for 0-based PDU offsets.

Without hardware, connect a client and a server simulator through a **virtual serial pair**:

```shell
socat -d -d pty,raw,echo=0,link=/tmp/ttyV0 pty,raw,echo=0,link=/tmp/ttyV1
# server simulator on /tmp/ttyV1, client (mbpoll -m rtu ... /tmp/ttyV0) on the other end
```

### 5.1 Why a TX–RX jumper on one port doesn't work

+ The client and the server program would both have to open the **same** port.
  The OS gives a serial port to one program at a time (Windows refuses; on Linux both read the same data and the result is meaningless).
+ A loopback only returns the **request itself**. Nobody parses it and builds a response, so the client gets back its own frame (or a timeout).

Use 2 ports (two USB adapters wired A-to-A, B-to-B, or TX-to-RX for RS-232), or the virtual pair above.

## Related notes

+ [Modbus_intro.md](Modbus_intro.md), [Modbus_SunSpec.md](Modbus_SunSpec.md)
+ [USB_CDC.md](USB_CDC.md), [../Linux/dts_provider_consumer.md](../Linux/dts_provider_consumer.md)

## Reference

+ [Modbus Organization: specifications (Modbus over Serial Line V1.02)](https://www.modbus.org/specs.php)
+ [RS485 serial communications (Linux kernel docs)](https://docs.kernel.org/driver-api/serial/serial-rs485.html)
+ [mbpoll](https://github.com/epsilonrt/mbpoll)
