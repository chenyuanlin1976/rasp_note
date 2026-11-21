# PWM control on RK3566 (Android 14)

Driving a PWM pin on an RK3566 running Android 14 takes two steps:

1. Enable the PWM controller and mux its pin in the **device tree**.
2. Drive the output, either from user space through **`/sys/class/pwm/`** or from a **kernel driver** that owns the channel.

The sysfs interface is fine for bring-up. In a product, a kernel driver (`pwm-leds`, `pwm-fan`, `pwm-backlight`, or a custom one) or a vendor HAL owns the channel, and apps never write sysfs.
The custom kernel driver example is in [../../Linux/Kernel/pwm_consumer_driver.md](../../Linux/Kernel/pwm_consumer_driver.md).
Section 6 shows the chain from an app through a system app and a vendor AIDL HAL down to sysfs.

## 1. Check the PWM controllers

On a userdebug/eng build:

```shell
adb root
adb shell
ls -d /sys/bus/platform/devices/*.pwm      # enabled PWM nodes, e.g. fe700020.pwm
ls /sys/class/pwm/                         # pwmchip0, pwmchip1, ...
cat /sys/kernel/debug/pwm                  # requested channels, period, duty, polarity, enabled
```

+ On RK3566 every PWM **channel** is its own device tree node and its own `pwmchipN` with one channel (`npwm` = 1), so the channel index is always `0`.
  For example `fe700020.pwm` is `pwm14` (PWM12–15 are at `fe700000`, `fe700010`, `fe700020`, `fe700030`).
+ The `N` in `pwmchipN` depends on probe order. Find it from the platform device instead of hard-coding it (section 3).
+ `/sys/kernel/debug` is debugfs. Android 12+ doesn't mount it on user builds, and on userdebug you may need `mount -t debugfs debugfs /sys/kernel/debug`.
+ The PWM you want is missing → its node is `status = "disabled"`, or another node (backlight, fan, LED, a GPIO user) uses the pin.
  Check the pin mux in `/sys/kernel/debug/pinctrl/*/pinmux-pins`.

## 2. Enable and mux the PWM in the device tree

In the board `.dts` (in the Rockchip BSP, under `kernel/arch/arm64/boot/dts/rockchip/`):

```dts
&pwm14 {
	status = "okay";
	pinctrl-names = "active";          /* Rockchip BSP; mainline uses "default" */
	pinctrl-0 = <&pwm14m0_pins>;       /* m0/m1/m2: pick the mux that matches your physical pin */
};
```

+ Each PWM can be routed to 1–3 pins (`m0`, `m1`, ...). Look up which mux matches your pin in the RK3566 datasheet or the board schematic.
+ Make sure no other node (backlight, fan, LED, `gpio-hog`, a GPIO user) claims the same PWM or pin.
+ Rebuild and flash with your BSP's flow. The Rockchip SDK packs the DTB into the resource section of `boot.img`. Other setups use `dtbo.img`.

## 3. Quick test through sysfs

Times are in **nanoseconds**. Find the chip directory from the platform device:

```shell
P=/sys/devices/platform/fe700020.pwm/pwm
CHIP=$P/$(ls $P)                    # pwmchipN
echo 0 > $CHIP/export               # creates $CHIP/pwm0/
echo 1000000 > $CHIP/pwm0/period        # 1 ms = 1 kHz
echo 500000  > $CHIP/pwm0/duty_cycle    # 50 %
echo normal  > $CHIP/pwm0/polarity      # or 'inversed'; change it only while disabled
echo 1 > $CHIP/pwm0/enable
cat /sys/kernel/debug/pwm               # confirm the values, then measure with a scope or logic analyzer
echo 0 > $CHIP/pwm0/enable
echo 0 > $CHIP/unexport
```

+ `duty_cycle` must never exceed `period`. When **raising** the period, write `period` first. When **lowering** it below the current duty cycle, write `duty_cycle` first, or the write fails with `EINVAL`.
+ If a kernel driver already holds the channel (`pwm-backlight`, `pwm-fan`, ...), `export` fails with `EBUSY`.
  Then use that driver's interface instead, e.g. `/sys/class/backlight/<name>/brightness`.
+ The settings are lost at reboot.

More on platform devices and the PWM sysfs layout: [../../Linux/HW/sysfs_platform_devices.md](../../Linux/HW/sysfs_platform_devices.md).

## 4. Choose who owns the PWM in a product

