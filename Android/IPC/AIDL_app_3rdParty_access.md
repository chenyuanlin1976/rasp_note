# Exposing an AOSP AIDL service to a 3rd-party APK

Suppose you implemented a custom service in AOSP, for example a GPIO service, and want a normal 3rd-party APK to use it.
By default, the app **can't reach it**:

+ **Hidden API**: `android.os.ServiceManager` is `@hide`, so an SDK app can't look up services by name.
+ **SELinux**: `untrusted_app` may only `find` services labeled `app_api_service`.
  A `neverallow` rule in AOSP enforces this, so you can't simply add an `allow` rule.
+ **Treble**: untrusted apps may not talk to **vendor** services or HALs at all.
  Only platform components that are declared HAL clients may, such as some system apps and `system_server`.
+ **Interface**: the app also needs the client-side stub classes.

Sections 1 to 5 use a GPIO service as the example. Section 6 applies the same pattern to device info (SW version, MACs, serial number) and Bluetooth on/off.

## 1. Choose the architecture

### Approach A: system app as a proxy (recommended)

```text
3rd-party APK --bindService()--> privileged/system app (bound service, public AIDL)
                                        |  (platform-signed, allowed by SELinux)
                                        v
                              native daemon / HAL (private AIDL)
```

+ A system app (in `/system_ext/priv-app` or `/product/priv-app`) exposes an ordinary **bound service** with a public AIDL interface.
+ That system app is the only component that talks to the native service or HAL.
  Its SELinux domain (`priv_app`/`platform_app`) can be granted the access.
+ The 3rd-party APK uses the normal `bindService()` path. It needs no hidden APIs and no SELinux changes for `untrusted_app`.
+ You enforce access with an Android **permission** declared in the system app.

### Approach B: app talks directly to a system service (not practical for 3rd-party apps)

This works only if **all** of the following are true:

+ the service is a **system** (not vendor) service
+ its type has the `app_api_service` attribute
+ the client can call a hidden API (a platform-signed app, or reflection, which hidden-API enforcement blocks)

These conditions make it a platform API, which is not appropriate for a custom feature.
Use Approach A.

## 2. Server side (system app, Approach A)

The **public** interface that the system app exposes. It is separate from the HAL's interface,
so you can keep it small and change the HAL freely.

```java
// IGpioService.aidl: shared with 3rd-party developers
package com.yourcompany.gpio;

interface IGpioService {
    /** Returns false if the pin is not allowed for apps or the HAL reports an error. */
    boolean setGpio(int pin, boolean high);
}
```

```xml
<!-- AndroidManifest.xml of the system app (com.yourcompany.gpiohost) -->
<permission
    android:name="com.yourcompany.permission.CONTROL_GPIO"
    android:protectionLevel="signature|privileged" />   <!-- or "dangerous"/"normal" if any app may use it -->

<service
    android:name=".GpioBridgeService"
    android:exported="true"
    android:permission="com.yourcompany.permission.CONTROL_GPIO">
    <intent-filter>
        <action android:name="com.yourcompany.action.CONTROL_GPIO" />
    </intent-filter>
</service>
```

Declare the permission in the **system app's own manifest**. You don't need to edit `frameworks/base`.
Inside the service, you can also check `Binder.getCallingUid()` or call `enforceCallingPermission()` for finer control.

## 3. Client side (3rd-party APK)

The APK needs the client stubs. Ship them in one of the 2 ways described in section 5.

```kotlin
class GpioControllerClient(private val context: Context) {
    private var gpioService: IGpioService? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            gpioService = IGpioService.Stub.asInterface(service)
        }
        override fun onServiceDisconnected(name: ComponentName) {
            gpioService = null
        }
    }

    fun bind(): Boolean {
        val intent = Intent("com.yourcompany.action.CONTROL_GPIO")
            .setPackage("com.yourcompany.gpiohost")    // explicit package is mandatory
        return context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    fun unbind() = context.unbindService(connection)

    fun setGpioPin(pin: Int, high: Boolean): Boolean = try {
        gpioService?.setGpio(pin, high) ?: false
    } catch (e: RemoteException) {
        false
    }
}
```

In the client's `AndroidManifest.xml`:

```xml
<uses-permission android:name="com.yourcompany.permission.CONTROL_GPIO" />

<!-- Android 11+ package visibility -->
<queries>
    <package android:name="com.yourcompany.gpiohost" />
</queries>
```

