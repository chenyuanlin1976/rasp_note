# USB OTG (On-The-Go)

In MCUs, **USB OTG (On-The-Go)** allows the MCU to dynamically switch its role  
between a **USB Device** (acting as a peripheral to a PC) and a **USB Host** (controlling its own peripherals).  

Unlike a smartphone where OTG is mostly used for consumers to plug in thumb drives,  
an MCU's OTG functionality is highly utilized in industrial, commercial, and embedded systems engineering.

## the most common use cases

1. Dual-Purpose Firmware Updates (Field Maintenance)  
   This is arguably the most common professional application for an MCU with OTG capabilities.  
   + **As a Device (DFU Mode)**: When connected to a technician's laptop or PC,  
     *the MCU acts as a USB Device* using Device Firmware Upgrade (DFU) or a Virtual COM port (CDC).  
     The PC pushes a new firmware binary directly to the MCU.
   + **As a Host (USB MSC Bootloader)**: If the device is deployed in a remote area without PC access, *the MCU acts as a USB Host.*  
     A field technician simply plugs a standard USB flash drive containing the update file (firmware.bin) into the device.  
     The MCU detects the drive, reads the file via a Mass Storage Class (MSC) driver, and flashes itself.  
2. Industrial Data Logging and Configuration  
   For remote equipment (like weather stations, flow meters, or solar inverters), data needs to be extracted or configured easily.
   + **Host Mode (Data Offloading)**: The MCU runs as a Host to dump locally stored sensor data (from internal flash or an SD card) onto a standard USB thumb drive for manual collection.
   + **Device Mode (Live Diagnostics)**: When connected to a factory PC or tablet, the MCU behaves as a peripheral,  
     presenting a graphical configuration interface or data stream via custom software.
3. Human-Machine Interface (HMI) & Test Equipment  
   Many embedded systems need modular ways to take user input or output data.  
   + **Interfacing with PC Peripherals**: In Host mode, the MCU can accept standard USB HID (Human Interface Device) peripherals like standard keyboards,  
     mice, or barcode scanners without needing a computer in the middle.  
   + **Interfacing with a PC**: The same physical port can be connected to a PC to turn the embedded system into an input device itself  
     (e.g., an MCU-based custom macro-pad, gaming controller, or laboratory measurement tool).
4. Testing, Calibration, and Factory Provisioning  
   During assembly line manufacturing, devices need to be quickly provisioned.  
   + An industrial programming fixture (acting as a USB Host) can plug into the MCU's port (acting as a Device) to inject unique cryptographic keys, MAC addresses, and initial calibration parameters.
   + Later, in the field, that same port on the MCU can act as a Host to control external calibration equipment or sensors.
5. Bridging and Direct Device-to-Device Communication  
   Because OTG allows two normally "peripheral" devices to talk to one another by having one assume the Host role:  
   + Direct Printing: An MCU in a medical device or laboratory instrument can switch to Host mode to send labels or reports directly to a USB printer  
     (using the USB Printer Class) without requiring a PC bridge.  
   + Camera Data Capture: An MCU can act as a Host to pull images directly from a digital camera or specialized sensor module over USB,  
     process them, and then switch to Device mode to upload them when plugged into a master terminal.

## how to switch its role

How the mode switches depends entirely on whether you are talking about the physical hardware connection or software settings.  

### The Hardware Trigger (How it happens automatically)

In traditional USB OTG (Micro-USB), **the switching is handled mechanically by the cable itself**  
using a *5th* pin called the ID (Identification) pin.  

+ **Host Mode (Master)**: When you plug an OTG cable/adapter into your phone,  
  *the adapter has its ID pin grounded* (connected to the ground pin).  
  This signals your phone's hardware to supply power 5V out of the port and look for attached devices.  
+ **Peripheral Mode (Slave)**: When you use a standard charging/data cable connected to a PC,  
  *the ID pin is left floating (disconnected).*  
  Your phone recognizes this and switches to receiver mode, waiting for data or power from the PC.  

The Type-C Era: With modern USB-C, the physical ID pin is replaced by CC (Configuration Channel) pins.  
The devices communicate electronically through these pins to negotiate who is the host (DFP - Downstream Facing Port)  
and who is the device (UFP - Upstream Facing Port).

### The Software Switch (How to change it manually)

If you have a phone connected to a PC or another dual-role device **via USB-C**,  
you don't need a special cable to switch modes; you can do it right from the software settings.
