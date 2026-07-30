# What is Modbus?

Modbus is an industrial communication protocol developed in 1979 by Modicon (now Schneider Electric).  
It acts as a standard language that allows electronic devices  
(such as Programmable Logic Controllers (PLCs), sensors, actuators, and meters)  
to communicate with each other and with control computers (like SCADA or HMI systems).

Because of its simplicity, reliability, and open-source nature (free to use without licensing fees),  
Modbus has become the de facto standard for industrial automation.

## How Modbus Works

Modbus operates on a **Request-Response** (or Client-Server / Master-Slave) architecture.

+ Client: The device that initiates the request (e.g., a computer, SCADA system, or PLC).
+ Server: The device that processes the request and sends back the requested data or  
  performs the requested action (e.g., a temperature sensor, power meter, or valve).

**Key Rule**: Slaves never speak unless spoken to. A slave cannot initiate communication on its own.

## Common Modbus Variants

As technology evolved, Modbus expanded from traditional serial lines to Ethernet networks.  
The main variants include:

1. **Modbus RTU** (Remote Terminal Unit):
   + Uses serial communication (RS-232, RS-485).
   + Data is transmitted in binary format for high data density.
   + Most common variant in factory floors.
2. Modbus ASCII:
   + Uses serial communication.
   + Data is transmitted as human-readable ASCII characters  
     (making it easier to troubleshoot with a terminal, but slower than RTU).
3. Modbus TCP (Transmission Control Protocol):
   + Designed for Ethernet networks.
   + Encapsulates the Modbus RTU/ASCII packet inside a standard TCP/IP packet (typically using port 502).
   + Allows multiple masters to query devices over a local network or the internet.
4. Modbus RTU/IP:
   + A variation where Modbus RTU packets are transported over an IP network rather than pure TCP.

## Advantages and Limitations

### Advantages

+ Open Standard: Free to implement and use across different manufacturers.
+ Simple Structure: Easy to learn, deploy, and troubleshoot compared to complex industrial protocols.
+ Versatile: Works seamlessly over old-school serial cables as well as modern Ethernet infrastructure.

### Limitations

+ No Built-in Security: Standard Modbus lacks native authentication or encryption,  
  making it vulnerable to cyberattacks if exposed to unsecured networks.
+ Master-Slave Bottleneck: Slaves cannot report alarms or events proactively;  
  the master must continuously poll them.
+ Limited Bandwidth: Not ideal for high-speed, high-volume data transmission  
  (like video or heavy configuration files).

## Modbus TCP Frame Structure (MBAP Header + PDU)

*A Modbus TCP request consists of a 7-byte MBAP Header followed by the PDU* (Protocol Data Unit):

+ **Transaction Identifier** (2 bytes): For pairing request and response.
+ **Protocol Identifier** (2 bytes): 0 for Modbus.
+ **Length** (2 bytes): Number of remaining bytes in the message.
+ **Unit Identifier** (1 byte): Slave address (often 0xFF or 1 for TCP).
+ Function Code (1 byte): e.g., 0x03 for Read Holding Registers.
+ Data (N bytes): Starting address, quantity of registers, etc.

## Modbus: master-slave architecture

Modbus TCP/RTU use the **master-slave** architecture.  
(often referred to in modern specifications as **Client-Server**).  
The underlying data model, function codes, and logical request-response mechanism remain identical across both protocols.  
The primary difference lies in the underlying transport layer:

+ Modbus RTU: Transmits binary data serially over physical cabling like RS-485 or RS-232,  
  relying on device addresses to route messages between the master and specific slaves.
+ Modbus TCP: Encapsulates the Modbus data packets inside standard TCP/IP frames, transmitting them over Ethernet networks.  
  Instead of a serial device address, it uses IP addresses to identify devices on the network,  
  alongside a Unit Identifier to communicate with sub-devices connected behind a gateway.

## To define and use Modbus registers for control

you must map your data into 4 data types: Coils, Discrete Inputs, Input Registers, and Holding Registers.  
Each type uses specific function codes and size rules to manage digital and analog values.  

### Coils (0xxxx)

+ Size & Access: 1 bit, Read/Write
+ Function Codes: Read (01), Write Single (05), Write Multiple (15)
+ Use for: Binary control actions like starting/stopping a motor or toggling a relay.

### Discrete Inputs (1xxxx)

+ Size & Access: 1 bit, Read-Only
+ Function Codes: Read (02)
+ Use for: Binary status monitoring like safety limit switches or push-button states.

### Input Registers (3xxxx)

+ Size & Access: 16 bits (2 bytes), Read-Only
+ Function Codes: Read (04)
+ Use for: Live analog measurements like temperature, pressure, or sensor values

### Holding Registers (4xxxx)

+ Size & Access: 16 bits (2 bytes), Read/Write
+ Function Codes: Read (03), Write Single (06), Write Multiple (16)
+ Use for: Configurable parameters, target setpoints, and multi-register data like 32-bit floats.

## How to Define and Map Addresses

+ Documentation vs. Wire Address:  
  Documentation usually lists human-readable addresses starting with a prefix digit (40001 for the first holding register).  
  However, the actual Modbus protocol frame uses a zero-based offset (0x0000).  
  To find the wire address, subtract the leading prefix range (e.g., subtract 40001 to get 0).
+ Handling Large Data Types (32-bit / Floats):  
  A standard Modbus register is 16 bits.  
  To store a 32-bit integer or an IEEE 754 floating-point number, define two consecutive 16-bit registers  
  (e.g., combining holding registers 40001 and 40002). Ensure both master and slave agree on the byte/word order (endianness)

## Technical Accuracy and Better Descriptive Clarity

Beyond social reasons, master/slave is often a vague metaphor for how modern digital systems actually work.  
Alternative terms frequently provide much better functional descriptions:

+ **Client/Server**: Accurately describes a cooperative network relationship where  
  + one component requests a service and  
  + the other fulfills it (much like a customer and a service provider).  
+ Initiator/Target or Requester/Responder: Explicitly defines who starts a communication transaction and who answers it,  
  which fits modern bus architectures (like PCI Express or modern networking protocols) much more logically.
+ Primary/Secondary or Main/Replica: Clearly outlines hierarchy in database replication or hardware configurations without invoking human social constructs.
