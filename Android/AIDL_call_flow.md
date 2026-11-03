# AIDL: call flow diagram

The diagram shows how one synchronous AIDL call travels from the client, through the Binder driver in the Linux kernel,
to the server, and back.

## 1. Diagram

```text
+-------------------------------------------------------------------+
| CLIENT PROCESS (user space)                                       |
|                                                                   |
|  [ Client code ]                                                  |
|        |  calls IFoo.method(args)                                 |
|        v                                                          |
|  [ IFoo.Stub.Proxy ]   (generated, implements IFoo)               |
|        |  1. marshal args into a Parcel, call transact()          |
|        v                                                          |
|  [ android.os.Binder -> JNI -> libbinder ]  (C++: libbinder(_ndk))|
+--------|----------------------------------------------------------+
         |  2. ioctl(BINDER_WRITE_READ) on /dev/binder
         v
+-------------------------------------------------------------------+
| LINUX KERNEL: Binder driver                                       |
|                                                                   |
|  3. find target process/node, copy the Parcel ONCE from the       |
|     client into a buffer that is mmap'd into the server process,  |
|     wake an idle server binder thread                             |
+--------|----------------------------------------------------------+
         |  4. the waiting server thread returns from its ioctl()
         v
+-------------------------------------------------------------------+
| SERVER PROCESS (user space)                                       |
|                                                                   |
|  [ binder thread pool thread (libbinder) ]                        |
|        v                                                          |
|  [ IFoo.Stub.onTransact() ]  5. unmarshal Parcel                  |
|        v                                                          |
|  [ Your implementation ]     6. run logic, write reply Parcel     |
+--------|----------------------------------------------------------+
         |  ioctl() with BC_REPLY
         v
+-------------------------------------------------------------------+
| LINUX KERNEL: Binder driver                                       |
|  7. copy the reply into the client's buffer, wake the client      |
+--------|----------------------------------------------------------+
         v
+-------------------------------------------------------------------+
| CLIENT PROCESS                                                    |
|  8. Proxy unmarshals the reply (or throws RemoteException)        |
|     and returns the value to the caller                           |
+-------------------------------------------------------------------+
```

## 2. Step by step

1. **Proxy**: the client calls a method on the interface object it got from `Stub.asInterface()`.
   For a remote binder, this object is the generated `Stub.Proxy`.
   It writes the interface token and the arguments into a `Parcel` and calls `transact()`.
2. **Into the kernel**: Java goes through `android.os.Binder` → JNI → `libbinder`.
   C++ goes through `libbinder` or `libbinder_ndk` directly.
   The library calls `ioctl(BINDER_WRITE_READ)` on `/dev/binder`.
   The calling thread **blocks** until the reply arrives (unless the method is `oneway`).
3. **Kernel routing**: the Binder driver finds the target node, then copies the data **one time**
   from the client's memory into a buffer that is already `mmap`'d into the server's address space.
   That's why Binder is called a *single-copy* IPC. Then the driver wakes an idle server thread.
4. **Server thread pool**: the thread pool lives in the **server's user space**.
   Its threads wait in `ioctl()`, and one of them returns with the transaction.
5. **Stub dispatch**: `Stub.onTransact()` checks the interface token, unmarshals the arguments, and calls your method.
6. **Execution and reply**: your method runs.
   For a synchronous call, the return value (or exception) goes into a reply `Parcel`, which is sent back with `ioctl()`.
   A `oneway` call has no reply, so the client doesn't wait.
7. **Reply routing**: the driver copies the reply to the client and wakes the blocked client thread.
8. **Return**: the Proxy unmarshals the reply. It returns the value or throws the exception.
   If the server process has died, the client gets a `DeadObjectException` (`RemoteException`).

## Related notes

+ [AIDL_intro.md](AIDL_intro.md)
+ [Binder_IPC_driver.md](Binder_IPC_driver.md), [Binder_AIDL.md](Binder_AIDL.md)

## Reference

+ [Binder overview (AOSP)](https://source.android.com/docs/core/architecture/hidl/binder-ipc)
