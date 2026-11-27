# RGB LED for a customer app: interfaces and hand-off (Android 14, RK3566)

A customer app, for example a CMS (content management system) or signage app, wants to show its own states on the board's RGB LED: new message, error, sync running.
The board vendor owns the LED hardware and the image.
This note covers the split between them: which interfaces exist, what goes into each one, and what both sides must agree on.

If the LED only has to show notifications, you need no custom interface. Use the standard notification light ([notification_led.md](notification_led.md)).
A custom interface is for app-defined states that don't fit the notification policy (the notification light is used only while the screen is off and can be suppressed by DND).

The customer app can also light the LED for **other** apps' notifications, for example a chat app on the same device.
It then adds a `NotificationListenerService` that filters those notifications and calls `setState()` / `clearState()` on this interface ([../App/notification_listener.md](../App/notification_listener.md)).
The listener only provides the events. It doesn't give the app access to the LED.

## 1. Two interfaces, not one

```text
customer app (3rd-party or preinstalled, signed with the customer's key)
  |  bindService(), public AIDL com.example.rgbled.IRgbLed  (shipped as an AAR)
  v
LED bridge system app (board vendor, platform-signed, /system_ext/priv-app)
  |  checks the caller, arbitrates between sources and priorities
  |  Binder, stable AIDL vendor.example.hardware.rgbled.IRgbLed/default
  v
vendor LED HAL (/vendor/bin/hw/, NDK backend, its own SELinux domain)
  |  brightness (or multi_intensity), trigger, delay_on, delay_off
  v
kernel: /sys/class/leds/<red|green|blue>/  or one multicolor LED class device
```

| | Public app interface | Vendor HAL interface |
| --- | --- | --- |
| Package | `com.<vendor>.rgbled` (an app package) | `vendor.<company>.hardware.rgbled` |
| Stability | Ordinary app AIDL; evolve it by only appending methods | `@VintfStability`, `stability: "vintf"`, frozen versions |
| Server | Bound service in the bridge system app | Native vendor HAL process |
| Clients | Customer apps | Only the bridge app (`hal_client_domain`) |
| Contains | States, sources, priorities | One effective LED state |

The customer's app can't use the vendor HAL interface directly:

+ `ServiceManager` is a hidden API, and `untrusted_app` may only find `app_api_service` services.
+ Treble keeps apps away from vendor services, and `neverallow` rules prevent you from opening that path.
+ The HAL interface can change with the board revision. The public interface the customer builds against must not.

The proxy pattern (manifest, client code, SELinux for the bridge app, delivering the AAR) is described in [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md).
This note covers only what is specific to the LED.

## 2. The public app interface

Design it around states, not sysfs paths or kernel trigger names, so that it works with every board revision:

```java
// IRgbLed.aidl: public, shipped to the customer in the AAR
package com.example.rgbled;

interface IRgbLed {
    const int MODE_SOLID = 1;
    const int MODE_BLINK = 2;

    const int PRIORITY_LOW = 0;      // for example "sync running"
    const int PRIORITY_NORMAL = 1;   // for example "new message"
    const int PRIORITY_HIGH = 2;     // for example "error"

    const int CAP_RGB = 1;           // independent red, green, blue channels
    const int CAP_DIMMING = 2;       // PWM levels, not only on/off
    int getCapabilities();

    /**
     * Sets the caller's request for one source. color is 0xRRGGBB.
     * onMs/offMs are used only for MODE_BLINK.
     * Throws IllegalArgumentException for invalid values.
     */
    void setState(int sourceId, int color, int mode, int onMs, int offMs, int priority);

    /** Removes the caller's request for one source. The LED shows the next request, or turns off. */
    void clearState(int sourceId);
}
```

+ **Sources:** the bridge stores requests by calling UID and `sourceId`.
  Then the app can clear "new message" when the message is read without also clearing "error".
  The request with the highest priority wins; among equal priorities, the most recent one wins.
+ **Capabilities:** with GPIO LEDs (`max_brightness` = 1), each channel is only on or off, so the LED can show 7 colors.
  Advertise this, and add modes such as "pulse" only if the hardware can do them (a controller with its own pattern engine), instead of faking them on every board.
+ **Client death:** if the app crashes, its requests should go away.
  Let the client register a callback or pass a binder token, and drop its requests in `RemoteCallbackList.onCallbackDied()` or a `linkToDeath()` handler ([../IPC/AIDL_callback.md](../IPC/AIDL_callback.md)).
