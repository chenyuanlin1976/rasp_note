# JNI notes

On Android, JNI (Java Native Interface) is the standard programming framework  
that allows Java/Kotlin code running inside the Android Runtime (ART) to interact with code written in native languages like C and C++.

While Android apps are primarily written in Java or Kotlin,  
you might wonder why we sometimes need to drop down to C/C++. Here are the core reasons:

## 1. Performance and Compute-Heavy Tasks

Java and Kotlin run on a virtual machine (ART) and use automatic garbage collection.  
For most everyday app tasks, this is plenty fast.  
However, certain heavy workloads require maximum hardware performance:

+ Real-time processing: 3D rendering (OpenGL/Vulkan), game engines (like Unreal or Unity), and physics simulations.
+ Media processing: Video/audio decoding, encoding, and real-time image filtering.
+ Heavy mathematics: Cryptography, computer vision (like OpenCV), or machine learning inference  
  (like TensorFlow Lite running on native hardware accelerators).

## 2. Code Reusability and Legacy Libraries

A massive amount of open-source software, standard libraries, and cross-platform business logic is written in C or C++.

+ Instead of rewriting complex libraries (such as SQLite, FFmpeg, or custom physics engines) from scratch in Java or Kotlin,  
  developers use JNI as a **bridge** to reuse existing, battle-tested C/C++ codebases across multiple platforms (like iOS and Android).

## 3. Direct Hardware Access and Low-Level Control

While the Android SDK provides high-level APIs for most hardware features,  
C/C++ gives you finer, closer-to-the-metal control when you need it:

+ Interacting directly with specific hardware components, sensors,  
  or external devices connected via USB or Bluetooth.
+ Direct memory management (allocating and freeing memory manually),  
  which can reduce garbage collection overhead and latency spikes in performance-critical loops.

## 4. Security and Code Protection (Obfuscation)

Java and Kotlin bytecode are relatively easy to decompile back into readable source code using free tools.

+ C and C++ compile directly into native machine code (binary libraries like `.so` files), which is much harder to reverse-engineer.  
  Developers often move sensitive algorithms, license verification, or anti-cheat mechanisms into native code for better security.

## The Trade-offs of Using JNI

While powerful, JNI isn't a silver bullet. You should only use it when necessary because:

+ Complexity: Writing C/C++ code introduces risks like memory leaks, buffer overflows, and segmentation faults  
  that don't typically happen in managed languages like Kotlin.
+ Development Overhead: Building and debugging native code requires additional toolchains  
  like the Android NDK (Native Development Kit) and CMake.
+ Cross-VM Overhead: Crossing the barrier between the JVM/ART and the native C environment incurs a small performance overhead.  
  Frequent, tiny calls back and forth can actually slow down your app.

## C/C++ code running via JNI has fewer built-in safety rails

At its core, C/C++ code running via JNI does **not** automatically get special or elevated system privileges  
beyond what the Java Virtual Machine (JVM) process itself possesses.

Because the native library is loaded directly into the JVM's process memory space,  
it operates within the **exact same** OS-level security context, user permissions, and hardware access rights as the Java application running it.

Here is a detailed breakdown of **how privileges work, how C/C++ interacts with the system, and the security boundaries involved.**

### 1. The Process Boundary (The Golden Rule)

An operating system grants privileges and resources to **processes**, not programming languages.

+ Whether a process executes bytecode compiled into the JVM or  
  machine code compiled into a `.dll`, `.so`, or `.dylib` file,  
  the OS sees them **both as part of the same single process**.
+ Therefore, the C/C++ code inherits the user ID, group permissions, file access rights,  
  and network capabilities of the running Java process.

Example: If your Java application runs as a standard user (www-data on Linux, for instance),  
any file system operations or network sockets opened by your C/C++ JNI code will also run as www-data  
and will be **restricted** by those same permissions.

### 2. How C/C++ Acquires System Capabilities

While JNI code **DOESN'T** magically get "root" or administrator rights,  
C/C++ is a lower-level language than Java, meaning **it has fewer built-in safety rails.**  
**This allows native code to perform tasks that standard Java restricts or abstracts away**:

+ **Direct Memory Manipulation**:  
  C/C++ can use raw pointers, perform pointer arithmetic, and access memory addresses directly.  
  Through JNI, you can pass Java NIO direct buffers (GetDirectBufferAddress)  
  and manipulate memory outside the JVM garbage collector's tracking.
+ **Direct OS System Calls**:  
  While Java uses native methods under the hood for things like java.io or java.net,  
  **C/C++ can make direct system calls (syscall)**  
  or call native OS APIs (like the Windows Win32 API or POSIX functions on Linux/macOS) directly.
+ **Hardware & Driver Interaction**:  
  *Native code can interface with hardware drivers*, use inline assembly,  
  or **load other shared libraries** that interact directly with physical devices  
  (e.g., GPUs, USB peripherals, or specialized sensors).

### 3. Security Boundaries and Risks

Because JNI bridges the gap between managed safety and unmanaged raw power, it introduces specific security implications:

+ **No JVM Sandboxing**:  
  Java has a robust security model (historically SecurityManager, or modern module encapsulations)  
  that restricts what code can do.  
  Once execution crosses the JNI boundary into C/C++, the JVM's security sandbox is bypassed.
+ **Process Crashes**:  
  A bug in Java (like an `ArrayIndexOutOfBoundsException`) throws a catchable exception.  
  A bug in C/C++ (like a segmentation fault, buffer overflow, or null pointer dereference) will crash the entire JVM process instantly,  
  taking down your Java application with it.
+ **Privilege Escalation Risk**:  
  If the parent Java process is accidentally run with elevated privileges  
  (e.g., root on Linux or Administrator on Windows),  
  the C/C++ native code running inside it automatically shares those full system privileges,  
  making vulnerabilities like buffer overflows extremely dangerous.

### Summary Checklist

| Feature        | Java/ Kotlin (Managed)            | C / C++ via JNI (Native)                        |
| -------------- | --------------------------------- | ----------------------------------------------- |
| OS Process     | Runs inside the JVM process       | Runs inside the same JVM process                |
| Permissions    | Restricted by OS user + JVM rules | Restricted only by OS user (bypasses JVM rules) |
| Memory Safety  | Garbage-collected, bounds-checked | Manual management, raw pointers                 |
| Failure Impact | Throws catchable exceptionsCan    | crash the entire application process            |
