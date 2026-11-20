# AIDL callbacks

An AIDL **callback** is an AIDL interface that the **client** implements and passes to the **service**.
The service keeps it and calls it later to push asynchronous events, progress, or results back to the client.

A normal AIDL call goes **client → service** (blocking request/reply, or `oneway` fire-and-forget).
A callback reverses the direction: **service → client**, still over Binder IPC.
Inside the callback call, the original service is the Binder client and the original client is the Binder server.

| Item | Description |
| --- | --- |
| Direction | Service → client, over Binder |
| Client side | Implements `ICallback.Stub` and passes it in a `register...()` call |
| Service side | Receives a proxy to the client's stub and stores it |
| Storage on the service (Java) | `RemoteCallbackList<T>` |
| Storage on the service (NDK) | `std::shared_ptr<T>` plus `AIBinder_linkToDeath()` |
| Thread on the client | A binder thread, never the main/UI thread |

## 1. Why use callbacks

+ **No polling**: the work finishes later (a scan, a download, a hardware interrupt).
  Instead of asking "done yet?" again and again, the client registers a callback and gets notified.
+ **Decoupling**: a long-lived service or HAL doesn't need to know which apps are listening.
  It just calls every registered callback.
+ **Several listeners**: many clients can register their own callback with one service (publish/subscribe over Binder).

## 2. Define the interfaces

The callback interface. Here the whole interface is `oneway`, so the service never waits for the client:

```java
// IScanCallback.aidl
package com.example.service;

oneway interface IScanCallback {
    void onProgress(int percent);
    void onScanCompleted(String result);
}
```

The service interface accepts and removes callbacks:

```java
// IScannerService.aidl
package com.example.service;

import com.example.service.IScanCallback;

interface IScannerService {
    void registerCallback(IScanCallback cb);
    void unregisterCallback(IScanCallback cb);
    void startScan();
}
```

Interfaces are always `in` parameters and take no direction tag.

## 3. Client: implement the Stub

The client creates **one** `IScanCallback.Stub` object and uses the same object for register and unregister.
Callback methods run on a **binder thread** of the client process, so UI updates must hop to the main thread.

```kotlin
class ScanActivity : AppCompatActivity() {
    private var scanner: IScannerService? = null

    private val callback = object : IScanCallback.Stub() {
        override fun onProgress(percent: Int) {
            runOnUiThread { progressBar.progress = percent }   // binder thread -> main thread
        }
        override fun onScanCompleted(result: String?) {
            runOnUiThread { resultView.text = result }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            scanner = IScannerService.Stub.asInterface(service).also {
                it.registerCallback(callback)
                it.startScan()
            }
        }
        override fun onServiceDisconnected(name: ComponentName) {
            scanner = null   // the service process died; callbacks stop arriving
        }
    }

    override fun onStop() {
        try {
            scanner?.unregisterCallback(callback)
        } catch (e: RemoteException) {
            // service already gone
        }
        unbindService(connection)
        scanner = null
        super.onStop()
    }
}
```

The bind/unbind part is explained in [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md).

## 4. Service: store callbacks in `RemoteCallbackList`

Each `registerCallback()` call gives the service a new Java proxy object, even for the same client callback.
A plain `ArrayList<IScanCallback>` therefore can't find the entry again in `unregisterCallback()`,
and it keeps dead clients forever.
`RemoteCallbackList<T>` solves both problems:

+ It keys entries by `cb.asBinder()`, so unregister finds the right entry.
+ It calls `linkToDeath()` on each callback and removes it automatically when the client process dies.
+ `beginBroadcast()` takes a snapshot, so clients can register or unregister during a broadcast.

```kotlin
class ScannerService : Service() {
    private val callbacks = RemoteCallbackList<IScanCallback>()

    private val binder = object : IScannerService.Stub() {
        override fun registerCallback(cb: IScanCallback?) { cb?.let { callbacks.register(it) } }
        override fun unregisterCallback(cb: IScanCallback?) { cb?.let { callbacks.unregister(it) } }
        override fun startScan() { /* start the work on a worker thread, return immediately */ }
    }

    // beginBroadcast() must not be nested or run on 2 threads at once
    @Synchronized
    private fun notifyProgress(percent: Int) {
        val n = callbacks.beginBroadcast()
        try {
            for (i in 0 until n) {
                try {
                    callbacks.getBroadcastItem(i).onProgress(percent)
                } catch (e: RemoteException) {
                    // the client died during the broadcast; the list drops it by itself
                }
            }
        } finally {
            callbacks.finishBroadcast()
        }
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun onDestroy() {
        callbacks.kill()
        super.onDestroy()
    }
}
```

`RemoteCallbackList` does **not** stop the exception from being thrown.
A client can die between the snapshot and the call, so each call still needs its own `try`/`catch`.

## 5. Native services and HALs (NDK backend)

