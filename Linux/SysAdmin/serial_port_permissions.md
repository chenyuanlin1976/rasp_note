# Serial port permissions on a Linux PC

When a PC talks to a board over a serial port (a USB-to-UART adapter, a USB CDC device, or a built-in UART), a normal user often gets `Permission denied` when opening the port.
This note explains why, compares the fixes, and lists the other common reasons a serial port won't open.

## 1. Why "Permission denied" happens

Serial ports are character devices under `/dev`:

| Device | What it is |
| --- | --- |
| `/dev/ttyS*` | Built-in UART (PC motherboard, or the SoC UART on a board) |
| `/dev/ttyUSB*` | USB-to-UART adapter with a vendor driver: FTDI (`ftdi_sio`), CP210x (`cp210x`), CH340 (`ch341`), PL2303 (`pl2303`) |
| `/dev/ttyACM*` | USB CDC ACM device: Raspberry Pi Pico, STM32 virtual COM port, Arduino boards with native USB |

udev creates these files when the device appears. On Debian, Ubuntu, and Fedora they belong to `root` and the group `dialout` with mode `0660` (Arch uses the group `uucp`):

```shell
ls -l /dev/ttyUSB0
# crw-rw---- 1 root dialout 188, 0 Nov 18 10:00 /dev/ttyUSB0
id -nG                       # groups of the current session
```

Only `root` and members of `dialout` can read and write the port.
A normal user running picocom, minicom, a pyserial script, or a flashing tool gets `Permission denied`.

## 2. Fixes compared

| Fix | Scope | Lasts | Use when |
| --- | --- | --- | --- |
| Join `dialout` (§3) | All serial ports, for one user | Permanent | Your own development machine (recommended) |
| `chmod 666` (§4) | One device file, for every user | Until unplug or reboot | A quick test on a machine you don't want to change |
| udev rule (§5) | Selected devices (by USB ID) | Permanent | A fixed name, a different group or mode, or desktop-user access |

Running every tool with `sudo` also works, but then the tool and the files it writes run as root. Avoid it.

## 3. Join the `dialout` group (recommended)

```shell
sudo usermod -aG dialout "$USER"     # -a = append; without it, the user is removed from other groups
```

+ Group membership is read at login, so **log out and back in** (or reboot). A new terminal tab isn't enough, because it inherits the desktop session's groups.
+ To use the new group in the current shell only: `newgrp dialout`.
+ Check with `id -nG`; the list must contain `dialout`.
+ After that, every serial port the system creates is accessible without `sudo`, including adapters plugged in later.

## 4. `chmod` the device (temporary)

```shell
sudo chmod 666 /dev/ttyUSB0          # rw for owner, group, and others
```

+ Every user on the machine can now open the port, not only you.
+ udev recreates the device file when the adapter is replugged or the PC reboots, and the permissions return to `root:dialout 0660`. You then have to run `chmod` again.

## 5. udev rule (per device)

A udev rule sets the group, mode, or a stable name for specific devices.
Find the USB vendor and product IDs with `lsusb` (e.g. `1a86:7523` for a CH340), or see every attribute with `udevadm info -a -n /dev/ttyUSB0`.

```text
# /etc/udev/rules.d/99-usb-serial.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", GROUP="dialout", MODE="0660", SYMLINK+="ttyCH340"
```

```shell
sudo udevadm control --reload        # then replug the adapter, or:
sudo udevadm trigger --subsystem-match=tty
ls -l /dev/ttyCH340                  # -> ttyUSB0
```

+ To give access to whoever is logged in at the local desktop (not ssh users), use `TAG+="uaccess"` instead of `GROUP`/`MODE`. systemd-logind applies it through an ACL. The rule file must sort before `73-seat-late.rules`, e.g. `70-usb-serial.rules`.
+ Without a custom rule, `/dev/serial/by-id/` already gives stable names (vendor, product, serial number).

## 6. Other reasons a port won't open

| Symptom | Cause | Fix |
| --- | --- | --- |
| Still `Permission denied` after `usermod` | Session started before the change | Log out and in; check `id -nG` |
| `/dev/ttyUSB0` appears and disappears right away (Ubuntu, CH340 adapters) | `brltty` (braille display daemon) claims the adapter; `dmesg` shows `interface 0 claimed by ch341 while 'brltty' sets config` | `sudo apt remove brltty` if you don't use a braille display |
| `Device or resource busy` | Another program has the port open | `sudo fuser -v /dev/ttyUSB0`, then close that program |
| `ttyACM` device gets random AT commands at plug-in | ModemManager probes it | udev rule with `ENV{ID_MM_DEVICE_IGNORE}="1"`, see [USB_CDC.md](../../Comm/USB_CDC.md#3-linux-host) |
| Port name changes (`ttyUSB0` ↔ `ttyUSB1`) | Order of detection | Use `/dev/serial/by-id/...` or a udev `SYMLINK` (§5) |
| No `/dev/tty*` at all | Driver missing or adapter not detected | `sudo dmesg -w` while plugging in; check `lsusb` |

## Related notes

+ [../../Comm/USB_CDC.md](../../Comm/USB_CDC.md): CDC ACM devices (`ttyACM*`) and USB serial drivers
+ [../../Android/Debug/uart_console.md](../../Android/Debug/uart_console.md): using a USB-to-UART adapter as the board's debug console
+ [../../Comm/Modbus_RTU.md](../../Comm/Modbus_RTU.md): RS-485 over USB serial adapters
+ [apt_dpkg_cmds.md](apt_dpkg_cmds.md): removing packages such as `brltty`

## Reference

+ [udev(7) man page](https://manpages.debian.org/stable/udev/udev.7.en.html)
+ [usermod(8) man page](https://manpages.debian.org/stable/passwd/usermod.8.en.html)
+ [Debian wiki: System groups (`dialout`)](https://wiki.debian.org/SystemGroups)
+ [ArchWiki: udev](https://wiki.archlinux.org/title/Udev)
