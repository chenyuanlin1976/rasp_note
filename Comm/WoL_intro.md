# Wake-on-LAN (WoL) and the magic packet

**Wake-on-LAN (WoL)** is an industry-standard way to power on a computer, or wake it from sleep, with a network message.
Even when the computer looks switched off, the motherboard keeps a small standby supply on the network interface card (NIC), so the NIC can keep listening for that message.
The message is called a **magic packet**.

## 1. The magic packet

A magic packet contains a fixed, easy-to-recognize pattern:

| Part | Content | Size |
| --- | --- | --- |
| Synchronization stream | `FF FF FF FF FF FF` (6 bytes of all ones) | 6 bytes |
| Target MAC address | The 6-byte MAC address of the target NIC, repeated **16 times** | 16 × 6 = 96 bytes |
| Total | | 6 + 96 = **102 bytes** |

Example for MAC `00:11:22:33:44:55`:

```text
FF FF FF FF FF FF
00 11 22 33 44 55   <- repeated 16 times
00 11 22 33 44 55
...
00 11 22 33 44 55
```

The NIC doesn't parse IP or UDP. It scans the whole received frame for this pattern, so the pattern can be carried in any frame:

+ **UDP datagram** (most common), usually to port **9** (discard) or **7** (echo).
+ **Raw Ethernet frame** with EtherType `0x0842`.

Some NICs also support a **SecureOn** password: 4 or 6 extra bytes appended after the 16 MAC repetitions.

## 2. How it works

1. **Listening mode:** Before the PC enters sleep or shutdown, the operating system (and the BIOS/UEFI for a full shutdown) leaves the NIC powered in a low-power state, watching for a magic packet with its own MAC address.
2. **Transmission:** Another device on the LAN sends the magic packet. A sleeping PC has no usable IP address, and its address may change through DHCP anyway, so the packet is sent as a **broadcast** to the whole subnet: either the limited broadcast `255.255.255.255` or the subnet's directed broadcast (e.g. `192.168.1.255`).
3. **Match:** Every NIC on the subnet receives the broadcast. Only the NIC whose MAC address appears 16 times in the payload reacts; all others ignore it.
4. **Power on:** The matching NIC signals the motherboard, through the PCI/PCIe power-management event (`PME#`) or, on older boards, a dedicated 3-pin WOL cable, and the power supply turns the system fully on.

```text
 sender (PC / phone / Raspberry Pi)
        |
        |  UDP broadcast, port 9: FF*6 + MAC*16
        v
 +-------------- LAN switch --------------+
        |                    |
   other NIC            target NIC (standby power)
   pattern != own MAC   pattern == own MAC
   -> ignore            -> PME# -> motherboard -> power on
```

## 3. Requirements and limitations

+ **Hardware/firmware:** The NIC and motherboard must support WoL, and it must be enabled in the BIOS/UEFI (often called "Wake on LAN", "Power On by PCI-E", or "Resume by LAN"). Some boards disable it in deep power-saving modes such as "ErP" or "Deep Sleep".
+ **OS driver setting:** The OS must leave WoL armed when it shuts down or suspends (see section 4).
+ **Wired Ethernet:** WoL works over wired Ethernet. Wi-Fi has a separate mechanism (Wake on Wireless LAN, WoWLAN) with much more limited support, and it usually doesn't work from a full shutdown.
+ **Same broadcast domain:** Routers don't forward broadcasts by default, so the sender normally has to be on the same subnet. Waking from another network needs a directed broadcast forwarded by the router, or an always-on device on the LAN (e.g. a Raspberry Pi) that you reach through SSH or VPN and that sends the packet locally.
+ **Power loss:** If the PC loses mains power completely (the PSU is switched off or unplugged), the NIC has no standby power and can't be woken.
+ **No reply:** The magic packet is fire-and-forget. The sender gets no acknowledgment; check by pinging the target after it boots.

## 4. Enabling WoL on a Linux target

Check and set WoL with `ethtool` (replace `enp3s0` with your interface name):

```shell
sudo ethtool enp3s0 | grep -i wake
#   Supports Wake-on: pumbg
#   Wake-on: d

sudo ethtool -s enp3s0 wol g   # g = wake on magic packet
```

| Flag | Meaning |
| --- | --- |
| `p` | Wake on PHY activity |
| `u` | Wake on unicast messages |
| `m` | Wake on multicast messages |
| `b` | Wake on broadcast messages |
| `a` | Wake on ARP |
| `g` | Wake on magic packet |
| `s` | Enable SecureOn password for magic packet |
| `d` | Disable (wake on nothing) |

The `ethtool` setting is lost at reboot on many drivers. Make it persistent with the network manager in use:

```shell
# NetworkManager
nmcli connection modify "<connection name>" 802-3-ethernet.wake-on-lan magic
```

```text
# systemd-networkd / udev: /etc/systemd/network/50-wol.link
[Match]
MACAddress=00:11:22:33:44:55

[Link]
NamePolicy=kernel database onboard slot path
WakeOnLan=magic
```

On Windows, enable "Wake on Magic Packet" in the NIC's Device Manager properties (Advanced and Power Management tabs). Windows "Fast Startup" can prevent WoL from a full shutdown on some systems.

Note down the target's MAC address (`ip link show enp3s0`); the sender needs it.

## 5. Sending a magic packet

From Linux (for example an always-on Raspberry Pi):

```shell
# wakeonlan (UDP, default port 9, broadcast 255.255.255.255)
sudo apt install wakeonlan
wakeonlan 00:11:22:33:44:55
wakeonlan -i 192.168.1.255 00:11:22:33:44:55   # directed broadcast

# etherwake (raw Ethernet frame, EtherType 0x0842; needs root)
sudo apt install etherwake
sudo etherwake -i eth0 00:11:22:33:44:55
```

Minimal Python sender:

```python
import socket

def wake(mac: str, broadcast: str = "255.255.255.255", port: int = 9) -> None:
    mac_bytes = bytes.fromhex(mac.replace(":", "").replace("-", ""))
    if len(mac_bytes) != 6:
        raise ValueError("MAC address must be 6 bytes")
    packet = b"\xff" * 6 + mac_bytes * 16          # 102 bytes
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(packet, (broadcast, port))

wake("00:11:22:33:44:55")
```

To verify that packets reach the target (while it's still running), capture on the target:

```shell
sudo tcpdump -i enp3s0 -XX 'udp port 9 or ether proto 0x0842'
```

## Related notes

+ [IoT_Network.md](IoT_Network.md): Wi-Fi, Zigbee, Thread, LoRa and other IoT networks
+ [../Linux/network_cmds.md](../Linux/network_cmds.md): `ip`, `arp` and other network commands
+ [../Linux/socket_intro.md](../Linux/socket_intro.md): sockets, including UDP
+ [../Linux/ssh_login.md](../Linux/ssh_login.md): SSH into an always-on sender to wake PCs remotely

## Reference

+ [Wikipedia: Wake-on-LAN](https://en.wikipedia.org/wiki/Wake-on-LAN)
+ [ethtool(8) man page](https://man7.org/linux/man-pages/man8/ethtool.8.html)
+ [systemd.link(5): WakeOnLan=](https://www.freedesktop.org/software/systemd/man/latest/systemd.link.html)
+ [NetworkManager: nm-settings-nmcli(5)](https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html)
