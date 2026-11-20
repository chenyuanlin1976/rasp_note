# MAC addresses on an RK3566 Android board (Bluetooth, Wi-Fi, Ethernet)

This note explains how to read the Bluetooth, Wi-Fi, and Ethernet MAC addresses of an RK3566 board running Android 14, how to tell whether an address is a real factory address or a locally administered (random or generated) one, and how a platform-signed app can read the factory addresses (section 7).

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

+ Some Wi-Fi/Bluetooth modules also carry their own address in on-chip OTP. Which source wins depends on the BSP and the module driver; for Broadcom/Cypress (AP6xxx) Bluetooth see `USE_CONTROLLER_BDADDR` in section 3.1.
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
+ To get a real address, write the BT MAC into vendor storage (or the module's OTP) and make sure the Bluetooth HAL/vendor library passes it to the controller (section 3.1).
+ Settings UI: **Settings > About tablet > Bluetooth address** (the exact menu names vary by BSP). Bluetooth must be on.
+ BLE privacy (resolvable private addresses) changes the address that **other devices see** while advertising and connecting. The identity address shown above doesn't change. See [../../Comm/BLE_intro.md](../../Comm/BLE_intro.md).

### 3.1 Controller address vs host address (`USE_CONTROLLER_BDADDR`)

The address that `dumpsys bluetooth_manager` reports is the one the **controller** (the Bluetooth chip) returns: after the chip starts, the stack reads it with the HCI `Read_BD_ADDR` command and saves it as the adapter address.
Which address the chip holds at that point is decided by the vendor library (`libbt-vendor.so`) that sets up the chip, on BSPs whose Bluetooth HAL loads one (the HIDL 1.x default HAL does).

`USE_CONTROLLER_BDADDR` is a build option of the Broadcom/Cypress vendor library ([`hardware/broadcom/libbt`](https://android.googlesource.com/platform/hardware/broadcom/libbt/)), which also drives AP6xxx Wi-Fi/Bluetooth modules.
It isn't an option of the Bluetooth stack (Bluedroid/Fluoride) itself.

```text
host address (from the HAL: ro.bt.bdaddr_path file or a bdaddr property,
              e.g. persist.service.bdroid.bdaddr)
        |
        v
libbt-vendor, after the firmware download
        |-- USE_CONTROLLER_BDADDR = FALSE: write the host address into the chip (vendor HCI command)
        |-- USE_CONTROLLER_BDADDR = TRUE:  Read_BD_ADDR; keep the chip's own (OTP) address if it isn't
        |                                  00:00:00:00:00:00, otherwise write the host address
        v
chip BD_ADDR --HCI Read_BD_ADDR--> Bluetooth stack --> dumpsys bluetooth_manager
```

| `USE_CONTROLLER_BDADDR` | Chip has an address in OTP | Chip has no address (all zeros) |
| --- | --- | --- |
| `FALSE` (default) | Overwritten by the host address | Host address |
| `TRUE` | OTP address is kept | Host address |

+ Use `TRUE` when the module vendor programs a unique address into each chip, and `FALSE` when the factory writes the address on the host side (for example into vendor storage, section 2).
+ With `TRUE`, the library only checks for all zeros. A module that ships with the **same** dummy address in OTP makes every board use that address, and boards near each other then conflict when pairing.
+ With `FALSE` and no host address provisioned, the chip gets the stack's generated `22:22:xx:xx:xx:xx` address (section 3).

The default is set in `include/bt_vendor_brcm.h`. A board overrides it in its `include/vnd_<device>.txt` file (a line like `USE_CONTROLLER_BDADDR = TRUE`), which the build turns into the generated `vnd_buildcfg.h`. BSPs often carry their own copy of the library, so search the whole tree:

```shell
# in the AOSP/BSP source tree
grep -rn USE_CONTROLLER_BDADDR hardware/ device/ vendor/

# on the device: the vendor library logs the address it reads or writes while Bluetooth starts
adb logcat -c
adb shell svc bluetooth disable; adb shell svc bluetooth enable
adb logcat -d | grep -iE "bt_hwcfg|bd_?addr"
```

Compare the result with `dumpsys bluetooth_manager` and with a second board: the address should be non-zero, match the source you expect (OTP or provisioned), and differ between boards.

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

## 7. Read the factory MACs from a platform-signed app

Normal apps can't read the real addresses:

+ Since Android 6, `BluetoothAdapter.getAddress()` and `WifiInfo.getMacAddress()` return the placeholder `02:00:00:00:00:00` to apps without `LOCAL_MAC_ADDRESS`.
+ Since Android 11, SELinux blocks the netlink query behind `NetworkInterface.getHardwareAddress()` for apps targeting API 30+, so it returns `null`.

An app signed with the device's **platform key** gets the signature permissions that unlock the real addresses.
The APIs return whatever the driver or Bluetooth stack reports, so on a board without provisioned MACs they still return the locally administered fallbacks from section 2.
To pass the addresses on to a customer's app that isn't platform-signed, wrap these functions in a system app's bound service; see [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md#6-example-device-info-and-bluetooth-control).

| Interface | API | Permissions | Notes |
| --- | --- | --- | --- |
| Bluetooth | `BluetoothAdapter.getAddress()` | `LOCAL_MAC_ADDRESS`, plus `BLUETOOTH_CONNECT` on Android 12+ | `BLUETOOTH_CONNECT` is a runtime permission; the platform key doesn't grant it |
| Wi-Fi | `WifiManager.getFactoryMacAddresses()` (`@SystemApi`, Android 10+) | `NETWORK_SETTINGS` | `WifiInfo.getMacAddress()` returns the MAC in use, which is usually randomized |
| Ethernet | `/sys/class/net/eth0/address`, then `NetworkInterface` | none; SELinux decides | Not randomized, so the address in use is the device address |

### 7.1 Manifest and signing

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.deviceinfo">
    <!-- Optional: android:sharedUserId="android.uid.system" runs the app as UID 1000 -->

    <!-- Signature permissions: granted because the APK is signed with the platform key -->
    <uses-permission android:name="android.permission.LOCAL_MAC_ADDRESS" />
    <uses-permission android:name="android.permission.NETWORK_SETTINGS" />

    <!-- Bluetooth: legacy permission up to Android 11, runtime permission on Android 12+ -->
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
</manifest>
```

+ Sign the APK with the platform key of the image that's flashed on the device (the certificate of the `android` package); see [../Signing/sign_apk.md](../Signing/sign_apk.md). A test-key APK on a release-key build gets none of these permissions.
+ The APK doesn't have to be preinstalled in `/system/priv-app`. A plain `adb install` to `/data/app` gets the signature permissions too, as long as the certificate matches.
+ Without `sharedUserId` the app runs in the SELinux domain `platform_app`. With `android:sharedUserId="android.uid.system"` it runs as UID 1000 in `system_app`, which passes almost every permission check but is deprecated since API 29 and can't be removed from an installed app later. See [../Signing/sharedUserId.md](../Signing/sharedUserId.md) and [../SELinux/SELinux_domains.md](../SELinux/SELinux_domains.md).

### 7.2 Bluetooth

`BluetoothAdapter.getAddress()` checks `LOCAL_MAC_ADDRESS`; without it the call returns `02:00:00:00:00:00`.
On Android 12+ it also needs `BLUETOOTH_CONNECT` and throws `SecurityException` without it.

```kotlin
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.content.Context

@SuppressLint("HardwareIds", "MissingPermission")
fun getBluetoothMacAddress(context: Context): String? {
    val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter ?: return null
    val mac = try {
        adapter.address
    } catch (e: SecurityException) {   // BLUETOOTH_CONNECT not granted (Android 12+)
        null
    }
    return mac?.takeIf { it.isNotBlank() && it != "02:00:00:00:00:00" }?.uppercase()
}
```

+ Ways to get `BLUETOOTH_CONNECT`: request it at runtime (apps with UI), pre-grant it for a preinstalled app with a default-permissions XML in `/system/etc/default-permissions/`, use `android.uid.system`, or for testing run `adb shell pm grant com.example.deviceinfo android.permission.BLUETOOTH_CONNECT`.
+ When Bluetooth is off, the call returns the last known address that `BluetoothManagerService` cached (the same value as `settings get secure bluetooth_address`, see section 3). On a device that never turned Bluetooth on it can be `null`.

### 7.3 Wi-Fi

Don't use `WifiInfo.getMacAddress()`: even with `LOCAL_MAC_ADDRESS` it returns the MAC on `wlan0` right now, which is the per-network randomized MAC (section 4).
`WifiManager.getFactoryMacAddresses()` returns the device MAC of each Wi-Fi interface and requires `NETWORK_SETTINGS`.

It's a `@SystemApi`, so it isn't in the public SDK.
In an Android Studio project, call it through reflection; apps signed with the platform key are exempt from the non-SDK interface restrictions.
In the AOSP tree, build the app with `platform_apis: true` (or `sdk_version: "system_current"`) and call `wifiManager.factoryMacAddresses` directly.

```kotlin
import android.content.Context
import android.net.wifi.WifiManager

fun getWifiFactoryMacAddress(context: Context): String? {
    return try {
        val wifiManager = context.applicationContext.getSystemService(WifiManager::class.java)
        val method = WifiManager::class.java.getMethod("getFactoryMacAddresses")
        val macs = method.invoke(wifiManager) as? Array<*>
        (macs?.firstOrNull() as? String)?.uppercase()
    } catch (e: Exception) {
        // NoSuchMethodException, or InvocationTargetException wrapping a
        // SecurityException when NETWORK_SETTINGS isn't granted
        null
    }
}
```

### 7.4 Ethernet

Android has no permission for the Ethernet MAC; access depends on SELinux.
Read sysfs first, since it works whether a cable is plugged in or not, and fall back to `NetworkInterface`.

```kotlin
import java.io.File
import java.net.NetworkInterface

fun getEthernetMacAddress(ifname: String = "eth0"): String? {
    // 1. sysfs: needs SELinux read access to sysfs_net for the app's domain
    try {
        val mac = File("/sys/class/net/$ifname/address").readText().trim()
        if (mac.isNotEmpty()) return mac.uppercase()
    } catch (_: Exception) {
        // file missing or access denied; try the next method
    }

    // 2. NetworkInterface: blocked for untrusted_app (targetSdk 30+), works for platform_app/system_app
    return try {
        NetworkInterface.getByName(ifname)
            ?.hardwareAddress
            ?.joinToString(":") { "%02X".format(it) }
    } catch (_: Exception) {
        null
    }
}
```

+ `NetworkInterface.getByName()` returns `null` if no interface has that name. Check the name with `adb shell ip link` (section 5).
+ If the sysfs read fails, look for `avc: denied` with `tcontext=u:object_r:sysfs_net:s0` in `adb logcat` or `dmesg`. Fix it with a policy rule for the app's own domain (`platform_app` or `system_app`), never for `untrusted_app`.

### 7.5 Check the app on the device

```shell
# signature permissions granted? granted=false means the APK isn't signed with this device's platform key
adb shell dumpsys package com.example.deviceinfo | grep -E "LOCAL_MAC_ADDRESS|NETWORK_SETTINGS|BLUETOOTH_CONNECT"

# SELinux domain of the running app
adb shell ps -AZ | grep com.example.deviceinfo
```

| Domain | Meaning |
| --- | --- |
| `u:r:platform_app:s0` | Platform-signed, no `sharedUserId` |
| `u:r:system_app:s0` | Platform-signed with `android.uid.system` |
| `u:r:untrusted_app:s0` (or `untrusted_app_<n>`) | Not signed with this device's platform key |

To compare the APK certificate with the build's keys, see [../Signing/verify_platformKeys.md](../Signing/verify_platformKeys.md).

## Related notes

+ [check_peripherals.md](check_peripherals.md): bring-up checks for Bluetooth, Wi-Fi, and Ethernet
+ [adb_intro.md](adb_intro.md), [adb_shell_cmds.md](adb_shell_cmds.md)
+ [../AOSP_cfg/wifi_default.md](../AOSP_cfg/wifi_default.md), [../AOSP_cfg/SettingsProvider_intro.md](../AOSP_cfg/SettingsProvider_intro.md)
+ [../../Linux/Network/network_cmds.md](../../Linux/Network/network_cmds.md), [../../Linux/HW/sysfs_intro.md](../../Linux/HW/sysfs_intro.md)
+ [../Signing/sign_apk.md](../Signing/sign_apk.md), [../Signing/sharedUserId.md](../Signing/sharedUserId.md), [../Signing/verify_platformKeys.md](../Signing/verify_platformKeys.md): platform key and `android.uid.system`
+ [../SELinux/SELinux_domains.md](../SELinux/SELinux_domains.md): `platform_app` and `system_app`
+ [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md): passing the MACs to apps that aren't platform-signed
+ [../../Comm/BLE_intro.md](../../Comm/BLE_intro.md), [../../Comm/WoL_intro.md](../../Comm/WoL_intro.md)

## Reference

+ [MAC randomization behavior (AOSP)](https://source.android.com/docs/core/connect/wifi-mac-randomization-behavior)
+ [Bluetooth (AOSP)](https://source.android.com/docs/core/connect/bluetooth)
+ [`hardware/broadcom/libbt` (AOSP source)](https://android.googlesource.com/platform/hardware/broadcom/libbt/): Broadcom vendor library, `USE_CONTROLLER_BDADDR`
+ [dumpsys](https://developer.android.com/tools/dumpsys)
+ [Android 6.0 changes: access to hardware identifiers](https://developer.android.com/about/versions/marshmallow/android-6.0-changes#behavior-hardware-id)
+ [Restrictions on non-SDK interfaces](https://developer.android.com/guide/app-compatibility/restrictions-non-sdk-interfaces)
+ [Bluetooth permissions (`BLUETOOTH_CONNECT`)](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)
+ [`BluetoothAdapter.getAddress()`](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#getAddress())
+ [sysfs ABI, including `sysfs-class-net` (`address`, `addr_assign_type`) (kernel docs)](https://docs.kernel.org/admin-guide/abi-testing.html)
+ [IEEE Registration Authority (OUI assignments)](https://standards.ieee.org/products-programs/regauth/)
+ Rockchip BSP documentation for vendor storage and RKDevInfoWriteTool (ships with the SDK)
