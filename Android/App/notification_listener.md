# NotificationListenerService

`NotificationListenerService` is a framework service class. An app subclasses it to get a callback whenever any app posts, updates, or removes a notification.
It can read the posting package, the title and text, the flags, and the actions of every notification on the device. Android therefore treats it as a sensitive capability: the listener receives nothing until the user grants it **notification access**.

A typical embedded use is to react to other apps' notifications with hardware, for example an RGB LED on an RK3566 board.
The listener only provides the events. It gives the app no hardware access (section 6).

## 1. Workflow

```text
SETUP (once)

  listener app installed (service declared in the manifest, section 2)
        |
        v
  notification access granted: user in Settings, adb, or overlay (section 5)
        |
        v
  system_server: NotificationManagerService (NMS) binds the listener service
        |
        v
  listener app: onListenerConnected()
        |  getActiveNotifications(): catch up on notifications posted earlier
        v
  ready

RUNTIME (every post, update, or removal)

  any app: NotificationManager.notify() / cancel(), or the user dismisses it
        |
        v
  system_server: NMS
        |  stores it as a StatusBarNotification (key: user, package, id, tag)
        |  for each bound listener with access: apply its filter types
        |  Binder callback into the listener's process
        v
  listener app, main thread: onNotificationPosted(sbn) / onNotificationRemoved(sbn)
        |  filter: package, ongoing, group summary (section 4)
        |  compute the new state, hand it to a worker thread
        v
  listener app, worker thread
        |  Binder call to the component that owns the LED (section 6):
        |    vendor system app   -> vendor AIDL HAL
        |    customer app        -> LED bridge system app -> vendor AIDL HAL
        v
  vendor HAL: /sys/class/leds/<led>/  brightness, trigger, delay_on, delay_off
```

The system keeps the listener bound, which usually keeps its process alive.
If the process dies anyway, NMS binds again, and the listener gets `onListenerConnected()` again. Call `getActiveNotifications()` there, because notifications may have changed while it was gone.

## 2. Declare the service

```xml
<!-- AndroidManifest.xml -->
<service
    android:name=".LedNotificationListener"
    android:label="@string/listener_label"
    android:exported="false"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
    <!-- optional, Android 12+: which notification types the listener gets by default -->
    <meta-data
        android:name="android.service.notification.default_filter_types"
        android:value="conversations|alerting" />
</service>
```

+ `BIND_NOTIFICATION_LISTENER_SERVICE` is the permission the **binder** must hold. Only the system holds it, so no other app can bind to the service.
  The app doesn't request it with `<uses-permission>`.
+ The label is the name the user sees on the notification access screen.
+ The app doesn't start the service. The system binds to it once access is granted, and binds again after the process dies.

## 3. Callbacks

| Callback | When |
| --- | --- |
| `onListenerConnected()` | The system has bound the service. From now on `getActiveNotifications()` works; use it to pick up notifications posted before the listener connected |
| `onNotificationPosted(sbn)` | A notification was posted, **or an existing one was updated** (same key). Expect several calls for one message |
| `onNotificationRemoved(sbn)` | A notification was cancelled or dismissed. The overload with a `reason` (API 26+) says why, for example `REASON_CLICK` or `REASON_CANCEL` |
| `onListenerDisconnected()` | The system unbound the service, for example because the user revoked access |

The `StatusBarNotification` (`sbn`) gives `packageName`, `key`, `postTime`, `isOngoing`, and the `Notification` itself.
The text is in `notification.extras`, for example `getCharSequence(Notification.EXTRA_TITLE)` and `EXTRA_TEXT`.

Besides reading, a listener can cancel notifications (`cancelNotification(key)`), snooze them (`snoozeNotification(key, durationMs)`, API 26+), and send their actions (`notification.actions[i].actionIntent`).

## 4. Example: count unread notifications for an LED

