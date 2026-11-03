# AIDL and HAL services

"AIDL is the **public contract** for a **native HAL service**." This note explains what that sentence means.

+ **HAL** is the *layer*: vendor code that hides chip-specific details from the rest of Android.
+ **AIDL** is the *technology* that defines and carries the HAL's interface (since Android 11; earlier HALs used HIDL,
  see [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md)).

## 1. What a "contract" is

A contract is a strict agreement on how 2 pieces of software talk to each other:
the method names, the argument types, the return values, and the errors.
Neither side needs to know how the other side is implemented; both just follow the contract.
For a HAL, the contract is a **versioned, frozen `.aidl` interface** marked `@VintfStability`.

## 2. What the HAL is

Android runs on many SoCs (Qualcomm, MediaTek, Rockchip, ...), and each one controls hardware differently.

+ A HAL is usually a **native (C++/Rust) service process** on the **vendor** partition, written by the SoC or device maker.
+ The framework (`system_server`, system services) only wants "turn Wi-Fi power on". It doesn't care which GPIO or register is involved.

## 3. Why AIDL is the contract

+ The framework and the HAL run in **different processes**, on **different partitions**, and are often updated separately (Treble, GSI).
+ Stable AIDL makes the contract:
  + **versioned and frozen**: the build checks API dumps; a released version can't change, only new versions can be added.
  + **declared in VINTF**: the device manifest says "I provide `IWifiPowerControl` v1 / default",
    and the framework compatibility matrix says what it requires.
+ The generated code marshals the data over **Binder**, so a crash in the HAL kills only the HAL process,
  not `system_server` or apps.

**In short**: AIDL is the stable rulebook that lets high-level Android code tell a low-level native HAL what to do,
across process and partition boundaries.

## 4. Example: Wi-Fi power HAL

> Simplified example to show the roles. A full buildable HAL (`Android.bp`, `.rc`, VINTF, SELinux)
> is in [AIDL_HAL_impl.md](AIDL_HAL_impl.md).
> Real Wi-Fi power is normally handled by the kernel Wi-Fi driver (rfkill) and the AOSP Wi-Fi HAL.

### 4.1 The contract (`.aidl`)

`android.hardware.*` packages are reserved for Google-defined HALs. Custom HALs use `vendor.<company>.*`.

```java
// vendor/example/hardware/wifipower/aidl/vendor/example/hardware/wifipower/IWifiPowerControl.aidl
package vendor.example.hardware.wifipower;

@VintfStability
interface IWifiPowerControl {
    /** Turns the Wi-Fi module power on/off. Fails with a service-specific error on GPIO failure. */
    void setWifiPower(boolean enable);
}
```

Rule of the contract: the caller passes a `boolean`.
Success is "no error"; failure comes back as an exception or status, not as a `false` return value (see the AIDL style guide).

### 4.2 Server side (C++ HAL, NDK backend)

```c++
#include <aidl/vendor/example/hardware/wifipower/BnWifiPowerControl.h>
#include <cerrno>
#include <gpiod.h>   // libgpiod v1 API, see ../Linux/libgpiod_intro.md

namespace aidl::vendor::example::hardware::wifipower {

class WifiPowerControl : public BnWifiPowerControl {
  public:
    explicit WifiPowerControl(gpiod_line* line) : mLine(line) {}   // line requested as output at startup

    ndk::ScopedAStatus setWifiPower(bool enable) override {
        if (gpiod_line_set_value(mLine, enable ? 1 : 0) < 0) {
            return ndk::ScopedAStatus::fromServiceSpecificError(errno);
        }
        return ndk::ScopedAStatus::ok();
    }

  private:
    gpiod_line* mLine;
};

}  // namespace aidl::vendor::example::hardware::wifipower
```

### 4.3 Client side (framework / privileged Java code)

```java
import android.os.IBinder;
import android.os.RemoteException;
import android.os.ServiceManager;              // @hide: platform code / platform-signed apps only
import android.os.ServiceSpecificException;
import vendor.example.hardware.wifipower.IWifiPowerControl;

// AIDL HAL instance name = "<package>.<Interface>/<instance>"
String name = IWifiPowerControl.DESCRIPTOR + "/default";
IBinder binder = ServiceManager.waitForDeclaredService(name);   // null if not declared in VINTF
IWifiPowerControl hal = IWifiPowerControl.Stub.asInterface(binder);

try {
    hal.setWifiPower(true);
} catch (ServiceSpecificException e) {
    Log.e(TAG, "HAL reported GPIO error " + e.errorCode);
} catch (RemoteException e) {
    Log.e(TAG, "HAL process died / binder failure", e);
}
```

Normal 3rd-party apps **can't** do this, because vendor HALs are not reachable from apps.
They go through a framework or system-app API instead (see [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md)).

### 4.4 Why this structure matters

+ **Decoupling**: the vendor can rewrite the C++ code (for example, switch from libgpiod to a kernel driver).
  As long as `IWifiPowerControl` v1 is still fulfilled, the framework doesn't change.
+ **Fault isolation**: if the HAL crashes, only the HAL process dies. `init` restarts it, and clients get `DeadObjectException`.

## 5. Describing the GPIO in the device tree (`.dtsi`)

There are 2 different ways to describe the pin, and **they are mutually exclusive**:

### 5.1 A kernel driver owns the pin

```dts
wifi_module: wifi@1 {
    compatible = "vendor,wifi-chip";
    /* line 12 of gpio1, active-high enable */
    enable-gpios = <&gpio1 12 GPIO_ACTIVE_HIGH>;
};
```

The driver bound to `vendor,wifi-chip` claims the line with `devm_gpiod_get(dev, "enable", ...)`.
After that, **user space (libgpiod) gets `EBUSY`** for this line.
The HAL then controls power through the driver (rfkill or a sysfs attribute), not through libgpiod.

### 5.2 User space (the HAL) owns the pin

No driver claims the line. You only give it a name, so the HAL can find it with `gpiod_chip_find_line()` / `gpioinfo`:

```dts
&gpio1 {
    gpio-line-names = "", "", "", "", "", "", "", "", "", "", "", "",
                      "WIFI_PWR_EN";   /* index 12 */
};
```

### 5.3 Build and check

1. Rebuild the `.dtb` (or the `dtbo`) and flash it.
2. Check that the property is in `/proc/device-tree/...`.
3. Run `gpioinfo gpiochip1`: the line shows as `"WIFI_PWR_EN" unused` (5.2) or as used by the driver's consumer name (5.1).

## Related notes

+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md): complete vendor HAL server and client
+ [HAL_intro.md](HAL_intro.md), [HAL_libgpiod.md](HAL_libgpiod.md), [libgpiod_android.md](libgpiod_android.md), [DTSI_syntax_fmt.md](DTSI_syntax_fmt.md)
+ [VINTF_AIDL.md](VINTF_AIDL.md)

## Reference

+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [Stable AIDL](https://source.android.com/docs/core/architecture/aidl/stable-aidl)
