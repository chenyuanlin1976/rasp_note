# MQTT (Message Queuing Telemetry Transport)

MQTT is a lightweight, open messaging protocol designed for constrained devices and low-bandwidth, high-latency, or unreliable networks. 
It is the de facto standard protocol for the Internet of Things (IoT).

## Popular Free Public Brokers (For Testing Only)

+ EMQX: Host broker.emqx.io, Port 1883 (TCP) or 8883 (SSL/TLS)
+ HiveMQ: Host broker.hivemq.com, Port 1883 (TCP)
+ Mosquitto: Host test.mosquitto.org, Port 1883 (TCP)

## How MQTT Works (Pub/Sub Architecture)

Unlike traditional web communication (like HTTP) which relies on a request-response model,  
**MQTT uses a Publish/Subscribe (Pub/Sub) model**.

Clients do not communicate directly with each other.  
Instead, they interact through a central coordinator called a **Broker**.

+ **Publisher**: A device/sensor that gathers data and sends (publishes) it to the broker under a specific topic.
+ **Subscriber**: An application or device that is interested in a topic and receives messages from the broker.
+ **Broker**: The server responsible for filtering all incoming messages and distributing them to the correct subscribed clients.

## Core Concepts & Terminology

+ **Topics**: A hierarchical string used by the broker to *filter messages* for each client  
  (structured like a file path, e.g., home/living-room/temperature).
+ **Quality of Service (QoS)**: An agreement between the sender and receiver on the guarantee of message delivery.  
+ **Retained Messages**: A flag a publisher can set so the broker saves the last known good message for a topic.  
  When a new client subscribes, it immediately receives this message without waiting for a new publication.
+ **Last Will and Testament (LWT)**: A notification message registered with the broker by a client.  
  If the client disconnects unexpectedly, the broker automatically publishes the LWT message to alert other devices.

## The 3 QoS Levels

+ QoS 0 (At Most Once): Fire and forget. No confirmation is sent (fastest, but messages can be lost).
  + Sent once with no confirmation or response expected.
  + Fast and lightweight, but messages can be lost if the network drops.
  + Best for rapid telemetry or sensor data where missing a single update does not matter
+ QoS 1 (At Least Once): Guarantees that the message arrives **at least once**, but duplicates may occur.
  + Guarantees the message arrives, using a **PUBACK** response packet.
  + If confirmation is delayed, the sender re-transmits the message (potentially causing duplicates).
  + Best for general events where delivery is crucial but duplicate handling is acceptable.
+ QoS 2 (Exactly Once): Guarantees the message arrives exactly one time using a four-step handshake (slowest, most secure).
  + Uses a strict four-step handshake (**PUBLISH, PUBREC, PUBREL, PUBCOMP**) to prevent loss or duplication.
  + Highest overhead and slowest speed.Best for financial transactions or vital command systems where duplicates cause severe errors.

## Key Benefits of MQTT

+ Extremely Lightweight: Features a very small fixed header (as small as 2 bytes), minimizing network traffic and overhead.
+ Low Power Consumption: Designed to conserve battery life on remote IoT sensors.
+ Reliable over Poor Networks: Built-in features like persistent sessions and QoS levels handle intermittent network connectivity well.
+ Scalable: A single broker can manage thousands of connected clients seamlessly.

## Common Use Cases

+ Smart Home Systems: Connecting devices like lights, thermostats, and smart locks to hubs or apps (e.g., Home Assistant, AWS IoT).
+ Industrial IoT (IIoT): Monitoring factory machinery, tracking remote pipeline metrics, and automating logistics.
+ Automotive: Telematics and vehicle-to-cloud communication.
+ Healthcare: Remote patient monitoring devices that transmit vital signs continuously.

## To publish MQTT messages in C

the industry standard is to use the Eclipse **Paho MQTT C client library**.  
It provides clean, reliable functions to handle connections, message creation, and delivery tracking.

### Prerequisites

