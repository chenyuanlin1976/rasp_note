# AIDL (Android Interface Definition Language)

AIDL is the language Android uses to define the **programming interface** that a **client** and a **service**
agree on so that they can talk to each other through **Inter-Process Communication (IPC)**.

Every Android process runs in its own isolated memory space, so process A **cannot** call a method or read memory inside process B.
AIDL generates the boilerplate that hides this:

+ **marshalling**: packing the arguments into a `Parcel`
+ sending the `Parcel` through the kernel's **Binder driver**
+ **unmarshalling** it again on the other side

| Item | Description |
| --- | --- |
| Layer | Every layer: app ↔ app, app ↔ system service, framework ↔ HAL (stable AIDL) |
| Purpose | Defines the methods and data types that 2 processes use to talk to each other |
| Transport | Binder (`/dev/binder`; the older vendor ↔ vendor `/dev/vndbinder` is deprecated since Android 11) |
| Backends | Java (Kotlin uses it), C++ `cpp`, C++ `ndk`, Rust: see [AIDL_impl_langs.md](AIDL_impl_langs.md) |

## 1. How AIDL works

1. **Define the interface**: write an `.aidl` file with a Java-like syntax that lists the methods.
2. **Code generation**: the build (Gradle or Soong) generates an interface in the backend language.
   For apps, this is a **Java** file (Kotlin code calls the generated Java classes; the compiler does not emit Kotlin).
3. **Server side**: the service implements the abstract inner class **`Stub`**.
4. **Client side**: the client gets an `IBinder` (from `bindService()` or `ServiceManager`)
   and turns it into the interface with `IYourInterface.Stub.asInterface(binder)`.

The generated code contains 2 key classes:

+ **`Stub` (server side)**: an abstract class that **extends `android.os.Binder`** and **implements your interface**.
  `onTransact()` unmarshals the incoming `Parcel` and calls your implementation.
+ **`Stub.Proxy` (client side)**: implements the same interface.
  Each method marshals the arguments into a `Parcel`, calls `transact()` across Binder, and unmarshals the reply.
  If the binder is in the same process, `asInterface()` returns the local `Stub` object directly, with no IPC and no Proxy.

The full transaction path is in [AIDL_call_flow.md](AIDL_call_flow.md).

## 2. Minimal example

```java
// IMyService.aidl
package com.example.myapp;

interface IMyService {
    int getScore();
    void updateScore(int newScore);
}
```

```java
// Server: return the Stub from onBind()
public class MyService extends Service {
    private volatile int score = 100;   // binder threads call concurrently -> keep it thread-safe

    private final IMyService.Stub binder = new IMyService.Stub() {
        @Override public int getScore()               { return score; }
        @Override public void updateScore(int value)  { score = value; }
    };

    @Override
    public IBinder onBind(Intent intent) { return binder; }
}
```

```java
// Client: convert the IBinder inside ServiceConnection
@Override
public void onServiceConnected(ComponentName name, IBinder service) {
    myService = IMyService.Stub.asInterface(service);
}
```

The complete Android Studio walkthrough (Gradle, manifest, client lifecycle) is in [AIDL_binding.md](AIDL_binding.md).

## 3. Supported data types

+ Primitives: `boolean`, `byte`, `char`, `int`, `long`, `float`, `double`. **`short` is not supported.**
+ `String`, `IBinder`, `ParcelFileDescriptor` (`ndk::ScopedFileDescriptor` in the NDK backend)
+ Arrays of the supported types (`int[]`, `String[]`, ...)
+ `List<T>` (`List<String>`, `List<MyParcelable>`). Java gets an `ArrayList`, and C++ gets a `std::vector`.
  A raw, untyped `List` works only in the Java backend and isn't allowed in stable interfaces.
+ **Java backend only**: `CharSequence`, `FileDescriptor`, and `Map` (the receiver gets a `HashMap`).
  The C++/NDK/Rust backends have no `Map`; use a `List` of key/value parcelables instead.
+ Other AIDL interfaces (for callbacks), plus `parcelable` types (structured AIDL parcelables, or Java classes that implement `Parcelable`)
+ Constants (`const int VERSION = 1;`), `enum` types (`@Backing(type="int")`), and `union` types (Android 12+)