The callbacks run on the app's main thread. Keep them short and do the slow work (here a Binder call to an LED service) on another thread.
Recomputing the state from `activeNotifications` on every change is simpler than tracking posts and removals, and it handles updates and group summaries correctly:

```kotlin
class LedNotificationListener : NotificationListenerService() {

    private val watchedPackages = setOf("com.example.chat")
    private val worker = Executors.newSingleThreadExecutor()

    override fun onListenerConnected() = refresh()
    override fun onNotificationPosted(sbn: StatusBarNotification) = refresh()
    override fun onNotificationRemoved(sbn: StatusBarNotification) = refresh()

    private fun refresh() {
        val unread = activeNotifications.orEmpty().count(::isRelevant)
        worker.execute { setLed(on = unread > 0) }
    }

    private fun isRelevant(sbn: StatusBarNotification): Boolean =
        sbn.packageName in watchedPackages &&
            !sbn.isOngoing &&
            (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY) == 0

    private fun setLed(on: Boolean) {
        // call the LED service here, see section 6
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }
}
```

+ Filter by package first. Ongoing notifications (music, downloads, foreground services) and group summaries usually shouldn't count.
+ Don't log `EXTRA_TITLE` or `EXTRA_TEXT`. Notifications contain private messages and one-time codes.

## 5. Grant notification access

The app can't grant the access to itself. The ways to grant it:

| Who | How |
| --- | --- |
| The user | **Settings > Apps > Special app access > Notification access** (the exact path depends on the build). The app can open the list with `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`, or, on API 30+, its own entry with `Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS` and `Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME` (the flattened `ComponentName`) |
| A developer | `adb shell cmd notification allow_listener com.example.app/.LedNotificationListener` (and `disallow_listener`) |
| The device image | For a preinstalled system app, list the package in the framework overlay `config_defaultListenerAccessPackages` |

Check the state in the app with `NotificationManager.isNotificationListenerAccessGranted(ComponentName)` (API 27+) or `NotificationManagerCompat.getEnabledListenerPackages()`.
From the shell: `adb shell settings get secure enabled_notification_listeners`.

Since Android 13, an app installed from an APK file instead of from an app store may be blocked from getting notification access by **restricted settings**.
The user must first allow restricted settings on the app's App info screen. A preinstalled app isn't affected.

## 6. From notifications to the board LED

A listener sees the notifications of every app, but it still can't write `/sys/class/leds/` or call a vendor HAL.
It needs a component that may drive the LED:

| Listener in | LED path | Note |
| --- | --- | --- |
| A vendor system app | The app calls a vendor AIDL HAL through Binder | No public interface needed; the policy stays in the image ([../HW/notification_led.md](../HW/notification_led.md#4-driving-a-non-led-gpio-from-notifications), approach C) |
| A customer (3rd-party) app | The app calls the public interface of an LED bridge system app, which calls the HAL | The customer decides which notifications count ([../HW/rgb_led_customer_app.md](../HW/rgb_led_customer_app.md)) |

The standard notification light is a different mechanism. It shows only the app's **own** notifications, and NMS decides when ([../HW/notification_led.md](../HW/notification_led.md)).

## Related notes

+ [../HW/notification_led.md](../HW/notification_led.md): the standard notification light, and approach C (listener + GPIO HAL)
+ [../HW/rgb_led_customer_app.md](../HW/rgb_led_customer_app.md): a public RGB LED interface for a customer app
+ [AndroidManifest.md](AndroidManifest.md): services, permissions, `android:exported`
+ [app_components.md](app_components.md): services and bound services
+ [app_background_limits.md](app_background_limits.md): when app code may run in the background

## Reference

+ [`NotificationListenerService`](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
+ [`StatusBarNotification`](https://developer.android.com/reference/android/service/notification/StatusBarNotification)
+ [`Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`](https://developer.android.com/reference/android/provider/Settings#ACTION_NOTIFICATION_LISTENER_SETTINGS)
+ [Notifications overview](https://developer.android.com/develop/ui/views/notifications)
