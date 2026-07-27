# What is Modbus?

Modbus is an industrial communication protocol developed in 1979 by Modicon (now Schneider Electric).  
It acts as a standard language that allows electronic devices  
(such as Programmable Logic Controllers (PLCs), sensors, actuators, and meters)  
to communicate with each other and with control computers (like SCADA or HMI systems).

Because of its simplicity, reliability, and open-source nature (free to use without licensing fees),  
Modbus has become the de facto standard for industrial automation.

## How Modbus Works

Modbus operates on a **Request-Response** (or Client-Server / Master-Slave) architecture.

+ Master/ Client: The device that initiates the request (e.g., a computer, SCADA system, or PLC).
+ Slave/ Server: The device that processes the request and sends back the requested data or  
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
