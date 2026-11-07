# Binder Service Lookup: bindService() vs ServiceManager

Both give you an `IBinder` to another process, but they are different mechanisms for different users:

| | `ServiceConnection` + `bindService()` | `ServiceManager` / `servicemanager` |
| --- | --- | --- |
| What it is | A public SDK callback interface (`android.content.ServiceConnection`) | `servicemanager` is a native daemon (`/system/bin/servicemanager`), the Binder context manager. `android.os.ServiceManager` (`@hide`) and `AServiceManager_*` (NDK, platform) are its clients |
| Finds services by | `Intent` / `ComponentName`, resolved by **ActivityManagerService** | A global **name string**, for example `"activity"` or `vendor.example.hardware.myhal.IMyHalService/default` |
| Services found | `<service>` components declared in app manifests | System services (`system_server`), native daemons, AIDL HALs |
| Lifecycle | AMS starts the app process and the `Service` on demand (`BIND_AUTO_CREATE`) and tracks the binding | The service registers itself at boot with `addService()`. `init` starts lazy HALs on lookup |
| Access control | `android:exported`, `android:permission` on the `<service>`, package visibility | SELinux `service_manager { find }` for the caller's domain. Hidden API: only platform code can call it |
| Who uses it | Any app | Framework, platform-signed system apps, native daemons, HAL clients |

## 1. `ServiceConnection` (apps)

```kotlin
private val connection = object : ServiceConnection {
    override fun onServiceConnected(name: ComponentName, service: IBinder) {
        remote = IMyAidlInterface.Stub.asInterface(service)
    }
    override fun onServiceDisconnected(name: ComponentName) {   // service process died; the binding stays
        remote = null
    }
    override fun onBindingDied(name: ComponentName) { /* API 26+: unbind and bind again */ }
    override fun onNullBinding(name: ComponentName) { /* API 28+: onBind() returned null */ }
}

val intent = Intent("com.example.aidldemo.IMyAidlInterface").setPackage("com.example.aidldemo")
bindService(intent, connection, Context.BIND_AUTO_CREATE)
// ... unbindService(connection) in the matching lifecycle callback
```

+ `bindService()` goes to ActivityManagerService (itself registered in `servicemanager` as `"activity"`).
  AMS finds the component, starts its process if needed, calls the service's `onBind()`, and hands the binder back through the callback.
+ `onServiceDisconnected()` is called only when the service process dies, not on `unbindService()`.
+ The full walkthrough (Gradle, manifest, cross-app checklist) is in [AIDL_binding.md](AIDL_binding.md).

## 2. `ServiceManager` (platform code)

```java
// Platform code only (built with platform_apis / in the framework)
IBinder b = ServiceManager.waitForDeclaredService(
        "vendor.example.hardware.myhal.IMyHalService/default");   // null if not in the VINTF manifest
IMyHalService hal = IMyHalService.Stub.asInterface(b);
```

+ `android.os.ServiceManager` is `@hide`. Apps built with the public SDK can't call it,
  and reflection is blocked by the hidden-API restrictions (Android 9+).
+ Even platform code needs SELinux permission to **find** the service.
  For a HAL, that means the client domain has `hal_client_domain()`. Signing the app with the platform key doesn't grant that by itself.
+ Apps reach system services through `Context.getSystemService()`.
  The framework's `SystemServiceRegistry` looks up the binder in `servicemanager` and wraps it in a manager class (`PowerManager`, ...).
+ The native API, the add/find rules, and debugging are in [ServiceManager_ndk.md](ServiceManager_ndk.md).

## 3. How they fit together

```text
3rd-party app ──bindService()──► AMS ──► system app's <service> (exported, signature/custom permission)
                                              │
                                              └─ServiceManager lookup──► vendor AIDL HAL (/dev/binder)
```

A 3rd-party app can't use `ServiceManager`. It binds to a system app, and the system app uses `ServiceManager` to reach the HAL.
See [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md).

## Related notes

+ [AIDL_binding.md](AIDL_binding.md), [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md), [ServiceManager_ndk.md](ServiceManager_ndk.md)
+ [Binder_intro.md](Binder_intro.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md)

## Reference

+ [`ServiceConnection`](https://developer.android.com/reference/android/content/ServiceConnection)
+ [Bound services overview](https://developer.android.com/develop/background-work/services/bound-services)
+ [Restrictions on non-SDK interfaces](https://developer.android.com/guide/app-compatibility/restrictions-non-sdk-interfaces)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
