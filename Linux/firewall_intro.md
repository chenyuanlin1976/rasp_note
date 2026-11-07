# Linux firewalls: netfilter, nftables, iptables, ufw, firewalld

A Linux firewall is not one program. The packet filtering happens in the kernel (**netfilter**),
and user-space tools load rules into it. Several tools exist, but on one machine they all end up programming the same kernel hooks.

## 1. Layers

```text
 ufw            firewalld          <- front-ends: simple rules / zones
  │                 │
  ▼                 ▼
 iptables (iptables-nft)   nft     <- command-line tools that write rules
  │                         │
  ▼                         ▼
 kernel: nf_tables  (or legacy x_tables for iptables-legacy)
  │
  ▼
 netfilter hooks + connection tracking (conntrack)
```

+ **netfilter** is the kernel framework: hooks in the network stack where packets can be inspected, changed, dropped, or accepted,
  plus connection tracking.
+ The rule engines and their tools sit on top. A front-end only generates rules; the kernel does the filtering.

## 2. Rule engines and their tools

| | iptables | nftables |
| --- | --- | --- |
| Kernel side | `x_tables` (one module per table and match) | `nf_tables` (since Linux 3.13), a small rule VM |
| Tool | `iptables`, `ip6tables`, `arptables`, `ebtables` (one per protocol family) | `nft` for IPv4, IPv6, ARP, and bridge |
| Tables and chains | Fixed: tables `filter`, `nat`, `mangle`, `raw`; built-in chains `INPUT`, `OUTPUT`, `FORWARD`, `PREROUTING`, `POSTROUTING` | You create tables and chains and attach chains to hooks |
| Rule updates | Whole table replaced on each change | Atomic, incremental updates; sets and maps for large rule lists |
| Status | Legacy | The current framework |

`iptables` usually still works on a modern system: the `iptables-nft` variant accepts the old syntax and writes nftables rules.
`iptables -V` shows which one is installed (`(nf_tables)` or `(legacy)`).
Debian 10+ and Ubuntu 21.10+ use `iptables-nft` by default; firewalld uses nftables by default since RHEL 8.
Vendor board images can differ: a Jetson (L4T, Ubuntu 22.04 based) reports `iptables v1.8.7 (legacy)`. Check before assuming.

## 3. Front-ends

| Tool | Typical on | Model |
| --- | --- | --- |
| **ufw** | Ubuntu, Debian | Simple allow/deny rules per port, service, or address. See [ufw_cmds.md](ufw_cmds.md) |
| **firewalld** | Fedora, RHEL and its rebuilds (Rocky, AlmaLinux) | **Zones** (trust levels such as `public`, `home`, `trusted`) assigned to interfaces or source addresses; rules can change at run time (`firewall-cmd`) |

## 4. Key concepts

+ **Hooks and chains**: a packet passes different hooks depending on its path. Incoming to this host: `PREROUTING` → `INPUT`.
  Sent by this host: `OUTPUT` → `POSTROUTING`. Routed through it: `PREROUTING` → `FORWARD` → `POSTROUTING`.
+ **Tables**: group rules by purpose, for example filtering (`filter`) or address translation (`nat`).
+ **Rules are checked in order**, and the first matching rule that accepts or drops the packet decides.
+ **Default policy**: what happens when no rule matches. The usual baseline is deny incoming, allow outgoing.
+ **Stateful filtering**: conntrack tracks each connection's state (`NEW`, `ESTABLISHED`, `RELATED`, `INVALID`).
  A rule such as "accept `ESTABLISHED,RELATED`" lets replies to the host's own connections back in without an inbound rule per port.
  ufw and firewalld add this rule for you.

## 5. Which tool to use

+ **ufw**: Ubuntu/Debian desktops, boards, and simple servers.
+ **firewalld**: Fedora/RHEL family, or machines that move between networks and need zones.
+ **nft** directly: routers, gateways, NAT, or large rule sets, where you want full control (rules in `/etc/nftables.conf`).
+ **iptables**: only for old scripts and documentation; new rules should use nftables.

Use **one** firewall manager per machine. ufw and firewalld together, or hand-written `nft` rules next to a front-end, overwrite or contradict each other.
Docker and Kubernetes also insert their own rules (see [ufw_cmds.md](ufw_cmds.md#6-logging-and-pitfalls)).

## 6. See what is active

```shell
sudo nft list ruleset               # everything loaded into nf_tables (also rules written by iptables-nft, ufw, firewalld)
iptables -V                         # iptables v1.8.x (nf_tables) or (legacy)
sudo iptables -L -n -v              # iptables view of the filter table
sudo ufw status verbose             # if ufw is used
sudo firewall-cmd --state; sudo firewall-cmd --list-all   # if firewalld is used
systemctl status ufw firewalld nftables                    # which manager starts at boot
```

## Related notes

+ [ufw_cmds.md](ufw_cmds.md): ufw commands and pitfalls
+ [../network_cmds.md](../network_cmds.md), [ssh_login.md](ssh_login.md), [../docker_demo.md](../docker_demo.md)

## Reference

+ [netfilter project](https://www.netfilter.org/)
+ [nftables wiki](https://wiki.nftables.org/)
+ [Debian wiki: nftables](https://wiki.debian.org/nftables)
+ [firewalld documentation](https://firewalld.org/documentation/)
+ [ufw(8) man page (Ubuntu)](https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html)
