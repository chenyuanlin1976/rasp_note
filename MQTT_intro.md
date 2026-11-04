# MQTT

MQTT is a lightweight publish/subscribe messaging protocol for constrained devices and unreliable or low-bandwidth networks.
It runs over TCP (or WebSockets), and it is one of the most widely used protocols for sending IoT telemetry to a server.
The name originally stood for "MQ Telemetry Transport"; the OASIS standard now treats MQTT as a name, not an acronym.
The current versions are MQTT 3.1.1 (2014) and MQTT 5.0 (2019).

## 1. Publish/subscribe with a broker

HTTP is request/response: the client asks a specific server. In MQTT, clients never talk to each other directly. Every client connects to a **broker**:

```text
 sensor ──PUBLISH home/livingroom/temperature "23.5"──▶ broker ──▶ dashboard (subscribed to home/+/temperature)
                                                              └──▶ logger    (subscribed to home/#)
```

+ **Publisher**: sends a message to the broker under a **topic**.
+ **Subscriber**: tells the broker which topics it wants and receives matching messages.
+ **Broker**: receives every message and forwards it to all clients with a matching subscription.
+ A client can be a publisher and a subscriber at the same time. Publisher and subscriber don't need to know each other's address, or be online at the same time (with persistent sessions).

## 2. Core concepts

+ **Topic**: a hierarchical UTF-8 string, levels separated by `/`, e.g. `home/livingroom/temperature`. Topics are not created in advance; publishing to one is enough.
+ **Wildcards** (in subscriptions only):
  - `+` matches exactly one level: `home/+/temperature`
  - `#` matches any number of levels and must be last: `home/#`
  - Topics starting with `$` (e.g. `$SYS/...` broker statistics) are not matched by a leading `#` or `+`.
+ **QoS**: the delivery guarantee (section 3).
+ **Retained message**: the broker keeps the last retained message per topic and sends it immediately to every new subscriber. Useful for state such as "light is on".
+ **Last Will and Testament (LWT)**: a message the client registers when it connects. If the client disconnects without a proper DISCONNECT (crash, network loss),
  the broker publishes it, e.g. `devices/plug1/status` = `offline`.
+ **Keep alive**: the client sends PINGREQ if it has nothing else to send, so the broker can detect a dead connection.
+ **Clean session / persistent session**: with a persistent session the broker remembers the client's subscriptions and queues QoS 1/2 messages while it is offline.
  (MQTT 5 replaces the clean-session flag with Clean Start plus a Session Expiry Interval.)
+ **Client ID**: must be unique per broker. A second client with the same ID disconnects the first one.

## 3. QoS levels

| QoS | Guarantee | Packets | Cost | Use for |
| --- | --- | --- | --- | --- |
| 0 | At most once ("fire and forget"); may be lost | PUBLISH | Lowest | Frequent telemetry where a missed sample doesn't matter |
| 1 | At least once; may be duplicated | PUBLISH, PUBACK | Medium | Most events; the receiver must tolerate duplicates |
| 2 | Exactly once | PUBLISH, PUBREC, PUBREL, PUBCOMP | Highest | Commands where a duplicate would cause harm (e.g. "dispense one item") |

+ QoS applies to each hop separately: publisher → broker, and broker → subscriber.
  A subscriber receives a message at the **lower** of the publish QoS and its subscription QoS.
+ QoS is about delivery, not security. Security comes from TLS and authentication (section 4).

## 4. Ports and security

| Port | Transport | Notes |
| --- | --- | --- |
| 1883 | MQTT over TCP | IANA-registered, unencrypted |
| 8883 | MQTT over TLS | IANA-registered |
| 8083 / 8084 | MQTT over WebSocket / secure WebSocket | Common broker defaults (e.g. EMQX), not standardized; check the broker's configuration |

+ Plain port 1883 sends user names, passwords, and payloads in clear text. Use TLS (8883) outside a trusted LAN.
+ Authenticate clients (user name/password or client certificates) and restrict topics per user with ACLs.

## 5. Why MQTT for IoT

