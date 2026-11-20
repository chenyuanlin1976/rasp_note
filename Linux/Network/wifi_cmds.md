# Wi-Fi commands on Linux

Wireless networking on Linux has three layers you work with:

+ **NetworkManager** (`nmcli`): everyday connections on desktops, many servers, and Raspberry Pi OS since Bookworm.
+ **cfg80211 / nl80211** (`iw`): low-level diagnostics and scanning. `iw` talks to the kernel's `cfg80211` subsystem over the `nl80211` netlink interface.
+ **`wpa_supplicant`**: WPA/WPA2/WPA3 authentication. NetworkManager runs it in the background; on headless or minimal systems you configure it yourself.

The older wireless-tools commands `iwconfig` and `iwlist` (Wireless Extensions) are deprecated in favor of `iw` and `nmcli`.

## 1. Quick reference

| Task | Current command | Legacy / alternative | What it does |
| --- | --- | --- | --- |
| Wi-Fi status / toggle | `nmcli radio wifi`, `nmcli dev status` | | Whether Wi-Fi is on, devices and connection state |
| Scan networks | `nmcli dev wifi list`, `iw dev <iface> scan` | `iwlist <iface> scan` | Nearby SSIDs, signal, channel, security |
| Connect / disconnect | `nmcli dev wifi connect <SSID> --ask` | `wpa_supplicant` | Join or leave a network |
| Link and signal | `iw dev <iface> link` | `iwconfig <iface>` | SSID, BSSID, frequency, bitrate, signal (dBm) |
| Driver capabilities | `iw list` | | Supported bands, modes, channels |
| Radio blocks | `rfkill list` | | Hardware/software RF blocks |

## 2. Connections with NetworkManager (`nmcli`)

```shell
nmcli radio wifi                     # enabled / disabled
nmcli radio wifi on                  # turn the radio on ('off' to turn off)
nmcli dev wifi list --rescan yes     # scan: SSID, signal, security
nmcli dev wifi connect "MyWiFi" --ask            # prompt for the password
nmcli dev wifi connect "MyWiFi" password "secret"  # non-interactive (password lands in shell history)
nmcli connection show                # saved connection profiles
nmcli dev disconnect wlan0           # disconnect wlan0
```

Saved profiles are stored in `/etc/NetworkManager/system-connections/` and reconnect automatically.

## 3. Low-level inspection and scanning (`iw`)

Use `iw` for exact signal strength, channel/frequency, or scanning without NetworkManager:

```shell
iw dev                               # wireless interfaces, type (managed/AP/monitor)
iw dev wlan0 link                    # current AP, signal (dBm), TX/RX bitrate
iw dev wlan0 station dump            # per-station counters (retries, failures)
sudo iw dev wlan0 scan | grep -E "SSID:|signal:|freq:"   # raw scan (needs root)
iw list                              # driver capabilities: bands, modes, channels
```

Signal in dBm (closer to 0 is stronger):

| Signal | Quality |
| --- | --- |
| -30 to -50 dBm | Excellent |
| about -67 dBm | Good enough for streaming and VoIP |
| -70 to -80 dBm | Weak, unstable throughput |
| below -80 dBm | Unreliable |

## 4. Radio blocks (`rfkill`)

If Wi-Fi refuses to turn on, check whether it is blocked (airplane-mode key, BIOS switch, or a regulatory setting):

```shell
rfkill list                          # soft/hard block status for Wi-Fi and Bluetooth
sudo rfkill unblock wifi             # remove the soft block
```

A hard block is a physical switch or firmware setting; `rfkill unblock` cannot clear it.
On Raspberry Pi OS, Wi-Fi stays soft-blocked until the Wi-Fi country is set (`sudo raspi-config` → Localisation Options → WLAN Country).

## 5. Headless setup without NetworkManager (`wpa_supplicant`)

On minimal systems where NetworkManager isn't running, `wpa_supplicant` performs the WPA handshake and a DHCP client gets the address:

```shell
wpa_passphrase "MyWiFi" "secret" | sudo tee /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
sudo dhcpcd wlan0                    # or 'dhclient wlan0', or systemd-networkd
```

+ `tee` overwrites the file. `wpa_passphrase` also writes the plain-text passphrase as a `#psk=` comment; delete that line and `chmod 600` the file.
+ With systemd, the per-interface file name lets you start it as a service: `sudo systemctl enable --now wpa_supplicant@wlan0`.
+ ISC `dhclient` is end-of-life; prefer `dhcpcd` or `systemd-networkd` on new setups.
+ Don't run a manual `wpa_supplicant` while NetworkManager manages the same interface; they fight over it.

## 6. Diagnostic tips

+ Check the kernel log for driver or firmware errors when an interface disappears or drops packets:

  ```shell
  sudo dmesg | grep -iE "iwlwifi|ath|rtw|mt76|brcmfmac|wifi|firmware"
  ```

  (`brcmfmac` is the driver for the Raspberry Pi on-board Wi-Fi.)
+ Check the interface name first: it may be `wlan0`, `wlp2s0`, or `wlx<mac>` for USB adapters. Use `ip link` or `iw dev` instead of assuming `wlan0`.
+ Check the band: 2.4 GHz is crowded and only channels 1, 6, and 11 don't overlap. The `freq:` value in `iw dev <iface> link` shows whether you are on 2.4, 5, or 6 GHz.
+ General IP, DNS, and routing problems: [network_troubleshoot.md](network_troubleshoot.md).

## Related notes

+ [network_troubleshoot.md](network_troubleshoot.md): `ip`, `ss`, `ping`, `dig`, `curl`, `tcpdump`
+ [network_cmds.md](network_cmds.md): `ip` vs `ifconfig`, `ip neigh` vs `arp`, PPPoE
+ [ssh_login.md](ssh_login.md): log in to a headless board once Wi-Fi is up

## Reference

+ [Linux wireless documentation (wireless.wiki.kernel.org)](https://wireless.wiki.kernel.org/en/users/documentation/iw)
+ [nmcli(1)](https://networkmanager.dev/docs/api/latest/nmcli.html)
+ [wpa_supplicant](https://w1.fi/wpa_supplicant/)
+ [Raspberry Pi documentation: configuration (networking)](https://www.raspberrypi.com/documentation/computers/configuration.html)
