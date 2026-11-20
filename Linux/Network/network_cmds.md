# Network configuration commands: ip, ifconfig, arp, PPPoE

This note covers configuring interfaces and the neighbor (ARP) table, with both the current `iproute2` commands and the legacy net-tools commands (`ifconfig`, `arp`).
For diagnosing problems (`ss`, `ping`, `traceroute`, `dig`, `curl`, `tcpdump`) see [network_troubleshoot.md](network_troubleshoot.md). For Wi-Fi (`nmcli`, `iw`), see [wifi_cmds.md](wifi_cmds.md).

## 1. Interfaces: `ip` (current)

`ip` comes from the `iproute2` package, which every current distribution installs.

```shell
ip addr show                                   # all interfaces, up or down, with addresses
ip addr show eth0                              # one interface
ip link show up                                # only interfaces that are up
sudo ip link set eth0 down                     # disable
sudo ip link set eth0 up                       # enable
sudo ip addr add 192.168.1.10/24 dev eth0      # add an address (existing ones stay)
sudo ip addr del 192.168.1.10/24 dev eth0      # remove it
sudo ip link set eth0 mtu 1500                 # MTU
sudo ip link set eth0 address 00:1a:2b:3c:4d:5e   # MAC (most drivers need the link down first)
```

Changes made with `ip` are lost at reboot. Make them permanent in NetworkManager (`nmcli`), netplan, systemd-networkd, or `/etc/network/interfaces`, depending on the distribution.

## 2. Interfaces: `ifconfig` (legacy)

`ifconfig` is in the deprecated `net-tools` package, which minimal systems often don't install. It doesn't show all addresses when an interface has several.

| Task | `ifconfig` | `ip` |
| --- | --- | --- |
| Active interfaces | `ifconfig` | `ip link show up` |
| All interfaces | `ifconfig -a` | `ip addr show` |
| One interface | `ifconfig eth0` | `ip addr show eth0` |
| Disable / enable | `sudo ifconfig eth0 down` / `up` | `sudo ip link set eth0 down` / `up` |
| Set IP and netmask | `sudo ifconfig eth0 192.168.1.10 netmask 255.255.255.0` | `sudo ip addr add 192.168.1.10/24 dev eth0` |
| MTU | `sudo ifconfig eth0 mtu 1500` | `sudo ip link set eth0 mtu 1500` |
| MAC address | `sudo ifconfig eth0 hw ether 00:1a:2b:3c:4d:5e` | `sudo ip link set eth0 address 00:1a:2b:3c:4d:5e` |

`ifconfig eth0 <ip>` replaces the primary address, while `ip addr add` adds one.

## 3. Neighbor (ARP) table

The ARP table maps IPv4 addresses on the local network to MAC addresses. `ip neigh` also shows IPv6 neighbors.

| Task | `ip neigh` (current) | `arp` (legacy) |
| --- | --- | --- |
| Show the table | `ip neigh show` | `arp -n` (`arp -a` for BSD-style output) |
| Only one interface | `ip neigh show dev eth0` | `arp -n -i eth0` |
| Delete an entry | `sudo ip neigh del 192.168.1.50 dev eth0` | `sudo arp -d 192.168.1.50` |
| Add a static entry | `sudo ip neigh add 192.168.1.50 lladdr 00:11:22:33:44:55 dev eth0 nud permanent` | `sudo arp -s 192.168.1.50 00:11:22:33:44:55` |
| Flush | `sudo ip neigh flush all` | (none) |

Without `-n`, `arp` tries reverse DNS for every entry, which is slow.

## 4. PPPoE (DSL) connections

PPPoE (Point-to-Point Protocol over Ethernet) is used by DSL and some fiber providers. On Debian/Ubuntu the `pppoeconf` and `ppp` packages provide:

```shell
sudo pppoeconf          # interactive: detect the modem, ask for user/password, write the config
sudo pon dsl-provider   # start the connection (pppd in the background)
plog                    # last lines of the PPP log
ip addr show ppp0       # the PPP interface and its address
sudo poff               # stop the connection
```

On systems with NetworkManager, a PPPoE ("DSL") connection can also be created with `nmcli connection add type pppoe ...`.

## Related notes

+ [network_troubleshoot.md](network_troubleshoot.md): `ss`, `ping`, `traceroute`, `dig`, `curl`, `tcpdump`
+ [wifi_cmds.md](wifi_cmds.md): `nmcli`, `iw`, `rfkill`, `wpa_supplicant`
+ [uri_url_intro.md](uri_url_intro.md): URI and URL syntax
+ [firewall_intro.md](firewall_intro.md), [ssh_login.md](ssh_login.md), [socket_intro.md](socket_intro.md)
+ [../../shellScript/linux_cmds.md](../../shellScript/linux_cmds.md): command cheat sheet

## Reference

+ [iproute2 (Linux Foundation wiki)](https://wiki.linuxfoundation.org/networking/iproute2)
+ [ip-address(8)](https://man7.org/linux/man-pages/man8/ip-address.8.html), [ip-link(8)](https://man7.org/linux/man-pages/man8/ip-link.8.html), [ip-neighbour(8)](https://man7.org/linux/man-pages/man8/ip-neighbour.8.html)
+ [Debian wiki: PPPoE](https://wiki.debian.org/PPPoE)
