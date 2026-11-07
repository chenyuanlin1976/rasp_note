# Binder IPC

Binder is Android's main inter-process communication (IPC) mechanism.
Apps, system services, and HALs call each other through it: a call looks like a method call on an object,
but the object lives in another process.
It consists of a kernel driver (`drivers/android/binder*.c`, `CONFIG_ANDROID_BINDER_IPC`, in mainline Linux)
and user-space libraries that implement the protocol.

```text
process A (client)                           process B (server)
interface proxy (generated)                  stub (generated) -> your implementation
libbinder / libbinder_ndk                    libbinder / libbinder_ndk, binder thread pool
        |  ioctl(BINDER_WRITE_READ)                  ^  thread returns from ioctl
        v                                            |
     ------------------  Binder driver (kernel)  ------------------
     routes by handle -> node, copies data once into B's mmap'd buffer, wakes a B thread
```

The step-by-step path of one call, and the size and thread limits, are in [AIDL_call_flow.md](AIDL_call_flow.md).

## 1. Why Binder and not sockets or pipes

| Need | Binder's answer |
| --- | --- |
| Object-oriented RPC | A remote object is referenced by a **handle**. Calls are transactions on that object, with a reply |
| Caller identity | The driver attaches the caller's **UID** and **PID** to each transaction. The server reads them (`Binder.getCallingUid()`, `AIBinder_getCallingUid()`), so the client can't fake them |
| Mandatory access control | SELinux checks every transaction (`binder { call transfer }`) and the service-manager registrations |
| Passing capabilities | A `Parcel` can carry **binder objects** and **file descriptors**. The driver translates them for the receiving process |
| Object lifetime | The driver counts references across processes (`binder_node` / `binder_ref`) and sends **death notifications** (`linkToDeath`) when the owning process dies |
| Performance | The payload is copied **once**, from the sender into a buffer that the receiver has `mmap`'d. A pipe or socket copies it twice (into the kernel, then out) |

Notes:

+ Use the **UID** for security decisions. The PID can be reused, and `oneway` transactions don't carry a PID at all (it reads as 0).
+ "Single copy" counts the kernel step only. Serializing into a `Parcel` and reading it back are copies in user space.
  HIDL's scatter-gather (Android 8) also removed those for its data structures.

## 2. Building blocks

| Part | Role |
| --- | --- |
| Binder driver | Device nodes, transaction routing, buffer allocation, thread wake-up, reference counts |
| Context manager | The process that owns **handle 0** on a device node (`BINDER_SET_CONTEXT_MGR`). It is the name registry: `servicemanager` on `/dev/binder` |
| `Parcel` | The message container: primitive data, binder objects, file descriptors |
| `IBinder` / `BBinder` / `BpBinder` | Java and C++ base types for local objects (`Binder`, `BBinder`) and remote references (`BinderProxy`, `BpBinder`) |
| Thread pool | Server threads blocked in `ioctl()` that wait for incoming transactions (Java: up to 15 extra threads by default) |
| Generated code | AIDL (or HIDL) generates the proxy (client) and stub (server) that marshal the `Parcel` |

User-space libraries:

| Library | Used by |
| --- | --- |
| `android.os.Binder` (Java, through JNI to `libbinder`) | Apps, `system_server`, framework |
| `libbinder` (C++, `android::sp`, `IBinder`) | Platform-internal native code (AIDL `cpp` backend) |
| `libbinder_ndk` (C API, `AIBinder_*`, `ndk::` wrappers) | Stable ABI: vendor code, HALs, APEX modules (AIDL `ndk` backend) |
| `libbinder_rs` | Rust (AIDL `rust` backend) |
| `libhwbinder` / `libhidlbase` | HIDL HALs (legacy) |

## 3. Binder devices (contexts)

Since Android 8, there are 3 Binder **contexts**. Each one has its own device node and its own context manager.
A binder object never crosses from one context to another.

| Device | Context manager | Traffic | Status |
| --- | --- | --- | --- |
| `/dev/binder` | `servicemanager` | Apps ↔ framework, framework ↔ **AIDL HALs**, vendor ↔ vendor with stable AIDL | Main path |
| `/dev/hwbinder` | `hwservicemanager` | Framework ↔ **HIDL** HALs | Legacy (HIDL deprecated since Android 10) |
| `/dev/vndbinder` | `vndservicemanager` | Vendor ↔ vendor, AIDL | Deprecated since Android 11; devices launching with 11+ must opt in (`PRODUCT_PACKAGES += vndservicemanager`) |

+ Vendor processes can't use `/dev/binder` with unstable interfaces.
  Since Android 10/11, **stable AIDL** (`@VintfStability`, NDK or Rust backend) lets vendor processes use `/dev/binder`.
  That is why `/dev/vndbinder` is no longer recommended for new vendor ↔ vendor interfaces.
+ On newer kernels, the nodes can come from **binderfs** (a filesystem that creates Binder devices on demand),
  and `/dev/binder` etc. are links into it.

## 4. Interface languages on top of Binder

Binder only moves transactions. An interface definition language generates the code that turns method calls into transactions:

| Language | Device | Status | Note |
| --- | --- | --- | --- |
| **AIDL** | `/dev/binder` (or `/dev/vndbinder`) | Current, for apps, services, and HALs (stable AIDL since Android 11 for HALs) | [AIDL_intro.md](AIDL_intro.md) |
| **HIDL** | `/dev/hwbinder` | Deprecated since Android 10; still found on upgraded devices | [HIDL_intro.md](HIDL_intro.md), [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md) |
| Hand-written `transact()` / `onTransact()` | Any | Possible, but no versioning or type checking | — |

## 5. Inspect Binder on a device

```shell
adb shell service list                                  # services in servicemanager
adb shell dumpsys -l
adb shell ls -l /dev/binder /dev/hwbinder /dev/vndbinder   # links into binderfs on newer devices
adb shell cat /dev/binderfs/binder_logs/stats           # driver statistics (root, if binderfs is mounted)
adb shell cat /dev/binderfs/binder_logs/state           # per-process nodes, refs, threads (root)
adb logcat | grep -E "FAILED BINDER TRANSACTION|TransactionTooLarge"   # oversized / failed transactions
```

On older kernels, the same files are in debugfs: `/sys/kernel/debug/binder/`.

## Related notes

+ [AIDL_call_flow.md](AIDL_call_flow.md): one call through proxy, driver, and stub, plus the limits
+ [AIDL_intro.md](AIDL_intro.md), [AIDL_backends.md](AIDL_backends.md), [HIDL_intro.md](HIDL_intro.md), [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md)
+ [ServiceManager_ndk.md](ServiceManager_ndk.md), [HAL_history.md](HAL_history.md), [SELinux_policy.md](SELinux_policy.md)

## Reference

+ [Binder IPC: contexts, scatter-gather, vndbinder (AOSP)](https://source.android.com/docs/core/architecture/hidl/binder-ipc)
+ [`android.os.Binder`](https://developer.android.com/reference/android/os/Binder), [`android.os.IBinder`](https://developer.android.com/reference/android/os/IBinder)
+ [binderfs (kernel docs)](https://docs.kernel.org/admin-guide/binderfs.html)