The exact per-backend table is in the AOSP "AIDL backends" page.

## 4. Constraints and design rules

### 4.1 Things the language does not allow

+ **Arbitrary classes**: anything you pass must be one of the types above. Other classes must become a `parcelable`.
+ **Fields / static state**: an interface may contain only methods and constants.
+ **`short`** (see above).
+ **Direction tags**: arrays, lists, and parcelables need `in`, `out`, or `inout` (e.g. `void fill(out int[] buf)`).
  Primitives, `String`, `IBinder`, and interfaces are always `in` and take no tag.

### 4.2 Design patterns that the AIDL style guide (and `aidl` warnings) flags

+ **Mixing `oneway` and normal methods** in one interface (`-Wmixed-oneway`):
  this makes the threading model hard to understand for both sides.
+ **Returning custom integer status codes**: throw `ServiceSpecificException` (Java)
  or return `ScopedAStatus::fromServiceSpecificError()` (NDK) instead.
+ **`out` array parameters** (`-Wout-array`): in Java, the caller must pre-allocate the array,
  so the server cannot choose the size. Return the array instead.

### 4.3 Threading

+ Incoming remote calls run on the **binder thread pool**.
  In a Java app, that is never the main/UI thread.
  In a native service, the main thread often joins the pool (`joinThreadPool()`), so it handles calls too.
+ Several clients (or one client with several threads) can call at the same time, so the implementation **must be thread-safe**.
+ On the client side, a normal (non-`oneway`) call **blocks** until the reply arrives.
  Calling from the UI thread can cause an ANR.
+ A `oneway` method returns immediately and has no return value or exceptions.
  `oneway` calls to the **same binder object** are delivered one at a time, in order.
  A `oneway` call to a binder in the **same process** still runs synchronously.

## 5. Local vs remote service

You need AIDL only if the service runs in **another process**.

| | Local service | Remote service |
| --- | --- | --- |
| Process | Same process as the caller | Separate process (another app, a system service, or your own `android:process=":remote"`) |
| Communication | Direct method calls: return a plain `Binder` subclass from `onBind()` | Binder IPC through **AIDL** (or `Messenger`) |
| Data passing | By reference (shared heap) | Marshalled into a `Parcel`, copied by the Binder driver |
| Threading | Runs on the caller's thread | Runs on a binder thread, so it must be thread-safe |
| Typical use | App-internal background work | Exposing features to other apps, system services, HALs |

The package name does **not** tell you local vs remote.
A service in your own package still runs in a different process if the manifest says so:

```xml
<!-- Same package, but a remote process -->
<service
    android:name=".MyRemoteService"
    android:process=":remote_process" />
```

## 6. Marshalling and Parcelable

**Marshalling** (serialization) converts an in-memory object into a flat byte stream (a `Parcel`).
**Unmarshalling** rebuilds the object on the other side.
`Parcelable` is Android's IPC-optimized mechanism. It is much faster than Java `Serializable`,
but it is meant for IPC, not for persistent storage. See also [marshalling.md](marshalling.md).

## 7. Stable AIDL

Normal AIDL assumes both sides are built together.
**Stable AIDL** (`aidl_interface` with `versions` / `stability: "vintf"`) freezes each API version.
Then the client and server can be updated independently, which is how AIDL replaced HIDL for HALs.
See [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md) and [AIDL_HAL_impl.md](AIDL_HAL_impl.md).

## Related notes

+ [AIDL_impl_langs.md](AIDL_impl_langs.md): backends (Java / CPP / NDK / Rust)
+ [AIDL_call_flow.md](AIDL_call_flow.md): what happens during one call
+ [AIDL_binding.md](AIDL_binding.md): app-level bound service, step by step
+ [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md): exposing an AOSP service to 3rd-party apps
+ [AIDL_HAL.md](AIDL_HAL.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md): AIDL HALs

## Reference

+ [Android Interface Definition Language (AIDL)](https://developer.android.com/develop/background-work/services/aidl)
+ [AIDL overview (AOSP)](https://source.android.com/docs/core/architecture/aidl)
+ [AIDL style guide](https://source.android.com/docs/core/architecture/aidl/aidl-style-guide)