Before compiling the code, you need to install the Paho C library on your system.

+ `sudo apt-get update`  
+ `sudo apt-get install libpaho-mqtt-dev`

### keys for Publisher

+ `MQTTClient_create()`: Allocates memory for your client interface and targets the network address.
+ `MQTTClient_connect()`: Performs the synchronous handshaking network call to link up with the broker.
+ `MQTTClient_message_initializer`: A helpful macro that assigns necessary default structures to the payload data.
+ `MQTTClient_publishMessage()`: Packages the message buffer and attempts transmission over the active TCP connection socket.
+ `MQTTClient_waitForCompletion()`: A blocking fallback checking mechanism that prevents thread ending  
  before receiving explicit confirmation (QoS 1) from the broker host.

## To subscribe to an MQTT topic and receive messages in C

You can use the asynchronous model of the Eclipse **Paho MQTT C client library**.  
This approach uses a callback system, meaning the library automatically triggers a specific function in your code whenever a new message arrives.

### Key Concepts for Subscribers

+ `MQTTClient_setCallbacks()`: Registers your custom C functions to handle background events.  
  You must call this after creating the client but before calling connect.
+ `messageArrived` Handler: This is your message processor.  
  It provides the topic name and the MQTTClient_message structure, which contains the `.payload` and `.payloadlen`.
+ Memory Management: Inside the callback, you must free the topicName and the message using `MQTTClient_free()` and `MQTTClient_freeMessage()`.  
  Forgetting this will cause a critical memory leak in continuous applications.
+ Return Value: The `messageArrived` function must return 1 (true) to indicate that the message was successfully handled.

## build an MQTT broker 

+ Installing an MQTT Broker: `sudo apt update && sudo apt install mosquitto mosquitto-clients`
+ Start the broker service:`sudo systemctl start mosquitto`
+ Connect your Paho C application to your local broker using the address `tcp://localhost:1883`

## Mosquitto

Eclipse Mosquitto is a lightweight, open-source message broker that implements the MQTT protocol (versions 5.0, 3.1.1, and 3.1),  
perfect for Internet of Things (IoT) messaging and small home automation projects.

### Install Mosquitto

+ `sudo apt-get update`  
+ Mosquitto Broker service: `sudo apt install mosquitto`
+ Publisher and Subscriber: `sudo apt-get install libmosquitto-dev mosquitto-clients`  

### Key Features

+ Uses a publish/subscribe model to route messages via topics.
+ Runs on tiny devices like a Raspberry Pi or full computer servers.
+ Includes simple command-line tools (`mosquitto_pub` and `mosquitto_sub`) to send and test messages.

### Basic Commands

+ Subscribe to a topic:`mosquitto_sub -h localhost -t "my/topic"`
+ Publish a message:`mosquitto_pub -h localhost -t "my/topic" -m "Hello"`

### Core API Architecture Explained

+ `mosquitto_lib_init()`: Configures global network states. Must be executed exactly once per program lifecycle.
+ `mosquitto_new()`: Instantiates the internal state tracker context object.
+ `mosquitto_loop_start()`: Spawns an internal worker thread so network acknowledgments (CONNACK, PUBACK) resolve safely  
  without pausing your primary application execution timeline.
+ `mosquitto_publish()`: Packages your payload data into an outward MQTT packet frame.
+ `mosquitto_subscribe()`: Sends a request packet to the broker indicating interest in specific data streams.
+ `mosquitto_connect_callback_set()`: Registers your on_connect function.  
   This executes as soon as the broker evaluates your credentials and responds with a CONNACK packet.
+ `mosquitto_message_callback_set()`: Registers your on_message function. 
  The library executes this whenever the broker routes an incoming packet matching your criteria to this client.
+ `mosquitto_loop_forever()`: Unlike the publisher which uses loop_start() to open a background thread and proceed,  
  a standard subscriber blocks the current execution thread right here to continuously poll for incoming TCP data packets.  
  It automatically handles ping requests to maintain the connection.
