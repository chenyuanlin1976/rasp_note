# MAC addresses on an RK3566 Android board (Bluetooth, Wi-Fi, Ethernet)

This note explains how to read the Bluetooth, Wi-Fi, and Ethernet MAC addresses of an RK3566 board running Android 14, and how to tell whether an address is a real factory address or a locally administered (random or generated) one.

| Interface | Randomized by Android? | Typical result when no MAC is provisioned | Read it with |
| --- | --- | --- | --- |
| Bluetooth | No (the identity address is fixed; BLE privacy uses separate random addresses over the air) | The Bluetooth stack generates `22:22:xx:xx:xx:xx` once and keeps it | `dumpsys bluetooth_manager` |
| Wi-Fi | Yes, per network by default (Android 10+) | The Wi-Fi driver makes up a random MAC | `cat /sys/class/net/wlan0/address` |
| Ethernet | No | The kernel driver makes up a random MAC (often a new one each boot) | `cat /sys/class/net/eth0/address` |

## 1. Universally vs locally administered addresses

A MAC address has 6 bytes. The two lowest bits of the **first byte** say what kind of address it is:

| Bit (first byte) | Mask | 0 | 1 |
| --- | --- | --- | --- |
| b0 (I/G) | `0x01` | Unicast | Multicast |
| b1 (U/L) | `0x02` | **Universally administered** (UAA): first 3 bytes are a vendor OUI assigned by the IEEE | **Locally administered** (LAA): set by software or the integrator, not tied to a vendor |

Example: `22:22:49:23:0B:00`. The first byte `0x22` is `0010 0010` in binary, so b1 = 1 (locally administered) and b0 = 0 (unicast).

Shortcut: look at the **second hex digit** of the address.

| Second hex digit | Meaning | Example first bytes |
| --- | --- | --- |
| `0`, `4`, `8`, `C` | Universal, unicast (a normal factory MAC) | `00`, `04`, `20`, `D8` |
| `2`, `6`, `A`, `E` | Local, unicast (random, generated, or self-assigned) | `02`, `06`, `22`, `DA` |
| odd (`1`, `3`, ...) | Multicast; never a valid interface address | `01`, `33` |

Check it in a shell:

```shell
mac=22:22:49:23:0B:00
(( 0x${mac:0:2} & 0x02 )) && echo "locally administered" || echo "universally administered"
```

+ A locally administered address isn't wrong in itself. It only means nobody assigned a vendor OUI address to this interface.
+ For products, each interface should get a fixed address from the company's IEEE OUI block, written during manufacturing.

## 2. Where the MACs come from on Rockchip boards

Rockchip BSPs keep per-device data such as the serial number and the MAC addresses in **vendor storage**, a small area on the boot storage that survives reflashing the Android partitions.
In the Rockchip BSP kernel (`rk_vendor_storage.h`) the entries include `VENDOR_SN_ID` (1), `VENDOR_WIFI_MAC_ID` (2), `VENDOR_LAN_MAC_ID` (3), and `VENDOR_BT_MAC_ID` (4).
The factory writes them with Rockchip's PC tool (RKDevInfoWriteTool) in loader mode, or with a factory app through `/dev/vendor_storage`; see your BSP documentation for the exact tool and version.

```text
vendor storage (SN, WIFI MAC, LAN MAC, BT MAC)
        |
        +--> Wi-Fi driver (wlan0)       --- missing ---> random MAC from the driver
        +--> Ethernet driver (eth0)     --- missing ---> random MAC from the kernel
        +--> Bluetooth HAL / stack      --- missing ---> stack generates 22:22:xx:xx:xx:xx
```

+ Some Wi-Fi/Bluetooth modules also carry their own address in on-chip OTP. Which source wins depends on the BSP and the module driver.
+ An Ethernet MAC can also come from the device tree (`local-mac-address`) or from U-Boot (`ethaddr`).
+ Every fallback above produces a **locally administered** address. Seeing one usually means vendor storage wasn't written.

## 3. Bluetooth

Turn Bluetooth on, then ask the Bluetooth service (registered as `bluetooth_manager`):

```shell
adb shell svc bluetooth enable
adb shell 'dumpsys bluetooth_manager | grep -E "state:|address:"'
```

```text
  state: ON
  address: 22:22:49:23:0B:00
```

Other places that show the address:

```shell
adb shell settings get secure bluetooth_address            # cached copy, see below
adb shell getprop persist.service.bdroid.bdaddr            # generated fallback address, if any
adb root
adb shell grep -A3 '^\[Adapter\]' /data/misc/bluedroid/bt_config.conf   # "Address = ..."
```