+ **Small overhead**: the fixed header is 2 bytes; a small PUBLISH is only a few bytes more than its topic and payload.
+ **One outgoing connection**: the device connects out to the broker, so it works behind NAT and firewalls without opening ports.
+ **Handles poor networks**: keep alive, LWT, QoS, and persistent sessions deal with dropped connections.
+ **Decoupling and fan-out**: one sensor message can reach many consumers; new consumers can subscribe without changing the device.
+ **Scalable**: brokers handle thousands of clients; clustered brokers handle far more.

Typical uses: smart home (Home Assistant, Zigbee2MQTT), industrial telemetry, vehicle telematics, and cloud IoT platforms (AWS IoT Core, Azure IoT Hub, both MQTT-based).

## 6. Mosquitto broker

Eclipse Mosquitto is a small open-source broker (MQTT 5.0, 3.1.1, 3.1) that runs well on a Raspberry Pi.

```shell
sudo apt update
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable --now mosquitto
```

Test with the command-line clients (in two terminals):

```shell
mosquitto_sub -h localhost -t "home/#" -v                          # -v prints the topic too
mosquitto_pub -h localhost -t "home/livingroom/temperature" -m "23.5"
mosquitto_pub -h localhost -t "devices/plug1/status" -m "online" -r -q 1   # retained, QoS 1
```

Since Mosquitto 2.0, a broker without a listener configuration accepts connections **from localhost only**.
To allow other devices, add a listener and authentication, for example in `/etc/mosquitto/conf.d/local.conf`:

```text
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

```shell
sudo mosquitto_passwd -c /etc/mosquitto/passwd myuser   # -c creates the file; omit it when adding more users
sudo chown root:mosquitto /etc/mosquitto/passwd && sudo chmod 640 /etc/mosquitto/passwd
sudo systemctl restart mosquitto
mosquitto_sub -h <broker-ip> -u myuser -P <password> -t "home/#" -v
```

Public test brokers (no privacy, anyone can read your topics; never use them for real data):

+ `test.mosquitto.org`, port 1883 (TCP) and 8883 (TLS)
+ `broker.emqx.io`, port 1883 (TCP) and 8883 (TLS)
+ `broker.hivemq.com`, port 1883 (TCP)

## 7. C client: Eclipse Paho (publisher)

The Eclipse Paho C library has two APIs: **MQTTClient** (synchronous, `libpaho-mqtt3c`, used here) and **MQTTAsync** (fully asynchronous, `libpaho-mqtt3a`).
The `...s` variants (`libpaho-mqtt3cs`, `libpaho-mqtt3as`) add TLS.

```shell
sudo apt install libpaho-mqtt-dev
gcc pub.c -o pub -lpaho-mqtt3c
```

```c
#include <stdio.h>
#include <string.h>
#include <MQTTClient.h>

#define ADDRESS  "tcp://localhost:1883"
#define CLIENTID "pub-demo"
#define TOPIC    "home/livingroom/temperature"

int main(void)
{
    MQTTClient client;
    MQTTClient_connectOptions opts = MQTTClient_connectOptions_initializer;
    MQTTClient_message msg = MQTTClient_message_initializer;
    MQTTClient_deliveryToken token;
    const char *payload = "23.5";
    int rc;

    MQTTClient_create(&client, ADDRESS, CLIENTID, MQTTCLIENT_PERSISTENCE_NONE, NULL);
    opts.keepAliveInterval = 20;
    opts.cleansession = 1;

    rc = MQTTClient_connect(client, &opts);
    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "connect failed: %d\n", rc);
        MQTTClient_destroy(&client);
        return 1;
    }

    msg.payload = (void *)payload;
    msg.payloadlen = (int)strlen(payload);
    msg.qos = 1;
    msg.retained = 0;

    MQTTClient_publishMessage(client, TOPIC, &msg, &token);
    rc = MQTTClient_waitForCompletion(client, token, 10000L);   /* wait up to 10 s for PUBACK */
    printf("delivered: %s\n", rc == MQTTCLIENT_SUCCESS ? "yes" : "no");

    MQTTClient_disconnect(client, 10000);
    MQTTClient_destroy(&client);
    return 0;
}
```

+ `MQTTClient_create()`: creates the client handle for a broker URI and client ID. It does not connect yet.
+ `MQTTClient_connect()`: connects and blocks until CONNACK.
+ `MQTTClient_publishMessage()`: sends the message and returns a delivery token.
+ `MQTTClient_waitForCompletion()`: blocks until the message with that token is acknowledged (QoS 1/2) or the timeout expires.

**Receiving with Paho**: call `MQTTClient_setCallbacks()` after `MQTTClient_create()` and before `MQTTClient_connect()`.
This is still the synchronous MQTTClient API; the library calls your callbacks from a background thread.

+ The `messageArrived(context, topicName, topicLen, message)` callback gets the payload in `message->payload` / `message->payloadlen`.
  The payload is not NUL-terminated.
+ Free both with `MQTTClient_freeMessage(&message)` and `MQTTClient_free(topicName)`, then return `1`.
  Returning `0` tells the library the message wasn't handled, and it calls the callback again.

## 8. C client: libmosquitto (subscriber)

```shell
sudo apt install libmosquitto-dev
gcc sub.c -o sub -lmosquitto
```

```c
#include <stdio.h>
#include <mosquitto.h>