## 4. SELinux (on the system-app side only)

You only open the path **system app → native service**. Example, with the domain/type names from [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md):

```text
# system_ext/private/gpio_bridge_app.te: a dedicated domain for the bridge app
type gpio_bridge_app, domain, coredomain;
app_domain(gpio_bridge_app)
allow gpio_bridge_app app_api_service:service_manager find;     # normal framework services
hal_client_domain(gpio_bridge_app, hal_gpioctl)                 # find hal_gpioctl_service + binder_call

# system_ext/private/seapp_contexts: put the platform-signed app into that domain
user=_app seinfo=platform name=com.yourcompany.gpiohost domain=gpio_bridge_app type=app_data_file levelFrom=all
```

`hal_gpioctl` must be defined in `system_ext/public`, not in vendor policy, or this file can't reference it.
See [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md#6-selinux).

Don't add rules like `allow untrusted_app gpio_device:chr_file ...`.
The app never opens `/dev/gpiochip*`; only the daemon does.
Such a rule would let **every** app touch the hardware. It also violates AOSP `neverallow` rules, which fails CTS.

## 5. How to deliver the interface to the app developer

### Option 1: share the `.aidl` file

1. The developer copies it to `app/src/main/aidl/com/yourcompany/gpio/IGpioService.aidl`.
2. The package and method signatures must **exactly** match the server's file.
3. With `buildFeatures { aidl = true }`, Gradle generates `IGpioService.Stub` / `Stub.asInterface()`.

### Option 2: ship a JAR / AAR

1. Build a library module that contains the `.aidl` file. AGP generates Java into `build/generated/aidl_source_output_dir/`.
2. Package it as (details in [../App/jar_aar_intro.md](../App/jar_aar_intro.md)):
   + **JAR**: the generated interface classes, parcelables, and helper code (a JAR may use Android APIs such as `Context`)
   + **AAR**: if you also ship resources, native `.so` files, or a manifest (with the `<uses-permission>` and `<queries>` entries)
3. **Best practice**: add a wrapper (for example `GpioManager`) that does the binding, reconnects,
   and converts `RemoteException` into normal errors.
   Then the app calls `gpioManager.setPinState(...)` and never sees `IBinder`.

### Which one to use

| Ship the `.aidl` file when | Ship a JAR / AAR when |
| --- | --- |
| The partner wants to write their own connection layer | You want to hide Binder details behind a clean SDK |
| They want Gradle to generate the stubs in their build | You want to avoid version mismatches from edited or outdated `.aidl` copies |
| You have close source-level collaboration | You need helper code, a manifest, or resources (use AAR) |

For a long-lived public interface, give the `.aidl` file a stable evolution rule anyway.
**Only append** new methods at the end, never reorder or remove them, because the transaction codes are assigned by position.

## 6. Example: device info and Bluetooth control

A common customer request: their app (signed with **their own key**, not your platform key) needs the software version, the Wi-Fi and Bluetooth MAC addresses, the serial number, and sometimes needs to switch Bluetooth on or off on a headless device.
Most of this is blocked for normal apps on Android 14, so the system app from section 1 provides it.

### 6.1 What a normal app gets on its own

| Item | Normal app (`untrusted_app`) | Why |
| --- | --- | --- |
| SW version (`Build.DISPLAY` = `ro.build.display.id`) | **Yes** | Public `android.os.Build` field; `Build.FINGERPRINT` and `Build.VERSION.*` too |
| Custom vendor property (`ro.vendor.*`, ...) | Depends | Only readable if your `property_contexts` gives it a type that apps may read; `SystemProperties` is `@hide` anyway |
| Serial number (`ro.serialno`) | **No** | Property read is denied by SELinux. `Build.SERIAL` is deprecated (returns `UNKNOWN`), and since Android 10 `Build.getSerial()` needs `READ_PRIVILEGED_PHONE_STATE`, which third-party apps can't hold |
| Wi-Fi MAC | **No** | `WifiInfo.getMacAddress()` returns `02:00:00:00:00:00` without `LOCAL_MAC_ADDRESS`; sysfs/netlink reads are blocked by SELinux; and the address on `wlan0` is randomized per network anyway |
| Bluetooth MAC | **No** | `BluetoothAdapter.getAddress()` returns `02:00:00:00:00:00` without `LOCAL_MAC_ADDRESS` (signature permission) |
| Ethernet MAC | **No** (on stock policy) | No permission exists; `NetworkInterface.getHardwareAddress()` returns `null` (netlink blocked for `targetSdk` 30+) and SELinux normally denies `/sys/class/net/eth0/address` |
| Turn Bluetooth on | Only with a user prompt | `BluetoothAdapter.enable()` is deprecated in Android 13 and always fails for apps targeting API 33+ (system apps and device/profile owners are exempt). `ACTION_REQUEST_ENABLE` (needs `BLUETOOTH_CONNECT`) shows a confirmation dialog, which nobody answers on a headless device |
| Turn Bluetooth off | **No** | No public API or intent for normal apps |
| Battery level and charging state | **Yes** | `ACTION_BATTERY_CHANGED` or `BatteryManager`, no permission; see [../Debug/check_peripherals.md](../Debug/check_peripherals.md#7-battery-and-charger) |
| Keep the device awake | **Yes** | Partial wake lock with the normal permission `WAKE_LOCK` |
| Put the device to sleep | **No** | `PowerManager.goToSleep()` needs `DEVICE_POWER` (signature); only an active device admin can call `DevicePolicyManager.lockNow()` |
| Wake from suspend at a set time | **Yes** | `AlarmManager` `RTC_WAKEUP` / `ELAPSED_REALTIME_WAKEUP`; exact alarms need `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`. See [../App/app_background_limits.md](../App/app_background_limits.md#4-wake-up-alarms) |
| Power on from off at a set time, program the RTC | **No** | No AOSP API; `/dev/rtc*` and `wakealarm` are closed to apps, and power-on alarms are PMIC/BSP-specific |

Details of the MAC addresses (factory vs randomized, `getFactoryMacAddresses()`, required permissions) are in [../Debug/mac_address.md](../Debug/mac_address.md#7-read-the-factory-macs-from-a-platform-signed-app).
A device owner app gets the Wi-Fi MAC from `DevicePolicyManager.getWifiMacAddress()`; there is no such call for Ethernet.
If the customer only needs a stable ID for their own installation, a random UUID kept in app storage avoids hardware identifiers entirely.

Don't work around this with `allow untrusted_app ...` rules or by giving customers your platform key: the first opens the data to every app, the second lets the customer's app do anything a system app can.

### 6.2 Interface

Give the customer a small interface with stable methods, instead of property names, `getprop`, or `dumpsys` output that can change between BSP releases.

```java
// IDeviceInfoService.aidl: shared with the customer
package com.yourcompany.deviceinfo;

interface IDeviceInfoService {
    /** Customer-facing SW version string. */
    String getSwVersion();
    /** Factory addresses as "AA:BB:CC:DD:EE:FF", or "" if not available. */
    String getWifiMac();
    String getBtMac();
    /** "" if not available. */
    String getSerialNumber();
    /** Returns false if the caller isn't allowed or the request failed. */
    boolean setBluetoothEnabled(boolean enable);
}
```

### 6.3 Implementation in the system app

The system app is signed with the platform key, so it can hold `LOCAL_MAC_ADDRESS`, `NETWORK_SETTINGS`, and `READ_PRIVILEGED_PHONE_STATE`; it also needs `BLUETOOTH_CONNECT` (see [../Debug/mac_address.md](../Debug/mac_address.md#71-manifest-and-signing) for granting it).
`getWifiFactoryMacAddress()` and `getBluetoothMacAddress()` are the functions from that note.

```kotlin
class DeviceInfoService : Service() {

    private val binder = object : IDeviceInfoService.Stub() {
        override fun getSwVersion(): String = Build.DISPLAY

        override fun getWifiMac(): String =
            getWifiFactoryMacAddress(this@DeviceInfoService) ?: ""

        override fun getBtMac(): String =
            getBluetoothMacAddress(this@DeviceInfoService) ?: ""

        @SuppressLint("HardwareIds")
        override fun getSerialNumber(): String = try {
            Build.getSerial()                      // needs READ_PRIVILEGED_PHONE_STATE
        } catch (e: SecurityException) {
            ""
        }

        @Suppress("DEPRECATION")
        @SuppressLint("MissingPermission")
        override fun setBluetoothEnabled(enable: Boolean): Boolean {
            enforceCallingPermission(
                "com.yourcompany.permission.CONTROL_BLUETOOTH", "setBluetoothEnabled")
            val adapter = getSystemService(BluetoothManager::class.java)?.adapter ?: return false
            return if (enable) adapter.enable() else adapter.disable()   // allowed for system apps
        }
    }

    override fun onBind(intent: Intent): IBinder = binder
}
```

+ Keep reads and control apart: `setBluetoothEnabled()` checks its own permission, so a read-only client can't toggle Bluetooth.
+ The customer's app is signed with **their** key, so a `signature` permission declared by your platform-signed app can never be granted to it.
  Use `android:protectionLevel="normal"` and, if only specific apps may call the service, check the caller in the service:
  `Binder.getCallingUid()` → `packageManager.getPackagesForUid()` → compare the package's signing certificate digest with an allowlist.
+ AIDL methods run on Binder threads; return quickly. `enable()` / `disable()` only start the state change, so the customer should poll `BluetoothAdapter.isEnabled()` (or listen for `ACTION_STATE_CHANGED`) to see the result.

### 6.4 Decide with the customer

+ **Wi-Fi or Bluetooth off:** return the last known MAC, an empty string, or turn the radio on first?
  `BluetoothAdapter.getAddress()` returns the cached address when Bluetooth is off; check what your Wi-Fi stack returns for `getFactoryMacAddresses()` with Wi-Fi off.
+ **Access control:** may every installed app read these values, or only the customer's packages? Who may toggle Bluetooth?
+ **SW version:** is `Build.DISPLAY` the string the customer should see, or a custom property (then read it in the service and return it from `getSwVersion()`)?

### 6.5 Verify

| Step | Check |
| --- | --- |
| Baseline | In a test APK signed with a debug key: `Build.DISPLAY` equals `adb shell getprop ro.build.display.id`; `Build.getSerial()` throws `SecurityException`; MAC APIs return `02:00:00:00:00:00` |
| System app permissions | `adb shell dumpsys package com.yourcompany.deviceinfo \| grep -E "LOCAL_MAC_ADDRESS\|NETWORK_SETTINGS\|READ_PRIVILEGED_PHONE_STATE\|BLUETOOTH_CONNECT"` shows `granted=true` |
| Values through the service | The same debug-key test APK gets the serial (`adb shell getprop ro.serialno` as root), and MACs that match [../Debug/mac_address.md](../Debug/mac_address.md) sections 3 and 4 |
| Bluetooth control | After `setBluetoothEnabled(true/false)`, `adb shell 'dumpsys bluetooth_manager \| grep state:'` shows `ON` / `OFF` |
| SELinux | Image in `enforcing` mode; no `avc: denied` in `adb logcat` / `dmesg` while the test runs |

## Related notes

+ [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md): bound-service basics
+ [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md): the native GPIO daemon behind the system app
+ [../Debug/mac_address.md](../Debug/mac_address.md): reading factory MACs in a platform-signed app (used in section 6)
+ [../App/app_background_limits.md](../App/app_background_limits.md): wake locks and wake-up alarms for normal apps
+ [../AOSP_cfg/sleep_flow.md](../AOSP_cfg/sleep_flow.md): who may put the device to sleep
+ [../AOSP_cfg/system_properties.md](../AOSP_cfg/system_properties.md): why not expose properties to customer apps
+ [../Signing/sign_apk.md](../Signing/sign_apk.md): platform key
+ [../App/jar_aar_intro.md](../App/jar_aar_intro.md), [../SELinux/SELinux_policy.md](../SELinux/SELinux_policy.md), [../SELinux/neverallow_error.md](../SELinux/neverallow_error.md)

## Reference

+ [Restrictions on non-SDK interfaces](https://developer.android.com/guide/app-compatibility/restrictions-non-sdk-interfaces)
+ [Package visibility](https://developer.android.com/training/package-visibility)
+ [Android 10 privacy changes: non-resettable device identifiers](https://developer.android.com/about/versions/10/privacy/changes)
+ [`Build.getSerial()`](https://developer.android.com/reference/android/os/Build#getSerial())
+ [`BluetoothAdapter.enable()`](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#enable())
+ [Bluetooth permissions (`BLUETOOTH_CONNECT`)](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)
+ [Best practices for unique identifiers](https://developer.android.com/identity/user-data-ids)
