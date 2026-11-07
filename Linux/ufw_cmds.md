# ufw (Uncomplicated Firewall) commands

`ufw` is a simple command-line front-end for the kernel's netfilter firewall on Ubuntu and Debian.
It writes iptables rules for you; on current Ubuntu/Debian, `iptables` itself uses the nftables backend.
How ufw relates to iptables, nftables, and firewalld: [firewalls_intro.md](firewalls_intro.md).

## 1. Set up safely

```shell
sudo apt install ufw
sudo ufw default deny incoming      # baseline: block unsolicited inbound traffic
sudo ufw default allow outgoing     #           allow everything outbound
sudo ufw allow ssh                  # BEFORE enabling, or a remote session locks you out
sudo ufw enable                     # applies now and at every boot
```

The firewall is stateful: replies to connections the machine opened are allowed in without an extra rule.

## 2. Status and control

```shell
sudo ufw status verbose             # on/off, default policies, rules
sudo ufw status numbered            # rules with their numbers (for delete / insert)
sudo ufw reload                     # re-read the rule files
sudo ufw disable                    # stop filtering (rules are kept)
sudo ufw reset                      # disable and delete all rules (backups are written to /etc/ufw/)
```

## 3. Rules by port or service

```shell
sudo ufw allow 80                   # TCP and UDP
sudo ufw allow 80/tcp               # one protocol
sudo ufw allow 6000:6007/tcp        # port range (needs a protocol)
sudo ufw allow http                 # service name from /etc/services
sudo ufw app list                   # application profiles installed by packages (/etc/ufw/applications.d)
sudo ufw allow OpenSSH              # allow by application profile
sudo ufw deny 23                    # drop silently; "reject" answers with an error instead
sudo ufw limit ssh                  # deny an IP that opens 6 or more connections in 30 seconds
```

## 4. Rules by source address

```shell
sudo ufw allow from 192.168.1.100                                     # all ports from one host
sudo ufw allow from 192.168.1.100 to any port 3306                    # one port from one host
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp           # SSH from the LAN only
sudo ufw allow in on eth0 to any port 80                              # only on one interface
sudo ufw insert 1 deny from 203.0.113.50                              # block a host (see section 5)
```

## 5. Rule order and deleting rules

Rules are checked **in order, and the first match wins**. `allow` and `deny` append to the end of the list,
so a `deny from 203.0.113.50` added after `allow ssh` doesn't block that host's SSH connections.
Use `insert 1` to put a blocking rule first.

```shell
sudo ufw status numbered            # find the number
sudo ufw delete 3                   # delete by number (numbers shift after each delete)
sudo ufw delete allow 80            # or repeat the rule after "delete"
```

## 6. Logging and pitfalls

```shell
sudo ufw logging on                 # blocked packets go to /var/log/ufw.log (and the kernel log)
sudo tail -f /var/log/ufw.log
```

+ IPv6 rules are created only if `IPV6=yes` in `/etc/default/ufw` (the default on Ubuntu).
+ Docker publishes container ports with its own iptables rules, which **bypass ufw**. A `-p 8080:80` container is reachable even if ufw denies 8080.
  Publish on `127.0.0.1` only (`-p 127.0.0.1:8080:80`) or use Docker's `DOCKER-USER` chain.
+ Before enabling ufw on a remote board or server, check the SSH rule with `sudo ufw show added`.

## Related notes

+ [firewalls_intro.md](firewalls_intro.md): netfilter, iptables, nftables, firewalld, ufw
+ [ssh_login.md](ssh_login.md), [../network_cmds.md](../network_cmds.md), [../docker_demo.md](../docker_demo.md)

## Reference

+ [ufw(8) man page (Ubuntu)](https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html)
+ [Ubuntu community wiki: UFW](https://help.ubuntu.com/community/UFW)
+ [Docker: packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