The NDK backend has no `RemoteCallbackList`.
The service stores the callback as `std::shared_ptr<IScanCallback>` and watches the client with a death recipient:

```c++
#include <aidl/com/example/service/BnScannerService.h>
#include <android/binder_ibinder.h>
#include <mutex>

using aidl::com::example::service::IScanCallback;

class Scanner : public aidl::com::example::service::BnScannerService {
  public:
    Scanner() : mDeath(AIBinder_DeathRecipient_new(onClientDied)) {}

    ndk::ScopedAStatus registerCallback(const std::shared_ptr<IScanCallback>& cb) override {
        if (cb == nullptr) return ndk::ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
        std::lock_guard<std::mutex> lock(mLock);
        mCallback = cb;
        AIBinder_linkToDeath(cb->asBinder().get(), mDeath.get(), this);
        return ndk::ScopedAStatus::ok();
    }
    // unregisterCallback(): AIBinder_unlinkToDeath() and reset mCallback

  private:
    static void onClientDied(void* cookie) {
        auto* self = static_cast<Scanner*>(cookie);
        std::lock_guard<std::mutex> lock(self->mLock);
        self->mCallback = nullptr;
    }

    std::mutex mLock;
    std::shared_ptr<IScanCallback> mCallback;
    ndk::ScopedAIBinder_DeathRecipient mDeath;
};
```

For several clients, keep a container of callbacks and compare them with `cb->asBinder()`,
because 2 `shared_ptr`s to the same remote binder are not necessarily the same object.
A full vendor HAL (VINTF, SELinux) is in [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md).

## 6. Rules and pitfalls

+ **Make callbacks `oneway`**: a normal callback blocks the service's thread until the client returns.
  A slow or hung client then stalls the service.
  `oneway` methods have no return value and no `out`/`inout` parameters.
  Declare the whole callback interface `oneway` instead of mixing (`-Wmixed-oneway`, see [AIDL_intro.md](AIDL_intro.md)).
+ **Ordering**: `oneway` calls to the same binder object arrive one at a time, in order.
  Calls to different clients are independent.
+ **Don't flood**: `oneway` calls use the receiver's async buffer, which is limited.
  Throttle high-rate events (e.g. send progress only when the percent changes). See [AIDL_call_flow.md](AIDL_call_flow.md).
+ **Client thread**: callbacks run on a binder thread. Never touch views there; post to the main thread
  (`runOnUiThread`, `Handler(Looper.getMainLooper())`, `LiveData`/`Flow`).
+ **Service thread**: don't call callbacks while holding a lock that `registerCallback()` also needs,
  and don't run long work inside `startScan()` itself; return and report through the callback.
+ **Same object for unregister**: keep one Stub instance on the client. A new Stub is a different binder.
+ **Always unregister** in the matching lifecycle callback (`onStop`/`onDestroy`) before unbinding.
  Death notification cleans up after crashes, not after normal exits of a live process.
+ **Security**: `registerCallback()` is a normal incoming call. Check the caller
  (`Binder.getCallingUid()`, permissions) before accepting the callback, as for any other method.

## 7. Typical use cases

| Area | Example callbacks |
| --- | --- |
| Hardware events (GPIO, keys, sensors) | `onKeyEvent(keyCode, action)`, `onValueChanged(value)` from a system service or HAL |
| Device state | USB attach/detach, network link up/down, power/suspend preparation |
| Long-running jobs | Firmware/OTA update, file transfer, media scan: `onProgress(percent)`, `onComplete(success, msg)` |
| Connections and sessions | Bluetooth or daemon link: `onConnected()`, `onDisconnected()`, `onError(code)` |
| Media | Playback state changes (playing, paused, track changed) |
| Shared platform services | Several apps listen for the same configuration or status change |

On a custom board (e.g. RK3566), the usual chain is HAL → system service → app, with a callback interface at each Binder hop.
3rd-party apps get the events from a system app's bound service, not directly from the HAL
(see [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)).

## Related notes

+ [AIDL_intro.md](AIDL_intro.md): AIDL basics, `oneway`, threading
+ [AIDL_call_flow.md](AIDL_call_flow.md): what happens during one call, binder buffer limits
+ [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md): app-level bound service and client
+ [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md): exposing an AOSP service to 3rd-party apps
+ [Binder_intro.md](Binder_intro.md): Binder basics, caller UID
+ [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md): complete vendor AIDL HAL

## Reference

+ [Android Interface Definition Language (AIDL)](https://developer.android.com/develop/background-work/services/aidl)
+ [RemoteCallbackList](https://developer.android.com/reference/android/os/RemoteCallbackList)
+ [IBinder.DeathRecipient](https://developer.android.com/reference/android/os/IBinder.DeathRecipient)
+ [AIDL overview (AOSP)](https://source.android.com/docs/core/architecture/aidl)
+ [AIDL style guide](https://source.android.com/docs/core/architecture/aidl/aidl-style-guide)
