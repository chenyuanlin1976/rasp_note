# AIDL and Binder

The relationship between Binder and AIDL is essentially the relationship between a low-level engine and an automatic transmission.

**Binder provides the raw, powerful mechanism for IPC**,  
while **AIDL provides the developer-friendly language and tooling to use that mechanism**  
without writing hundreds of lines of complex, error-prone boilerplate code.

## 1. High-Level Comparison

### Feature of Binder

+ What is it: A kernel-level IPC driver and communication framework (/dev/binder).
+ Layer: Operating System Kernel & C++ Native Layer.
+ Responsibility: Routing data, managing process lifecycles, memory mapping, thread pooling, and security (UID/PID tracking).

### Feature of AIDL

+ What is it: A code-generation tool and interface definition language.
+ Layer: Application/ Build Layer (Java, Kotlin, C++).
+ Responsibility: Defining the method signatures, marshalling arguments into Parcel objects, and unmarshalling them on the receiving end.

## 2. How They Work Together: The Pipeline

When you want 2 different processes to talk to each other (for example, your App and a background Music Service),  
writing raw Binder code requires manually packing data into a binary container called a Parcel,  
issuing specific `ioctl()` system calls to the kernel driver, and handling error codes.

**AIDL completely automates this workflow**:

### 1. You Write an Interface (.aidl)

You define a simple interface listing the methods and parameters you want to share, similar to a standard Java/Kotlin interface:

```java
// IPlayMusic.aidl
interface IPlayMusic {
    void playSong(String songTitle, int volume);
    String getCurrentSong();
}
```

### 2. The Build System Generates Code

During compilation, the AIDL compiler (aidl executable) reads your `.aidl` file  
and automatically generates a concrete Java or Kotlin implementation class containing 2 main inner components:

+ **The Proxy (Client Side)**: Implements your `IPlayMusic` interface.  
  When your app calls playSong(), the Proxy takes the arguments, packs them into a Parcel buffer,  
  and invokes the underlying **Binder driver** (`mRemote.transact(...)`) to send it across process boundaries.
+ **The Stub (Server Side)**: An abstract class that extends **Binder**.  
  When the Binder driver delivers the raw transaction to the target process,  
  the **Stub** receives the Parcel, unpacks (unmarshals) the arguments, and calls the actual method implementation you wrote on your service.

### 3. Binder Executes the Transport

The generated code acts as the bridge.  
It translates your high-level method calls into low-level Binder transactions,  
relying on the /dev/binder driver to safely move the data between process boundaries in the kernel.

## 3. Summary of Roles

+ Without AIDL, using Binder would require manual serialization, parsing error-prone binary buffers,  
  and writing verbose native C++ or JNI code for every single method call.
+ Without Binder, AIDL would just be an empty template language with no underlying transport mechanism to cross process boundaries.
