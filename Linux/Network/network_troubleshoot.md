# Network troubleshooting commands

Modern Linux networking is built around the `iproute2` suite (`ip`, `ss`), which replaces the net-tools commands (`ifconfig`, `route`, `netstat`, `arp`).
With a handful of tools you can check interfaces, test connectivity, list open ports, debug DNS, make HTTP requests, and capture packets.
Configuring interfaces (`ip` vs `ifconfig`, `ip neigh` vs `arp`, PPPoE) is in [network_cmds.md](network_cmds.md).

## 1. Quick reference

| Task | Current command | Legacy / alternative | What it does |
| --- | --- | --- | --- |
| Interfaces and IPs | `ip addr`, `ip link` | `ifconfig` | Interfaces, link state, MAC and IP addresses |
| Routing table | `ip route` | `route -n` | Routes and the default gateway |
| Sockets and ports | `ss -tulnp` | `netstat -tulnp` | Listening TCP/UDP ports and their processes |
| Reachability | `ping <host>` | | ICMP echo: latency and packet loss |
| Path tracing | `traceroute`, `mtr` | `tracepath` | Each hop between the host and a destination |
| DNS lookup | `dig`, `resolvectl` | `nslookup`, `host` | DNS records (`A`, `AAAA`, `MX`, `TXT`) and resolver status |
| HTTP / transfers | `curl` | `wget` | HTTP(S) requests, headers, downloads |
| Packet capture | `tcpdump` | `tshark` | Capture and filter raw traffic on an interface |

## 2. Interfaces and IP addresses (`ip`)

Check whether interfaces are up, which IPv4/IPv6 addresses they have, and where the default route points:

```shell
ip a                        # short for 'ip addr show': addresses and link state
ip -br a                    # one line per interface
ip route show default       # default gateway
sudo ip link set eth0 up    # bring an interface up ('down' to disable)
```

Check the interface name first (`ip link`); it may be `eth0`, `end0`, `enp3s0`, etc.

## 3. Listening ports and connections (`ss`)

`ss` (socket statistics) is fast and detailed.
Flags: `-t` TCP, `-u` UDP, `-l` listening, `-n` numeric addresses and ports, `-p` owning process.

```shell
sudo ss -tulnp              # listening TCP/UDP ports with processes
ss -tn state established    # established TCP connections
ss -s                       # summary by socket state
```

Without root, `-p` shows only your own processes.

## 4. Connectivity and latency (`ping`, `traceroute`, `mtr`)

Start with `ping` to confirm basic reachability and round-trip time (RTT). If traffic is lost or slow on the way, trace the path:

```shell
ping -c 4 1.1.1.1           # 4 packets to Cloudflare DNS
traceroute example.com
mtr -r -c 10 example.com    # ping + traceroute, report mode with 10 cycles
```

+ Many hosts and routers drop ICMP or traceroute probes, so a timeout does not always mean the host is down.
+ Public DNS servers that are handy ping targets: Cloudflare `1.1.1.1`, Google `8.8.8.8` / `8.8.4.4`, Chunghwa Telecom (HiNet) `168.95.1.1` / `168.95.192.1`.
+ `ping 1.1.1.1` works but `ping example.com` fails → the problem is DNS, not routing.
+ `traceroute` and `mtr` are often separate packages (`sudo apt install traceroute mtr-tiny`).

## 5. DNS (`dig`, `resolvectl`)

When a hostname resolves to the wrong address, or not at all, query DNS directly:

```shell
dig example.com +short          # A record (IP address)
dig example.com MX +short       # mail exchange records
dig @1.1.1.1 example.com        # ask a specific server, bypassing the local resolver
resolvectl status               # DNS servers per link (systemd-resolved only)
```

+ `dig` is in the `dnsutils` / `bind9-dnsutils` package on Debian/Ubuntu.
+ `resolvectl` works only when `systemd-resolved` is running; otherwise read `/etc/resolv.conf`.

## 6. HTTP requests and downloads (`curl`)

`curl` checks web endpoints, HTTP status codes, TLS, and response headers from the terminal:

```shell
curl -I https://example.com                     # response headers only (HEAD request)
curl -v https://example.com 2>&1 | head -n 25   # verbose: connection and TLS handshake
curl -o file.bin https://example.com/file.bin   # download to a file
```

Some servers answer `HEAD` differently from `GET`; use `curl -s -D - -o /dev/null <url>` to see the headers of a real `GET`.
Downloading with `wget`: [wget_cmds.md](wget_cmds.md).

## 7. Packet capture (`tcpdump`)

Use it to see the actual packets, for example to check whether a request reaches the interface at all:

```shell
sudo tcpdump -i eth0 -n port 443         # HTTPS traffic on eth0
sudo tcpdump -i any -nn host 8.8.8.8     # traffic to/from 8.8.8.8 on all interfaces
sudo tcpdump -i eth0 -w cap.pcap         # save to a file for Wireshark
```

`-n` skips name lookups for addresses; `-nn` also shows port numbers instead of service names.

## 8. Habits that save time

+ Prefer `ip` and `ss` over `ifconfig` and `netstat`: minimal distributions often don't install `net-tools`, while `iproute2` is standard.
+ Use `-n` while troubleshooting: skipping reverse DNS keeps output fast and avoids hangs during a DNS outage.
+ Check both the service and the firewall: a service can listen on `0.0.0.0:8080` and still be blocked by `ufw`, `nftables`/`iptables`, or a cloud security group.
  A service bound to `127.0.0.1:8080` is reachable only from the same host.
+ Wi-Fi specific problems (signal, scan, authentication): [wifi_cmds.md](wifi_cmds.md).

## Related notes

+ [network_cmds.md](network_cmds.md): `ip` vs `ifconfig`, `ip neigh` vs `arp`, PPPoE
+ [wifi_cmds.md](wifi_cmds.md): `nmcli`, `iw`, `rfkill`, `wpa_supplicant`
+ [uri_url_intro.md](uri_url_intro.md): URI and URL syntax
+ [firewall_intro.md](firewall_intro.md), [ufw_cmds.md](ufw_cmds.md), [wget_cmds.md](wget_cmds.md), [socket_intro.md](socket_intro.md)
+ [../../shellScript/linux_cmds.md](../../shellScript/linux_cmds.md): command cheat sheet

## Reference

+ [iproute2 (Linux Foundation wiki)](https://wiki.linuxfoundation.org/networking/iproute2)
+ [ip(8)](https://man7.org/linux/man-pages/man8/ip.8.html), [ss(8)](https://man7.org/linux/man-pages/man8/ss.8.html)
+ [curl documentation](https://curl.se/docs/)
+ [tcpdump man page](https://www.tcpdump.org/manpages/tcpdump.1.html)
