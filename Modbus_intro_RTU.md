# Modbus RTU

The Modbus RTU (Remote Terminal Unit) transmission mode uses a compact binary representation optimized for serial lines (like RS-485 or RS-232).

Unlike Modbus TCP, RTU frames do **NOT** use a MBAP header or length specifier.  
Instead, frame boundaries are determined by silent intervals (pauses) on the line,  
and error-checking is handled at the end by a 16-bit CRC (Cyclic Redundancy Check).

## Frame Structure

A complete Modbus RTU packet consists of four distinct fields:

| Field Name    | Length  | Description                                                                                                  |
| ------------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| Slave Address | 1 Byte  | Address of the target slave device (Range: 1 to 247, 0 is broadcast).                                        |
| Function Code | 1 Byte  | The operation code (e.g., 0x03 to read holding registers, 0x06 to write single register).                    |
| Data Field    | N Bytes | Parameters specific to the function code (e.g., starting addresses, quantity of registers, register values). |
| CRC Checksum  | 2 Bytes | Low-order byte first, high-order byte last (CRC-16).                                                         |

## Key Frame Characteristics

+ Timing / Framing: Modbus RTU relies on hardware timers rather than start/stop characters for framing.  
  A silent interval of at least 3.5 character times marks the beginning and end of a message frame.
+ Error Checking: Every single RTU frame ends with a 16-bit CRC calculated using the standard CRC-16-IBM polynomial (0xA001).  
  If the receiver's computed CRC does not match the trailing 2 bytes, the frame is silently dropped.

## Modbus function codes

### Bit Access (Digitals / Booleans)

+ 0x01: Read Coils, Read the status of binary outputs (ON/OFF).
+ 0x02: Read Discrete Inputs, Read the status of binary inputs (ON/OFF).
+ 0x05: Write Single Coil, Force a single binary output to ON or OFF.
+ 0x0F: Write Multiple Coils, Write a block of consecutive binary outputs.

### 16-Bit Register Access (Analogs / 16-bit integers)

+ 0x03: Read Holding Registers, Read the values of read/write 16-bit registers.
+ 0x04: Read Input Registers, Read the values of read-only 16-bit registers.
+ 0x06: Write Single Register, Write a value to a single 16-bit holding register.
+ 0x10: Write Multiple Registers, Write a block of consecutive 16-bit holding registers.

### Diagnostics & Maintenance

+ 0x07: Read Exception Status, Read status of 8 internal exception conditions (serial only).
+ 0x08: Diagnostics, Loopback tests, communication checks, or reset counters.
+ 0x11: Report Slave ID, Returns device description, run status, and custom data.

## Modbus RTU Dialogue Flow

**Modbus RTU operates on a strict Request-Response (Master-Slave / Client-Server) architecture**.  
The slave never speaks unless the master asks it a question first.

### Step-by-Step Sequence Diagram

[Modbus Master]                                    [Modbus Slave (ID: 1)]
      |                                                      |
      |--- 1. REQUEST FRAME -------------------------------->|
      |    (Address | Function | Data | CRC)                 |
      |                                                      |
      |                                            [Processing Request]
      |                                                      |
      |<-- 2. RESPONSE FRAME (or Exception) -----------------|
      |    (Address | Function | Data | CRC)                 |
      |                                                      |

### Detailed Breakdown of the Dialogue

1. The Master Sends a Request:  
   The master initiates communication by broadcasting or targeting a specific slave ID.
   + Frame Structure (RTU Binary):
     + Device Address: 1 byte (e.g., 0x01 for Slave 1)
     + Function Code: 1 byte (e.g., 0x03 to read holding registers)
     + Data: N bytes (specifies starting register address and how many registers to read)
     + CRC Checksum: 2 bytes (Cyclic Redundancy Check for error detection)
2. The Slave Processes the Request:  
   + The target slave listens to the line, checks the CRC, and verifies if the Device Address matches its own ID.
   + If it matches, the slave performs the requested action (e.g., reads sensor data from memory).
3. The Slave Sends a Response
   + If Successful (Normal Response):
     + Device Address: Echoes back its ID (0x01)
     + Function Code: Echoes back the function code (0x03)
     + Data: The requested values (e.g., register values)
     + CRC Checksum: 2 bytes
   + If an Error Occurs (Exception Response):
     + Device Address: Echoes back its ID
     + Function Code: Sets the highest bit to 1 (e.g., 0x83 instead of 0x03)
     + Exception Code: 1 byte explaining why it failed (e.g., 0x02 for Invalid Register Address)
     + CRC Checksum: 2 bytes

## Why Modbus RTU fails to physically jumper TX to RX on a single port

1. Port Conflict ("Access Denied" or "Port Already in Use")
   + Both your Modbus Master software and your Modbus Slave software are trying to open the exact same physical COM port.  
     Operating systems like Windows only allow one application at a time to claim and control a physical hardware port.  
     When the second program tries to open it, the OS blocks it and throws an error.  
2. Physical Loopback Doesn't Create a Master/Slave Dynamic.  
   + Modbus requires a dialogue (Master sends a request -> Slave processes it -> Slave replies).  
     A physical loopback just bounces your own transmitted data right back into your receiver.  
     Without two distinct endpoints, the master has no separate slave software listening to respond.  
