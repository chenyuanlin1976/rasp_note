# Linux command cheat sheet

Everyday commands on a Debian/Ubuntu host or a board (Raspberry Pi, Orange Pi, Jetson).

+ Text tools have their own notes: [grep_intro.md](grep_intro.md), [sed_intro.md](sed_intro.md), [awk_intro.md](awk_intro.md).
+ Shell syntax, including the standard streams (**0 stdin**, **1 stdout**, **2 stderr**) and redirection (`>`, `2>&1`, `|`),
  is in [bash_basic.md](bash_basic.md#8-input-output-redirection).

## 1. System information

```shell
man df                      # manual page (man -k keyword: search)
uname -a                    # kernel name, release, version, arch; -r: release only
cat /etc/os-release         # distribution and version
nproc                       # number of usable CPUs
lscpu; free -h              # CPU details; memory (RAM and swap)
uptime                      # load average
```

## 2. Hardware and kernel modules

```shell
lspci -nnk                  # PCI devices, IDs, kernel driver in use
lsusb; lsusb -t             # USB devices; as a tree with drivers
sudo lshw -C network        # hardware details by class
lsmod | grep iwlwifi        # loaded modules
modinfo iwlwifi             # parameters, firmware, version
sudo modprobe iwlwifi       # load, with dependencies (from /lib/modules/$(uname -r))
sudo modprobe -r iwlwifi    # unload
sudo insmod ./mydrv.ko      # load one .ko by path, no dependency handling (for development)
sudo dmesg -w | grep -i iwlwifi        # kernel log (follow)
```

`dkms` rebuilds out-of-tree modules automatically for new kernels. Module details: [../Linux/kernel_module.md](../Linux/kernel_module.md).

## 3. Processes

```shell
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head     # top memory users
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head     # top CPU users
top                         # interactive; Shift+M: sort by memory, Shift+P: by CPU
top -b -n 1 -o %MEM | head -n 15                      # one snapshot, for scripts
pgrep -a ssh; pkill -f myscript.sh                     # find / kill by name
kill -TERM "$pid"; kill -KILL "$pid"                   # ask to stop / force
```

## 4. Files

```shell
chown user:group file; chmod 640 file; chmod u+x script.sh
cmp file1 file2             # first differing byte (binary files)
diff -u file1 file2         # unified diff; diff -y: side by side
rsync -avu --delete /home/user/SRC/ /home/user/DEST     # see ../Linux/rsync_cmds.md
wget -c -i urls.txt         # resume downloads from a list; see ../Linux/wget_intro.md
```

Archives (`tar`, `zip`, ...): [../Linux/archive_compression.md](../Linux/archive_compression.md).

## 5. Find files and commands

| Command | Searches | Speed / freshness |
| --- | --- | --- |
| `command -v ls`, `type ls` | Commands as the shell resolves them (builtins, aliases, `PATH`) | Instant. Preferred in scripts |
| `which ls` | Executables in `PATH` | Instant |
| `whereis ls` | Binary, source, and man page in standard directories | Instant |
| `locate name` | A prebuilt database of file names (`plocate`/`mlocate`, refreshed by `updatedb`) | Instant, but misses new files |
| `find` | The real directory tree, by any criteria | Slow on large trees, always current |

```shell
find . -name '*.pdf'                      # quote the pattern so the shell doesn't expand it
find . -iname 'readme*'                   # case-insensitive
find /var/log -type f -mtime -1 -size +1M # modified in the last 24 h, larger than 1 MiB
find . -type d -exec chmod 755 {} +       # '+' passes many files per chmod ('\;' runs one per file)
find . -type f -exec chmod 644 {} +
```

## 6. Bytes and hex

```shell
printf '\x74\x24\xca\x38\xa3\xe1' > mac.bin   # write raw bytes (portable; 'echo -e' doesn't work in dash/sh)
xxd mac.bin                 # 00000000: 7424 ca38 a3e1   t$.8..
xxd -p mac.bin              # 7424ca38a3e1 (plain); xxd -g1: one byte per group
xxd -r -p hex.txt out.bin   # hex text back to binary
hexdump -C mac.bin          # 00000000  74 24 ca 38 a3 e1  |t$.8..|
hexdump mac.bin             # 0000000 2474 38ca e1a3   <- 16-bit words, little-endian: bytes look swapped
```

Use `hexdump -C` or `xxd`, which show bytes in file order. Plain `hexdump` (and `od -x`) groups bytes into host-endian 16-bit words.

Hashes and HMAC (`openssl dgst`), checksums: [../openssl_note.md](../openssl_note.md), [../checksumCmd.md](../checksumCmd.md).

## 7. Disks and file systems

```shell
df -h                       # free space per mounted file system
du -sh dir; du -h --max-depth=1 . | sort -h     # size of a directory / of each subdirectory
lsblk -f                    # block devices, partitions, file system types, mount points
sudo fdisk -l /dev/sdX      # partition table (fdisk /dev/sdX: edit it interactively)
sudo mkfs.ext4 -L data /dev/sdX1                # create an ext4 file system (mke2fs -t ext4)
sudo mount /dev/sdX1 /mnt; sudo umount /mnt
```

Double-check the device name with `lsblk` before `fdisk` or `mkfs`. They destroy data.

## 8. Network

Prefer the `iproute2` commands. `ifconfig`, `netstat`, and `arp` (net-tools) are deprecated and often not installed.

| Old (net-tools) | Current |
| --- | --- |
| `ifconfig` | `ip addr`, `ip link` |
| `route -n` | `ip route` |
| `arp -n` | `ip neigh` |
| `netstat -tulpn` | `ss -tulpn` |
| `iwconfig` | `iw dev`, `iw dev wlan0 link` |

```shell
ss -tulpn                   # listening TCP/UDP sockets with process (-p needs root for other users' sockets)
nmcli device; nmcli device wifi list    # NetworkManager
ping -c 4 8.8.8.8
```

More: [../network_cmds.md](../network_cmds.md).

## 9. Packages (Debian/Ubuntu)

```shell
sudo apt update && sudo apt upgrade
apt download build-essential                  # fetch a .deb into the current directory (no sudo)
sudo apt install ./build-essential_*.deb      # install a local file: './' is required, and apt resolves dependencies
sudo dpkg -i package.deb                      # low level: no dependency resolution (then: sudo apt -f install)
dpkg -L package; dpkg -S /usr/bin/xxd         # files of a package; which package owns a file
```

More: [../Linux/apt_dpkg_cmd.md](../Linux/apt_dpkg_cmd.md).

## 10. Date and time

```shell
date '+%F %T %Z %z'         # 2026-11-03 10:15:30 CST +0800
timedatectl                 # local time, time zone, NTP sync (systemd)
timedatectl list-timezones | grep Taipei
sudo timedatectl set-timezone Asia/Taipei
```

`date` formats and timestamps in scripts: [bash_recipes.md](bash_recipes.md#4-timestamps-and-delays).

## Related notes

+ [bash_basic.md](bash_basic.md), [bash_recipes.md](bash_recipes.md), [grep_intro.md](grep_intro.md)
+ [../Linux/rsync_cmds.md](../Linux/rsync_cmds.md), [../Linux/wget_intro.md](../Linux/wget_intro.md), [../Linux/apt_dpkg_cmd.md](../Linux/apt_dpkg_cmd.md)
+ [../Linux/kernel_module.md](../Linux/kernel_module.md), [../Linux/archive_compression.md](../Linux/archive_compression.md)
+ [../network_cmds.md](../network_cmds.md), [../openssl_note.md](../openssl_note.md), [../checksumCmd.md](../checksumCmd.md)

## Reference

+ [GNU coreutils manual](https://www.gnu.org/software/coreutils/manual/coreutils.html)
+ [man7.org: Linux man pages](https://man7.org/linux/man-pages/)
+ [iproute2 (ip, ss)](https://wiki.linuxfoundation.org/networking/iproute2)