| The PWM drives ... | Use | Interface for user space |
| --- | --- | --- |
| A dimmable LED | `pwm-leds` (`leds-pwm`) | `/sys/class/leds/<name>/brightness`, Lights HAL ([Led_control.md](Led_control.md)) |
| A fan | `pwm-fan` | hwmon, thermal framework |
| An LCD backlight | `pwm-backlight` | `/sys/class/backlight/<name>/`, framework brightness |
| A buzzer | `pwm-beeper` | input event `EV_SND` |
| Something else (motor, custom signal) | A custom kernel driver ([../../Linux/Kernel/pwm_consumer_driver.md](../../Linux/Kernel/pwm_consumer_driver.md)) or a vendor HAL writing `/sys/class/pwm` | A vendor AIDL HAL |

A standard kernel driver is preferred: the kernel owns the channel, applies the right state at boot and suspend, and Android's existing services use it.

## 5. Android 14: permissions for a vendor HAL

`adb root` works at once, but a normal process can't write the PWM files: they are owned by root, and SELinux labels them as generic `sysfs`.
Apps never get direct access (`neverallow` rules forbid it).
The working design is the same as for GPIO ([hw_control_sysfs.md](hw_control_sysfs.md)):

1. A **native vendor daemon or AIDL HAL** (`vendor.<company>.hardware.pwm`, in `/vendor/bin/hw/`) writes the PWM files.
2. Apps call it through Binder. A third-party app goes through a system app (bound service).

### 5.1 Ownership (DAC) with `ueventd.rc`

`pwmchipN` changes between boots, so use the platform path with a wildcard. ueventd applies the rules when the devices appear, including `pwm0` after `export`:

```text
# vendor ueventd.rc: <sysfs device path pattern> <attribute> <mode> <user> <group>
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*        export      0220  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*        unexport    0220  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   period      0660  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   duty_cycle  0660  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   polarity    0660  system  system
/sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0   enable      0660  system  system
```

The daemon (`user system`) then exports the channel itself at startup.

### 5.2 SELinux

sysfs files are labeled with `genfs_contexts`, using the real `/sys/devices/...` path. The label covers the whole subtree:

```text
# vendor/file.te
type sysfs_pwm, sysfs_type, fs_type;

# vendor/genfs_contexts
genfscon sysfs /devices/platform/fe700020.pwm   u:object_r:sysfs_pwm:s0

# vendor/hal_pwm_default.te
allow hal_pwm_default sysfs_pwm:dir r_dir_perms;
allow hal_pwm_default sysfs_pwm:file rw_file_perms;
```

+ Give the daemon a specific type like this. A broad rule on `sysfs` fails `neverallow` checks or opens far too much.
+ Open the files through `/sys/devices/platform/...`. Going through the `/sys/class/pwm` symlinks also needs `lnk_file` access to the generic `sysfs` type.
+ Check with `adb shell ls -lZ /sys/devices/platform/fe700020.pwm/pwm/pwmchip*/pwm0/` and look for denials with `adb logcat | grep avc` ([../SELinux/avc_denied.md](../SELinux/avc_denied.md)).

### 5.3 The API

Expose intent, not file writes, e.g. `setOutput(long periodNs, int dutyPercent)`.
The HAL validates the values, writes `period`/`duty_cycle`/`enable` in the right order, and is the only writer.
The full chain from an app to the HAL is in section 6.

## 6. From an app to the PWM

```text
 app (any)  --bindService()-->  system app: PwmControlService     public AIDL  com.example.pwm.IPwmControl
                                     |  Binder (platform-signed, hal_client_domain)
                                     v
                                vendor HAL: /vendor/bin/hw/...   stable AIDL  vendor.example.hardware.pwm.IPwm
                                     |  write()
                                     v
                                /sys/devices/platform/fe700020.pwm/pwm/pwmchipN/pwm0/{period,duty_cycle,enable}
```

Only the HAL touches sysfs. Every hop above it is a Binder call.
The general patterns are in [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md) (system app as a proxy) and [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md) (`Android.bp`, `.rc`, VINTF manifest, `service_contexts`).

### 6.1 HAL interface

```java
// aidl/vendor/example/hardware/pwm/IPwm.aidl
package vendor.example.hardware.pwm;

@VintfStability
interface IPwm {
    /** periodNs: 1..1e9 ns; dutyPercent: 0..100, where 0 disables the output. */
    void setOutput(long periodNs, int dutyPercent);
    int getDutyPercent();
}
```

