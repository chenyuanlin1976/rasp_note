# Sockets and ports on Linux

A **socket** is an endpoint for communication between processes, on the same machine or over a network.
To the program it is a **file descriptor**: `read()`/`write()` (or `recv()`/`send()`) and `close()` work on it, as with files.

## 1. Socket types

| Domain (`socket()` 1st argument) | Addresses | Typical use |
| --- | --- | --- |
| `AF_INET` / `AF_INET6` | IPv4 / IPv6 address + port | Network services (HTTP, Modbus TCP, MQTT) |
| `AF_UNIX` (= `AF_LOCAL`) | A path in the file system, or an abstract name | Local IPC (`/run/...sock`, Android `/dev/socket/...`) |
| `AF_NETLINK`, `AF_PACKET`, `AF_CAN`, `AF_BLUETOOTH` | Kernel-specific | Talking to the kernel, raw Ethernet, SocketCAN, Bluetooth |

| Type (2nd argument) | Semantics |
| --- | --- |
| `SOCK_STREAM` | Reliable, ordered byte stream (TCP over IP). No message boundaries: the receiver must frame the data |
| `SOCK_DGRAM` | Separate datagrams (UDP over IP). Boundaries are kept, but delivery and order aren't guaranteed over IP |
| `SOCK_SEQPACKET` | Reliable and ordered, with message boundaries (`AF_UNIX`, SCTP) |

## 2. System call sequence (TCP)

```text
server                                  client
socket()                                socket()
bind(addr:port)
listen(backlog)
accept()  <------- 3-way handshake ---- connect(server addr:port)
read()/write()  <---- data ---->        write()/read()
close()                                 close()
```

UDP has no `listen`/`accept`/`connect` step: `sendto()`/`recvfrom()` work with an address per datagram.

## 3. Ports

An IP address selects a machine (interface). A **port** (16-bit, 0–65535) selects a socket on it.
The kernel finds the socket for a packet from the protocol, the local address and port, and, for TCP connections, also the remote address and port.

| Range | IANA name | Linux behavior |
| --- | --- | --- |
| 0–1023 | Well-known (22 SSH, 80 HTTP, 443 HTTPS, 502 Modbus TCP) | `bind()` needs `CAP_NET_BIND_SERVICE` (root), below `net.ipv4.ip_unprivileged_port_start` (default 1024) |
| 1024–49151 | Registered | Free to use. Services register numbers with IANA (1883 MQTT, 8883 MQTT/TLS) |
| 49152–65535 | Dynamic / ephemeral | Linux picks client ports from `net.ipv4.ip_local_port_range`, **32768–60999** by default |

```shell
sysctl net.ipv4.ip_local_port_range net.ipv4.ip_unprivileged_port_start
ss -tlnp                         # listening TCP sockets with their processes (iproute2)
ss -tunap                        # all TCP/UDP sockets
nc -l 5000                       # quick TCP server on port 5000 (OpenBSD netcat)
nc 192.168.1.10 5000             # client
socat - TCP:192.168.1.10:502     # raw TCP connection (e.g. to a Modbus TCP device)
```

To let a non-root service use a port below 1024: `sudo setcap cap_net_bind_service=+ep /usr/local/bin/mysvc`,
or the `AmbientCapabilities=CAP_NET_BIND_SERVICE` setting in a systemd unit.

## Related notes

+ [../network_cmds.md](../network_cmds.md), [../Modbus_intro.md](../Modbus_intro.md), [../MQTT_intro.md](../MQTT_intro.md)
+ [../shellScript/shellCmd_note.md](../shellScript/shellCmd_note.md)

## Reference

+ `man 7 socket`, `man 7 ip`, `man 7 tcp`, `man 7 udp`, `man 7 unix`: [man7.org](https://man7.org/linux/man-pages/man7/socket.7.html)
+ [IANA service name and port number registry](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml)