+ **Bursts:** the bridge computes the effective state and calls the HAL only when it changes, like `LightsService` does ([LightsService_intro.md](LightsService_intro.md#31-unchanged-requests-dont-reach-the-hal)).
+ **Access:** protect the service with a permission defined in the bridge app.
  For a customer app signed with its own key, use `signature|knownSigner` with the customer's certificate digest (Android 12+), or check the caller with `hasSigningCertificate()` ([../Signing/signature_permission.md](../Signing/signature_permission.md)).
  `privapp-permissions` XML is for privileged permissions of priv-apps, so it is needed only for the bridge app, not for the customer's app.

## 3. The vendor HAL interface

The HAL knows nothing about sources or priorities. That policy lives in the bridge app, which is easier to update than vendor code:

```java
// vendor/example/hardware/rgbled/aidl/vendor/example/hardware/rgbled/LedMode.aidl
package vendor.example.hardware.rgbled;

@VintfStability
@Backing(type="int")
enum LedMode { OFF, SOLID, BLINK }
```

```java
// vendor/example/hardware/rgbled/aidl/vendor/example/hardware/rgbled/IRgbLed.aidl
package vendor.example.hardware.rgbled;

import vendor.example.hardware.rgbled.LedMode;

@VintfStability
interface IRgbLed {
    /** color is 0xRRGGBB. onMs/offMs are used only for LedMode.BLINK. Fails with EX_ILLEGAL_ARGUMENT if they are <= 0. */
    void setState(int color, LedMode mode, int onMs, int offMs);
    int getCapabilities();
}
```

+ Build the interface with the Java backend enabled as well as the NDK backend, so the bridge app can call it. Implement the server with the NDK backend.
  For VINTF, init, and SELinux, see [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md), and for the bridge app's `hal_client_domain`, see [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md#4-selinux-on-the-system-app-side-only).
+ Converting the color into writes is the same as in the Lights HAL: split it into 3 channels scaled to each `max_brightness`, or write `multi_intensity` on a multicolor LED class device. Blink with the kernel `timer` trigger ([../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#3-state-updates-setlightstate)).
+ Only one process may write an LED. If the board's Lights HAL also reports this LED (as `BATTERY` or `NOTIFICATIONS`), remove it there, or let one HAL own the LED and arbitrate. Otherwise the 2 HALs overwrite each other.

## 4. Hand-off checklist

| Topic | Agree on | Owner |
| --- | --- | --- |
| Interface version | Freeze the public `.aidl` before the customer starts. Later changes only append methods | Board vendor |
| Values and errors | Color format, allowed `onMs` / `offMs` range, which calls throw which exceptions | Both |
| Policy | Priorities, what the LED shows at boot and with no requests, whether the state changes with the screen on or off | Both |
| Concurrency | Calls arrive on Binder threads; the bridge serializes them and coalesces bursts | Board vendor |
| Access | Is the customer app 3rd-party or preinstalled? Which certificate digest goes into `knownCerts`? | Both |
| Delivery | AAR with the stubs and a wrapper class (binding, reconnect, capability check), plus a test APK that shows every color and blink rate | Board vendor |
| Hardware | sysfs node names, `max_brightness` per channel, PWM or GPIO, `CONFIG_LEDS_TRIGGER_TIMER`, sharing with the battery or notification light | Board vendor |

## Related notes

+ [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md): the system-app proxy, client code, SELinux, delivering the AAR
+ [Led_control.md](Led_control.md): Lights HAL vs. vendor LED HAL, kernel blinking, sysfs permissions
+ [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md): color-to-sysfs conversion and write order
+ [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md): building and registering a vendor AIDL HAL
+ [notification_led.md](notification_led.md): the standard notification light, and reacting to other apps' notifications
+ [../App/notification_listener.md](../App/notification_listener.md): `NotificationListenerService`, notification access
+ [LightsService_platform_app.md](LightsService_platform_app.md): controlling the standard lights from a platform-signed app
+ [../IPC/AIDL_callback.md](../IPC/AIDL_callback.md), [../Signing/signature_permission.md](../Signing/signature_permission.md), [../App/jar_aar_intro.md](../App/jar_aar_intro.md)

## Reference

+ [AIDL overview](https://source.android.com/docs/core/architecture/aidl)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [Define a custom app permission](https://developer.android.com/guide/topics/permissions/defining)
+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