Build it as an `aidl_interface` with `stability: "vintf"` and the NDK (server) and Java (system app) backends enabled, as in [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md) §1.

### 6.2 HAL implementation (C++, NDK backend)

```c++
#define LOG_TAG "vendor.example.hardware.pwm"

#include <aidl/vendor/example/hardware/pwm/BnPwm.h>
#include <android-base/file.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

#include <unistd.h>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <filesystem>
#include <mutex>
#include <string>
#include <thread>

namespace aidl::vendor::example::hardware::pwm {

class Pwm : public BnPwm {
  public:
    explicit Pwm(std::string dir) : mDir(std::move(dir)) {}

    ndk::ScopedAStatus setOutput(int64_t periodNs, int32_t dutyPercent) override {
        if (periodNs <= 0 || periodNs > 1'000'000'000 || dutyPercent < 0 || dutyPercent > 100) {
            return ndk::ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
        }
        const int64_t dutyNs = periodNs * dutyPercent / 100;

        std::lock_guard<std::mutex> lock(mLock);
        // duty_cycle must never exceed period: grow the period first, shrink it last.
        bool ok = periodNs >= mPeriodNs
                          ? write("period", periodNs) && write("duty_cycle", dutyNs)
                          : write("duty_cycle", dutyNs) && write("period", periodNs);
        ok = ok && write("enable", dutyPercent > 0 ? 1 : 0);
        if (!ok) {
            ALOGE("setOutput(%lld ns, %d %%): %s", static_cast<long long>(periodNs), dutyPercent,
                  strerror(errno));
            return ndk::ScopedAStatus::fromExceptionCode(EX_ILLEGAL_STATE);
        }
        mPeriodNs = periodNs;
        mDutyPercent = dutyPercent;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus getDutyPercent(int32_t* _aidl_return) override {
        std::lock_guard<std::mutex> lock(mLock);
        *_aidl_return = mDutyPercent;
        return ndk::ScopedAStatus::ok();
    }

  private:
    bool write(const char* attr, int64_t value) {
        return android::base::WriteStringToFile(std::to_string(value), mDir + "/" + attr);
    }

    std::mutex mLock;
    const std::string mDir;     // .../pwmchipN/pwm0
    int64_t mPeriodNs = 0;      // the safe state written in main() has duty_cycle = 0
    int32_t mDutyPercent = 0;
};

}  // namespace aidl::vendor::example::hardware::pwm

using aidl::vendor::example::hardware::pwm::Pwm;

// pwmchipN changes between boots: find it under the platform device.
static std::string findPwmChip(const std::string& platformDir) {
    std::error_code ec;
    for (const auto& e : std::filesystem::directory_iterator(platformDir + "/pwm", ec)) {
        if (e.path().filename().string().rfind("pwmchip", 0) == 0) return e.path().string();
    }
    return {};
}

int main() {
    const std::string chip = findPwmChip("/sys/devices/platform/fe700020.pwm");
    if (chip.empty()) {
        ALOGE("PWM controller not found");
        return EXIT_FAILURE;
    }
    const std::string dir = chip + "/pwm0";
    if (access(dir.c_str(), F_OK) != 0) {
        android::base::WriteStringToFile("0", chip + "/export");
    }
    // export creates pwm0 at once, but ueventd changes the owner of its files a moment later.
    for (int i = 0; i < 50 && access((dir + "/enable").c_str(), W_OK) != 0; ++i) {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    // Safe state: output off, duty 0 (then any period is valid).
    android::base::WriteStringToFile("0", dir + "/enable");
    android::base::WriteStringToFile("0", dir + "/duty_cycle");

    ABinderProcess_setThreadPoolMaxThreadCount(0);
    auto service = ndk::SharedRefBase::make<Pwm>(dir);
    const std::string instance = std::string(Pwm::descriptor) + "/default";
    binder_exception_t err = AServiceManager_addService(service->asBinder().get(), instance.c_str());
    if (err != EX_NONE) {
        ALOGE("Failed to register %s: %d", instance.c_str(), err);
        return EXIT_FAILURE;
    }
    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;  // joinThreadPool() never returns
}
```

+ Link `libbinder_ndk`, `libbase`, `liblog`, and `vendor.example.hardware.pwm-V1-ndk`. Install it in `/vendor/bin/hw/` (`relative_install_path: "hw"`), and run it as `user system` so the `ueventd.rc` rules in §5.1 apply.
+ Its domain `hal_pwm_default` needs the sysfs rules from §5.2, plus `hal_server_domain(hal_pwm_default, hal_pwm)` and a `service_contexts` entry ([../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md) §4).

