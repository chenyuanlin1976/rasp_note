# Exposing an AOSP AIDL service to a 3rd-party APK

Suppose you implemented a custom service in AOSP, for example a GPIO service, and want a normal 3rd-party APK to use it.
By default, the app **can't reach it**:

+ **Hidden API**: `android.os.ServiceManager` is `@hide`, so an SDK app can't look up services by name.
+ **SELinux**: `untrusted_app` may only `find` services labeled `app_api_service`.
  A `neverallow` rule in AOSP enforces this, so you can't simply add an `allow` rule.
+ **Treble**: untrusted apps may not talk to **vendor** services or HALs at all.
  Only platform components that are declared HAL clients may, such as some system apps and `system_server`.
+ **Interface**: the app also needs the client-side stub classes.

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

You only open the path **system app → native service**. Example, with the domain/type names from [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md):

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
See [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md#6-selinux).

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
2. Package it as (details in [jar_aar_intro.md](jar_aar_intro.md)):
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

## Related notes

+ [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md): bound-service basics
+ [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md): the native GPIO daemon behind the system app
+ [jar_aar_intro.md](jar_aar_intro.md), [SELinux_policy.md](SELinux_policy.md), [neverallow_error.md](neverallow_error.md)

## Reference

+ [Restrictions on non-SDK interfaces](https://developer.android.com/guide/app-compatibility/restrictions-non-sdk-interfaces)
+ [Package visibility](https://developer.android.com/training/package-visibility)