+ `settings get secure bluetooth_address` isn't read from the hardware. `BluetoothManagerService` saves the address there after the adapter reports it, so it's the **last known** address, and it may be empty on a fresh device that never turned Bluetooth on.
+ An address that starts with **`22:22`** is the AOSP Bluetooth stack's fallback. When no address is provisioned (no `ro.bt.bdaddr_path` file and no stored property), the stack generates `22:22` + 4 random bytes, stores it in `persist.service.bdroid.bdaddr`, and keeps using it. So it stays the same across reboots, but it changes after a factory reset (a wipe of `/data`).
+ To get a real address, write the BT MAC into vendor storage (or the module's OTP) and make sure the Bluetooth HAL/vendor library passes it to the controller.
+ Settings UI: **Settings > About tablet > Bluetooth address** (the exact menu names vary by BSP). Bluetooth must be on.
+ BLE privacy (resolvable private addresses) changes the address that **other devices see** while advertising and connecting. The identity address shown above doesn't change. See [../../Comm/BLE_intro.md](../../Comm/BLE_intro.md).

## 4. Wi-Fi

Turn Wi-Fi on, then read the interface:

```shell
adb shell svc wifi enable
adb shell cat /sys/class/net/wlan0/address                 # MAC the interface uses right now
adb shell cat /sys/class/net/wlan0/addr_assign_type        # 0 = permanent, 1 = random, 3 = set by user space
adb shell ip link show wlan0                               # same MAC, on the "link/ether" line
adb shell 'dumpsys wifi | grep -iE "mac" | head -n 30'     # framework view; the format changes between releases
```

Since Android 10, Wi-Fi uses a **randomized MAC per network** by default:

+ For each saved network, the framework derives a random, locally administered MAC and sets it on `wlan0` before connecting. It stays the same for that network ("persistent" randomization).
  Android 12+ can also use non-persistent randomization, which changes the MAC more often for some networks.
+ Scans can also use a random MAC.
+ So the MAC on `wlan0` depends on the network you're connected to, and it's usually locally administered even when the board has a factory MAC.

To see or use the device (factory) MAC:

1. **Settings > About tablet** (or **Status**) shows the device Wi-Fi MAC address. The label differs between releases and BSPs.
2. **Settings > Network & internet > Internet**, tap the gear next to the network, **Privacy > Use device MAC**. Reconnect, then `cat /sys/class/net/wlan0/address` shows the device MAC.

If the device MAC is itself locally administered or changes after a reboot, vendor storage has no Wi-Fi MAC and the driver generated one.
Apps without the right permissions get `02:00:00:00:00:00` from the Wi-Fi APIs; that is a placeholder, not the real address.

## 5. Ethernet

Android doesn't randomize the Ethernet MAC. `eth0` uses what the driver got from vendor storage, the device tree, or U-Boot (Rockchip boards use the `dwmac-rk` glue of the stmmac driver).

```shell
adb shell ip link                                          # find the interface name (eth0 on most boards)
adb shell cat /sys/class/net/eth0/address
adb shell cat /sys/class/net/eth0/addr_assign_type         # 0 = permanent, 1 = random
adb shell ip addr show eth0                                # MAC on "link/ether", plus the IP address
adb shell dumpsys ethernet                                 # interfaces tracked by the Ethernet service
```

+ With no MAC from any source, the kernel picks a random one (`eth_random_addr()`), which is always locally administered and is usually different on every boot.
+ A custom init script, or `ip link set eth0 address ...` as root, can also set a local address. See [../../Linux/Network/network_cmds.md](../../Linux/Network/network_cmds.md).
+ Some BSPs show the Ethernet MAC under **Settings > Network & internet > Ethernet**. If yours doesn't, use the commands above.

## 6. Check that the MACs are fixed

A factory MAC is universally administered **and** survives a reboot. Run this before and after `adb reboot` (for Wi-Fi, connect to a network that uses **Use device MAC**, or read the device MAC from Settings):

```shell
for i in eth0 wlan0; do
  echo "$i: $(adb shell cat /sys/class/net/$i/address) type=$(adb shell cat /sys/class/net/$i/addr_assign_type)"
done
adb shell 'dumpsys bluetooth_manager | grep "address:"'
```

| Result | Meaning |
| --- | --- |
| Universal address, same after reboot | Provisioned factory MAC |
| Local address, same after reboot | Generated once and stored (e.g. Bluetooth `22:22:...`), or set by a script |
| Local address, new after every reboot | Not provisioned; the driver makes one up at each boot |

## Related notes

+ [check_peripherals.md](check_peripherals.md): bring-up checks for Bluetooth, Wi-Fi, and Ethernet
+ [adb_intro.md](adb_intro.md), [adb_shell_cmds.md](adb_shell_cmds.md)
+ [../AOSP_cfg/wifi_default.md](../AOSP_cfg/wifi_default.md), [../AOSP_cfg/SettingsProvider_intro.md](../AOSP_cfg/SettingsProvider_intro.md)
+ [../../Linux/Network/network_cmds.md](../../Linux/Network/network_cmds.md), [../../Linux/HW/sysfs_intro.md](../../Linux/HW/sysfs_intro.md)
+ [../../Comm/BLE_intro.md](../../Comm/BLE_intro.md), [../../Comm/WoL_intro.md](../../Comm/WoL_intro.md)

## Reference

+ [MAC randomization behavior (AOSP)](https://source.android.com/docs/core/connect/wifi-mac-randomization-behavior)
+ [Bluetooth (AOSP)](https://source.android.com/docs/core/connect/bluetooth)
+ [dumpsys](https://developer.android.com/tools/dumpsys)
+ [sysfs ABI, including `sysfs-class-net` (`address`, `addr_assign_type`) (kernel docs)](https://docs.kernel.org/admin-guide/abi-testing.html)
+ [IEEE Registration Authority (OUI assignments)](https://standards.ieee.org/products-programs/regauth/)
+ Rockchip BSP documentation for vendor storage and RKDevInfoWriteTool (ships with the SDK)
