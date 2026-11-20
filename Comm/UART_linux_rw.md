# Reading and writing a UART on Linux

A program talks to an external UART device (a module, an MCU, a modem) through a tty device node.
It opens the node, sets the line parameters (baud rate, data bits, parity, stop bits) and raw mode with `termios`, then uses ordinary `read()` and `write()`.

## 1. Find the device node

| Node | Typical device |
| --- | --- |
| `/dev/ttyUSB*` | USB-to-UART adapter (FTDI, CP210x, CH340, PL2303) |
| `/dev/ttyACM*` | USB CDC ACM device (Pico, STM32 virtual COM port), see [USB_CDC.md](USB_CDC.md) |
| `/dev/ttyS*`, `/dev/ttyAMA*` | On-chip UART of the PC or board (`ttyAMA*` on Raspberry Pi PL011) |

```shell
ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null
sudo dmesg | grep -iE 'tty|usb-serial|ch341|cp210|ftdi' | tail -n 15
ls -l /dev/serial/by-id/            # stable names for USB adapters
```

If opening the node gives `Permission denied`, add the user to the `dialout` group; see [../Linux/SysAdmin/serial_port_permissions.md](../Linux/SysAdmin/serial_port_permissions.md).

## 2. Quick test from the shell

Interactive terminal (8N1, no flow control):

```shell
picocom -b 115200 --databits 8 --parity n --stopbits 1 --flow n /dev/ttyUSB0
# exit: Ctrl+A, then Ctrl+X
```

Without a terminal program, set the port with `stty` and use `cat` / `printf`:

```shell
stty -F /dev/ttyUSB0 115200 cs8 -cstopb -parenb raw -echo
cat /dev/ttyUSB0 &                  # print what the device sends
printf 'AT\r\n' > /dev/ttyUSB0      # send a command
kill %1
```

Garbled characters usually mean a wrong baud rate; no output at all usually means swapped TX/RX or a missing ground.

## 3. C program with `termios`

Put the port in **raw mode** (`cfmakeraw()`). Otherwise the tty layer treats some bytes specially: it translates `\r` to `\n`, echoes input, sends a signal on `0x03` (Ctrl+C), and handles `0x11`/`0x13` as XON/XOFF. That breaks binary protocols.

```c
/* uart_rw.c */
#define _DEFAULT_SOURCE          /* cfmakeraw() and CRTSCTS are not in strict POSIX */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

static int configure_uart(int fd, speed_t baud)
{
    struct termios tty;

    if (tcgetattr(fd, &tty) != 0) {
        perror("tcgetattr");
        return -1;
    }

    cfmakeraw(&tty);
    cfsetispeed(&tty, baud);
    cfsetospeed(&tty, baud);

    /* 8N1, no hardware flow control, enable receiver, ignore modem control lines */
    tty.c_cflag &= ~(CSIZE | PARENB | CSTOPB | CRTSCTS);
    tty.c_cflag |= CS8 | CREAD | CLOCAL;

    /* read() returns as soon as 1 byte arrives, or after 1.0 s with 0 bytes */
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        perror("tcsetattr");
        return -1;
    }
    tcflush(fd, TCIOFLUSH);      /* drop stale bytes received before configuration */
    return 0;
}

static int write_all(int fd, const char *buf, size_t len)
{
    while (len > 0) {
        ssize_t w = write(fd, buf, len);
        if (w < 0) {
            if (errno == EINTR)
                continue;
            perror("write");
            return -1;
        }
        buf += w;
        len -= (size_t)w;
    }
    return 0;
}

int main(int argc, char **argv)
{
    const char *path = (argc > 1) ? argv[1] : "/dev/ttyUSB0";

    int fd = open(path, O_RDWR | O_NOCTTY);   /* O_NOCTTY: don't become our controlling tty */
    if (fd < 0) {
        perror("open");
        return EXIT_FAILURE;
    }

    if (configure_uart(fd, B115200) != 0 || write_all(fd, "PING\r\n", 6) != 0) {
        close(fd);
        return EXIT_FAILURE;
    }

    /* Collect bytes until a newline or a 1 s gap */
    char buf[256];
    size_t used = 0;
    while (used < sizeof(buf) - 1) {
        ssize_t n = read(fd, buf + used, sizeof(buf) - 1 - used);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            perror("read");
            break;
        }
        if (n == 0)                            /* VTIME timeout */
            break;
        used += (size_t)n;
        if (memchr(buf, '\n', used) != NULL)
            break;
    }
    buf[used] = '\0';

    if (used == 0)
        printf("Timed out waiting for response\n");
    else
        printf("Received (%zu bytes): %s\n", used, buf);

    close(fd);
    return EXIT_SUCCESS;
}
```

```shell
gcc -Wall -Wextra -O2 uart_rw.c -o uart_rw
./uart_rw /dev/ttyUSB0
```

### 3.1 `VMIN` and `VTIME` (raw mode)

`VTIME` is in tenths of a second.

| `VMIN` | `VTIME` | `read()` behavior |
| --- | --- | --- |
| 0 | 0 | Returns immediately with what is available (possibly 0) |
| 0 | > 0 | Returns when a byte arrives, or 0 after `VTIME` |
| > 0 | 0 | Blocks until `VMIN` bytes have arrived |
| > 0 | > 0 | Blocks for the first byte, then returns after `VMIN` bytes or a `VTIME` gap between bytes |

For several ports or other events at the same time, use `poll()` on the file descriptors instead of relying on `VTIME`.

## 4. Practical tips

+ **Wiring**: TX of one side to RX of the other, RX to TX, and a common GND. Check that the voltage levels match (3.3 V vs 5 V vs RS-232).
+ **Byte stream, no packets**: one `read()` can return 1 byte or half a message. Frame messages with a delimiter (`\n`), a length prefix, or a silence timeout, as in the loop above.
+ **Line endings**: many modules and AT modems expect `\r\n`, some only `\r` or `\n`; check the device's protocol.
+ **Write completion**: `write()` returns when the data is in the kernel buffer. Call `tcdrain(fd)` to wait until it has actually been sent, e.g. before switching an RS-485 transceiver (see [Modbus_RTU.md](Modbus_RTU.md)).
+ **Baud rates**: use the `B<rate>` constants. Linux defines high rates such as `B1500000` (the RK3566 debug console rate).
+ **Console conflicts**: if the UART is also the kernel console or runs a `getty` login (`/dev/ttyS0`, `/dev/ttyAMA0`, `/dev/ttyFIQ0`), console output mixes with your data. Disable the console on that port first; see [../Android/Debug/uart_console.md](../Android/Debug/uart_console.md).

## Related notes

+ [../Linux/SysAdmin/serial_port_permissions.md](../Linux/SysAdmin/serial_port_permissions.md): `dialout` group, udev rules, port busy errors
+ [USB_CDC.md](USB_CDC.md): `ttyACM*` devices and USB serial drivers
+ [Modbus_RTU.md](Modbus_RTU.md): a binary protocol over UART / RS-485
+ [../Android/Debug/uart_console.md](../Android/Debug/uart_console.md): UART as the board's debug console

## Reference

+ `termios(3)`: <https://man7.org/linux/man-pages/man3/termios.3.html>
+ `stty(1)`: <https://man7.org/linux/man-pages/man1/stty.1.html>
+ Linux serial drivers and tty layer: <https://docs.kernel.org/driver-api/serial/index.html>