static void on_connect(struct mosquitto *mosq, void *obj, int rc)
{
    (void)obj;
    if (rc == 0)
        mosquitto_subscribe(mosq, NULL, "home/+/temperature", 1);   /* (re)subscribe on every connect */
    else
        fprintf(stderr, "connect refused: %s\n", mosquitto_connack_string(rc));
}

static void on_message(struct mosquitto *mosq, void *obj, const struct mosquitto_message *msg)
{
    (void)mosq;
    (void)obj;
    printf("%s: %.*s\n", msg->topic, msg->payloadlen, (const char *)msg->payload);
}

int main(void)
{
    struct mosquitto *mosq;
    int rc;

    mosquitto_lib_init();

    mosq = mosquitto_new("sub-demo", true, NULL);   /* true = clean session */
    if (mosq == NULL) {
        fprintf(stderr, "mosquitto_new failed\n");
        mosquitto_lib_cleanup();
        return 1;
    }

    mosquitto_connect_callback_set(mosq, on_connect);
    mosquitto_message_callback_set(mosq, on_message);

    rc = mosquitto_connect(mosq, "localhost", 1883, 60);   /* keep alive 60 s */
    if (rc != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "connect failed: %s\n", mosquitto_strerror(rc));
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    mosquitto_loop_forever(mosq, -1, 1);   /* blocks; handles keep alive and reconnects */

    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();
    return 0;
}
```

+ `mosquitto_lib_init()` / `mosquitto_lib_cleanup()`: call once per program, at start and end.
+ `mosquitto_new()`: creates a client instance (client ID, clean session flag, user data pointer).
+ `mosquitto_connect_callback_set()`: the callback runs when CONNACK arrives. Subscribing there means subscriptions are restored after a reconnect.
+ `mosquitto_message_callback_set()`: the callback runs for every received message. The message is freed by the library after the callback returns; copy what you need.
+ Network loop, pick one:
  - `mosquitto_loop_forever()`: blocks the calling thread. Typical for a pure subscriber.
  - `mosquitto_loop_start()`: starts a background thread and returns, so the main thread can do other work (e.g. read sensors and `mosquitto_publish()`). Stop it with `mosquitto_loop_stop()`.
  - `mosquitto_loop()`: one iteration, for integrating with your own event loop.

## Related notes

+ [IoT_Network.md](IoT_Network.md): the network links MQTT runs over, and other IoT application protocols
+ [Modbus_intro.md](Modbus_intro.md): polling industrial devices; gateways often forward Modbus data to MQTT
+ [BLE_intro.md](BLE_intro.md): BLE sensors behind an MQTT gateway
+ [Linux/socket_intro.md](Linux/socket_intro.md): TCP sockets underneath MQTT
+ [network_cmds.md](network_cmds.md): network troubleshooting commands

## Reference

+ MQTT specifications (OASIS): <https://mqtt.org/mqtt-specification/>
+ Eclipse Mosquitto: <https://mosquitto.org/>
+ Mosquitto configuration (`mosquitto.conf`): <https://mosquitto.org/man/mosquitto-conf-5.html>
+ libmosquitto API: <https://mosquitto.org/api/>
+ Eclipse Paho: <https://eclipse.dev/paho/>
