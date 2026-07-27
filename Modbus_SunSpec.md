# SunSpec Modbus

SunSpec Modbus is an open communication standard created by the SunSpec Alliance Modbus Page  
that defines data models for solar inverters and distributed energy resources.  
It builds on standard Modbus protocols to make device monitoring and grid compliance simple.

## Core Features

+ Uses standard Modbus RTU (**RS-485 serial**) or Modbus TCP (Ethernet/IP).  
+ Organizes data into standardized "blocks" or "models"  
  so any system can read device data without custom manufacturer maps.  
+ Referenced heavily in smart grid rules like IEEE 1547-2018 for clean energy systems.

## How It Works

+ Common Map: Devices start scanning at specific base register addresses  
  to find a "SunSpec Common Block" identifier.  
+ Data Models: Followed by dynamic blocks containing real-time measurements,  
  controls, ratings, and status.  
+ Plug-and-Play: Monitoring software auto-detects metrics like voltage, current,  
  power output, and frequency without manual register configuration.

## How They Work Together

+ The Request: A master controller wants to read data from a **SunSpec inverter**.  
  It creates a Modbus RTU message packet containing the inverter's ID and target register.
+ The Transmission: The controller's serial chip converts this binary Modbus RTU data  
  into electrical voltage spikes. It sends them down the RS-485 physical wires.
+ The Reception: The inverter detects the voltage differences on the RS-485 lines,  
  converts them back into binary bytes, and reads the Modbus RTU message to process the request.

## Why They Are Paired

+ Noise Resistance: *RS-485 uses differential signaling* to reject industrial electromagnetic interference.  
+ Long Distance: RS-485 carries Modbus RTU packets up to 1,200 meters (4,000 feet) without signal repeaters.  
+ Multi-Drop Bus: A single RS-485 wire pair connects up to 32 (or more) Modbus RTU slave devices in a daisy-chain.  
