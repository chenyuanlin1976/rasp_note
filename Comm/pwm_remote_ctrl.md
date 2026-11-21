# Remote PWM control from an app

A mobile app, browser dashboard, or desktop client that dims an LED, sets a motor or fan speed, or moves a servo doesn't toggle pins over the network.
It sends **commands** (a duty cycle, on/off) to a controller (ESP32, Raspberry Pi, an Android or Linux board), and firmware or a service there drives the hardware PWM.
This note is about that link: which protocol, what to send, and how to keep it safe.
Driving the PWM on the device itself: [../Android/HW/pwm_control.md](../Android/HW/pwm_control.md) (RK3566, Linux sysfs, Android HAL).

```text
 app / browser ──(HTTP, WebSocket, MQTT, BLE)──> service or firmware on the controller ──> PWM peripheral ──> driver stage ──> load
```

## 1. Choose the link

| Approach | Best for | How the app talks to the device |
| --- | --- | --- |
| HTTP / REST | Local web UI, simple switches and sliders | `POST /api/pwm` with `{"channel": 0, "duty": 75}` to a small server on the device (Flask/FastAPI on a Pi, `esp_http_server` or ESPAsyncWebServer on ESP32) |
| WebSocket | Smooth real-time sliders | One persistent two-way connection; slider values stream with low latency, and the device pushes state back |
| MQTT | Several devices, home automation, remote control through a broker | The app publishes `75` to `devices/pi1/pwm/0/set`; the device subscribes, applies it, and publishes the result to `devices/pi1/pwm/0/state` |
| BLE | Phone to device directly, no Wi-Fi | The app writes a value to a custom GATT characteristic; notifications report the state |
| Ready-made platforms | Prototypes without UI code | Home Assistant, Node-RED dashboard, or Blynk map sliders to device topics or pins |

Details on the protocols: [MQTT_intro.md](MQTT_intro.md), [BLE_intro.md](BLE_intro.md), [IoT_Network.md](IoT_Network.md).

## 2. Define the message contract

+ **One duty scale**: use `0`–`100` (%) or `0`–`255` in the protocol, never both. The device converts it to the hardware resolution (10-bit, 12-bit, or nanoseconds in Linux sysfs).
+ **Frequency is a property of the load**, so the device normally fixes it. Make it configurable only if the hardware and load allow it.
+ **Feedback**: the device reports the value it actually applied, plus state and faults (`on`/`off`, overcurrent, ...). Several clients then stay in sync, and an app that reconnects shows the real state.
+ **Rate-limit sliders**: a slider fires events at display rate (60 Hz or more). Send at most every 50–100 ms, and always send the final value.

Typical PWM frequencies:

| Load | Frequency | Why |
| --- | --- | --- |
| LED dimming | ≥ 1 kHz (often a few kHz) | No visible flicker, also on camera |
| DC motor (H-bridge, MOSFET) | about 20–25 kHz | Above hearing, so no whine; higher frequencies increase switching losses |
| 4-pin PC fan | 25 kHz | Defined by the 4-wire fan specification |
| Hobby servo | 50 Hz, pulse about 1–2 ms | The pulse width is the position, not the duty cycle; check the servo's range |
| Heater (through an SSR) | Slow, ~1 Hz or less | Thermal load is slow; zero-cross SSRs switch only at mains zero crossings |

## 3. Example: browser slider over HTTP

```javascript
// Send the duty cycle (0..100 %) to the device and return the state it applied.
async function setPwmDuty(baseUrl, channel, dutyPercent) {
  const duty = Math.max(0, Math.min(100, Math.round(Number(dutyPercent))));
  const res = await fetch(`${baseUrl}/api/pwm`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ channel, duty }),
  });
  if (!res.ok) {
    throw new Error(`PWM update failed: ${res.status}`);
  }
  return res.json();            // e.g. {"channel": 0, "duty": 75, "enabled": true}
}

// Rate-limit: send at most every 100 ms; the last value is always sent.
function throttleLatest(fn, ms) {
  let timer = null, pending = null;
  return (...args) => {
    pending = args;
    if (timer) return;
    timer = setTimeout(() => { timer = null; fn(...pending); }, ms);
  };
}

const sendDuty = throttleLatest((v) => setPwmDuty("http://192.168.1.50:8080", 0, v).catch(console.error), 100);
document.querySelector("#duty").addEventListener("input", (e) => sendDuty(e.target.value));
```

The service on the device validates the request again (range, channel) and applies it:

+ Linux board (Raspberry Pi, RK3566, Jetson): the PWM sysfs interface `/sys/class/pwm/pwmchipN/pwm0/` (see [../Android/HW/pwm_control.md](../Android/HW/pwm_control.md) §3), or `lgpio` on a Raspberry Pi. `pigpio` doesn't support the Raspberry Pi 5.
+ ESP32: the ESP-IDF `ledc` driver (or `analogWrite()` in the Arduino core).
+ Android device: the app calls a system service, which calls a vendor HAL ([../Android/HW/pwm_control.md](../Android/HW/pwm_control.md) §6).

## 4. Safety and reliability

+ **Safe default**: the output is `0 %` (or a safe idle state) at boot, after a firmware crash, and when the controlling connection drops.
  For motors and heaters, use a watchdog: if no command or keep-alive arrives for N seconds, stop.
+ **Hardware first**: hold the gate driver off with a pull-down resistor, so the load stays off while the MCU is in reset or the pin is still an input.
+ **Authentication**: don't expose an unauthenticated control endpoint to the internet, where anyone could move actuators.
  Keep it on the local network, or use TLS with authentication (HTTPS, MQTT over TLS on port 8883 with credentials, BLE pairing).
+ **Validate on the device**: never trust the range check in the app. The device clamps or rejects every value.

## Related notes

+ [MQTT_intro.md](MQTT_intro.md), [BLE_intro.md](BLE_intro.md), [IoT_Network.md](IoT_Network.md)
+ [../Android/HW/pwm_control.md](../Android/HW/pwm_control.md): PWM on RK3566 / Android (device tree, sysfs, HAL, app)
+ [../Linux/Kernel/pwm_consumer_driver.md](../Linux/Kernel/pwm_consumer_driver.md): a kernel driver that owns a PWM
+ [../Embedded/RPi5_gpio_ctrl.md](../Embedded/RPi5_gpio_ctrl.md), [../Embedded/OPi5_gpio_ctrl.md](../Embedded/OPi5_gpio_ctrl.md)
+ [../HW/transistor_BJT_MOSFET.md](../HW/transistor_BJT_MOSFET.md): driving a PWM load (LED, fan, motor) from a GPIO with a MOSFET or BJT

## Reference

+ [Linux PWM interface (kernel docs)](https://docs.kernel.org/driver-api/pwm.html)
+ [ESP-IDF LED control (LEDC)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/peripherals/ledc.html)
+ [MDN: Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API), [MDN: WebSockets API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
+ [MQTT specification](https://mqtt.org/mqtt-specification/)
