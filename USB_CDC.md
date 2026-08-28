# USB CDC

USB CDC stands for Universal Serial Bus **Communication Device Class**.  
It is a formal specification defined by the USB Implementers Forum (USB-IF)  
that allows electronic devices to communicate with a host computer by emulating standard communication interfaces,  
such as *traditional serial ports (UART) or network connections*.

Instead of requiring custom, proprietary drivers for every new hardware device,  
operating systems (Windows, macOS, Linux) often include built-in, generic drivers for standard CDC subclasses.  
This allows devices to work "out of the box."

## Key Subclasses of USB CDC

The CDC specification is divided into several models or subclasses  
depending on what type of interface the device needs to emulate:

+ **ACM (Abstract Control Model)**: The most common subclass. It emulates a *traditional RS-232 serial/COM port*.  
  Microcontrollers (like Arduino, ESP32, and STM32) use this so you can send and receive text via a Serial Monitor.
+ ECM (Ethernet Control Model) / NCM (Network Control Model): Used to emulate wired Ethernet adapters over a USB connection.  
  Devices like USB-to-Ethernet dongles or tethered smartphones use these to provide network access.
+ OBEX (Object Exchange) & ATM: Less common subclasses used for file transfers and ATM-style networking over USB.

## How USB CDC-ACM Works (Virtual COM Ports)

When you plug a microcontroller into your computer and open a terminal program, USB CDC-ACM translates data streams:

1. Data Packets: The device packages serial data into standard USB **bulk transfer packets**.
2. Enumeration: Upon connection, the device tells the operating system, "I am a CDC-compliant communication device."
3. Driver Assignment: The OS assigns a generic driver (e.g., usbser.sys on Windows or built-in kernel modules on Linux/macOS)  
   and creates a virtual port (like COM3 or **`/dev/ttyACM0`**).
4. Communication: Software applications can read and write to this virtual port just like an old-school hardware serial cable.

## Advantages and Use Cases

+ No Custom Drivers Needed: Major operating systems support CDC-ACM natively, saving developers from writing proprietary Windows/Mac drivers.
+ Debugging and Logging: Invaluable for embedded systems development, allowing microcontrollers to stream debug logs directly to a PC.
+ Firmware Updates: Used in bootloaders to receive new firmware binaries over a simple serial connection.

## When the OS is Android

When the OS is Android, USB CDC functions in one of 2 directions depending on whether  
the Android device acts as a **USB Host** (plugging an external device into the phone)  
or a **USB Device**/Accessory (plugging the phone into a PC or another microcontroller).

### Android as a USB Host (Connecting external hardware to a phone/tablet)

If you plug an Arduino, an STM32, or a USB-to-serial adapter into an Android phone via an **OTG (On-The-Go) cable**,  
the external hardware is presenting itself as a USB CDC-ACM device.

+ The Challenge: Standard Android does **NOT** expose traditional Linux serial device nodes like `/dev/ttyACM0`  
  to regular user-space apps due to security sandboxing and lack of built-in driver bindings in the Android framework.
+ The Solution: Android apps use **the Android USB Host API** (`android.hardware.usb`) combined with user-space driver libraries.
+ Popular Libraries: Libraries like usb-serial-for-android talk directly to the USB endpoints over Java/Kotlin,  
  allowing apps to read and write bytes from CDC-ACM hardware without needing root access.

### Android as a USB Device (Connecting a phone to a PC or Host)

If an Android device is acting as a gadget (e.g., tethering, or custom hardware running Android Things/embedded Android communicating with a PC),  
it can emulate a USB CDC interface.  

+ Gadget Serial (`/dev/ttyGS0`): Android's underlying Linux kernel supports USB gadget drivers.  
  By configuring the kernel's ConfigFS, an Android system can present itself to a connected PC as a virtual COM port (CDC-ACM).  
+ Use Case: Developers building custom Android-based hardware or kiosks use this to stream logs, debug via a PC terminal,  
  or exchange data over a standard USB cable using native daemons or libraries (like gadget-serial).