### 6.3 System app: public bound service

A platform-signed system app is the only HAL client. It exposes its own, simpler interface to other apps:

```java
// src/main/aidl/com/example/pwm/IPwmControl.aidl
package com.example.pwm;

interface IPwmControl {
    void setDutyPercent(int percent);   // 0..100, 0 = off
    int getDutyPercent();
}
```

```kotlin
package com.example.pwm

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.ServiceManager
import vendor.example.hardware.pwm.IPwm

class PwmControlService : Service() {

    // Hidden API: works only in a platform-signed app (platform_apis: true).
    private val hal: IPwm? by lazy {
        IPwm.Stub.asInterface(ServiceManager.waitForDeclaredService("${IPwm.DESCRIPTOR}/default"))
    }

    private val binder = object : IPwmControl.Stub() {
        override fun setDutyPercent(percent: Int) {
            require(percent in 0..100) { "percent must be 0..100" }   // IllegalArgumentException reaches the caller
            val h = hal ?: throw IllegalStateException("PWM HAL not available")
            h.setOutput(PERIOD_NS, percent)
        }

        override fun getDutyPercent(): Int = hal?.dutyPercent ?: 0
    }

    override fun onBind(intent: Intent): IBinder = binder

    private companion object {
        const val PERIOD_NS = 1_000_000L   // 1 kHz, fixed by the product, not by the caller
    }
}
```

```xml
<!-- AndroidManifest.xml of the system app -->
<permission
    android:name="com.example.permission.CONTROL_PWM"
    android:protectionLevel="signature" />

<application>
    <service
        android:name=".PwmControlService"
        android:exported="true"
        android:permission="com.example.permission.CONTROL_PWM" />
</application>
```

+ `exported="true"` with `android:permission` lets only apps holding the permission bind. `signature` limits it to apps with the same key. For third-party apps choose another protection level ([../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md)).
+ Clients bind with `bindService()` as in [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md). On Android 11+ a client also needs a `<queries>` entry for the system app's package.
+ The system app's SELinux domain needs `hal_client_domain(<domain>, hal_pwm)`.
+ A Binder call blocks until the HAL has written sysfs. Call it off the main thread, and rate-limit slider updates (see [../../Comm/pwm_remote_ctrl.md](../../Comm/pwm_remote_ctrl.md) §2).

### 6.4 Why not JNI or sysfs writes from Kotlin

+ JNI code runs in the app's process with the app's UID and SELinux domain. It has no more access than Kotlin code ([../Native/JNI_C_code.md](../Native/JNI_C_code.md)).
+ Writing sysfs from the system app would need SELinux rules giving an app domain access to vendor sysfs files.
  That puts hardware policy into the system partition and breaks the system/vendor split. The vendor HAL keeps the hardware access in `/vendor`.
+ Third-party apps never get sysfs access (`neverallow`). They always go through the system app.

## Related notes

+ [../../Linux/Kernel/pwm_consumer_driver.md](../../Linux/Kernel/pwm_consumer_driver.md): custom kernel driver using the PWM consumer API
+ [../../Linux/HW/sysfs_platform_devices.md](../../Linux/HW/sysfs_platform_devices.md): platform devices, PWM sysfs on RK3566
+ [hw_control_sysfs.md](hw_control_sysfs.md): sysfs hardware access from a vendor daemon (GPIO example)
+ [Led_control.md](Led_control.md), [gpio_control.md](gpio_control.md), [../HAL/HAL_sysfsNodes.md](../HAL/HAL_sysfsNodes.md)
+ [../../Linux/DeviceTree/dts_provider_consumer.md](../../Linux/DeviceTree/dts_provider_consumer.md): `#pwm-cells`, `pwms`, `pwm-names`
+ [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md), [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md): bound service, system app proxy, vendor HAL
+ [../../Comm/pwm_remote_ctrl.md](../../Comm/pwm_remote_ctrl.md): controlling a PWM over HTTP, MQTT, or BLE

## Reference

+ [Pulse Width Modulation (PWM) interface (kernel docs)](https://docs.kernel.org/driver-api/pwm.html)
+ [Implementing SELinux: genfs_contexts (AOSP)](https://source.android.com/docs/security/features/selinux/implement)
+ [AIDL for HALs (AOSP)](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ Rockchip RK3566 datasheet and the Rockchip Android SDK documentation (vendor docs)
