# AIDL (Android Interface Definition Language)

AIDL is a tool used in Android to define the programming interface that  
both a client and a service agree upon to communicate with each other using **Inter-Process Communication (IPC)**.  

Because Android processes run in their own isolated memory spaces,  
an object cannot normally access memory in another process.  
AIDL abstracts away the complex underlying mechanics of marshalling objects into primitives,  
passing them across the kernel via **Android's Binder driver**, and unmarshalling them on the other side.

## How AIDL Works

+ The `.aidl` File: You define an **interface** with method signatures using a syntax similar to Java or C++.  
+ Code Generation: During compilation, the Android build system parses the `.aidl` file  
  and automatically generates a matching interface file in Java or C++.  
+ Stub and Proxy: The generated code includes two primary inner components:  
  + **Stub (Server-side)**: An abstract Binder class that extends IInterface and listens for incoming transaction requests,  
    routing them to your service implementation.  
  + **Proxy (Client-side)**: A wrapper that converts method calls and parameters into a Parcel packet  
    and sends them across the Binder driver to the remote process.  

## Supported Data Types

+ Primitive Java types (int, long, char, boolean, etc., except short)  
+ String and CharSequence
+ Arrays and Lists/Maps of supported types (Lists/Maps automatically resolve to ArrayList and HashMap on delivery)
+ Other AIDL-generated interfaces and custom Parcelable objects.

## Common Use Cases

+ Bound Services: Allowing a background service in one application to serve requests from multiple client apps.
+ AOSP System Services: Communicating between Android framework core services and applications  
  (e.g., interacting with hardware managers, telephony, or media services).  
+ HAL (Hardware Abstraction Layer): Modern Android architectures utilize stable AIDL interfaces  
  to communicate reliably between native system processes and hardware drivers.
