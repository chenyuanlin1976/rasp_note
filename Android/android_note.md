# android note

## Android studio icons

The type of folders or module

1. Green dot: Application/App module, Executable main program/ App.
   e.g.: `com.android.application`
2. Three vertical bars: Android library
   e.g.: `com.android.library`
3. Blue square: source root  
   e.g.: `src/main/java` or `src/main/kotlin`
4. Coffee Cup: **pure** Java/Kotlin class library. NOT includes Android resource.

## The Build Variants panel

It in Android Studio controls how Gradle builds and packages your application.  
It is the intersection of Build Types (developer-facing environments like debug or release)  
and Product Flavors (user-facing versions like free or paid, or staging and production).

### Accessing Build Variants

+ Go to View > Tool Windows > Build Variants from the menu bar.  
+ Alternatively, click the Build Variants tab usually pinned to the left edge or bottom-left tool window bar.

### Key Components

+ Module Column: Lists the modules in your project (e.g., :app).
+ Active Build Variant Column: A dropdown menu for each module that lets you switch the active variant you want to test, run, or compile.
+ Default Setup: Out of the box, Android Studio creates two build types for every module:
  + debug: Configured for development, enables debugging tools, and signs the app with a default debug keystore.  
  + release: Configured for production, typically applies code shrinking, obfuscation (R8/ProGuard), and requires a custom release signing key.  

### Common Use Cases

+ Multiple Environments: Setting up staging and production flavors with distinct API endpoints  
  and separate applicationIdSuffix values so both versions can live on the same device simultaneously.  
+ App Tiers: Creating free and paid variants to gate certain features or resources.
+ Source Sets: Organizing code or resources specific to a variant  
  (e.g., placing custom assets inside a src/staging/ folder instead of the main source set).

Note: Any changes made to build types or product flavors in your module-level build.gradle or build.gradle.kts files  
  require you to click Sync Now before they populate correctly in the Build Variants panel.

## how-to-start-a-service-when-apk-is-installed-for-the-first-time

1. All applications, upon installation, are placed in a "**stopped**" state.  
   This is the same state that the application winds up in after the user force-stops the app from the Settings application.  
   While in this "stopped" state, the application will NOT run for any reason, except by a manual launch of an activity.  
   Notably, no BroadcastReceviers will be invoked, regardless of the event for which they have registered, until the user runs the app manually.  

   The app won't run any services or broadcast receivers unless it's in started state.  
   It's in started state after it's been run from launcher or via ADB.

2. Applications installed on the /system partition are NOT subject to being placed into the "stopped" state after installation.  

   a. **/system/app**: For standard system applications.  
   b. **/system/priv-app**: For privileged system applications that require special permissions or access to hidden APIs.

If you have root, you can do,  
`$adb root`  
`$adb remount`  
`$adb push yourApk /system/app`

And it can immediately receive broadcast intents.  
This certainly doesn NOT provide a general purpose solution, but i wanted to mention it for completeness.

EDIT: Keep in mind that different versions of Android locate system APKs in different places.  
For example, Android 8 puts them under /system/app//.apk. Shell into your device and poke around and follow the same scheme used for other system APKs.

He will be able to update a system app. As long as you have the same package name and signing you can update a system app.  
The update will be placed on the data partition but still have the "system" status since a previous version is available on the system partition.

That's because all installed applications are in stopped state. In this state applications will not receive ANY broadcast notifications.  
In order to activate your application some other application (or user) needs to start your service or activity, or content provider.  
The usual workflow is when user clicks on your application's icon.

[Ref](https://stackoverflow.com/questions/8531926/how-to-start-a-service-when-apk-is-installed-for-the-first-time)

## sharedUserId

In Android, **android:sharedUserId** is an attribute in the **AndroidManifest.xml** file that allows multiple applications to share the same Linux user ID (UID).  
This enables them to run in the same process and access each other's data and code with the same permissions.  

When applications declare the same **android:sharedUserId** in their manifests and are **signed with the same certificate**,  
they will be assigned the same UID by the Android system.  

| AndroidManifest.xml                       | Android.mk                  |
|-------------------------------------------|-----------------------------|
| android:sharedUserId="android.uid.system" | LOCAL_CERTIFICATE:=platform |
| android:sharedUserId="android.uid.nfc"    | LOCAL_CERTIFICATE:=platform |
| android:sharedUserId="android.uid.se"     | LOCAL_CERTIFICATE:=platform |
| android:sharedUserId="android.uid.shared" | LOCAL_CERTIFICATE:=shared   |
| android:sharedUserId="android.media"      | LOCAL_CERTIFICATE:=media    |

## applications: stopped/active states

## launchers apps

## Use wake locks

When it's necessary, you can use wake locks to keep the device from going to sleep.  
Device battery life will be significantly affected by the use of this API.  
**Do not acquire PowerManager.WakeLocks unless you really need them**, use the minimum levels possible, and be sure to release them as soon as possible.  

[Ref](https://developer.android.com/develop/background-work/background-tasks/awake/wakelock)

## android:persistent

[Ref](https://developer.android.com/guide/topics/manifest/application-element)

## factory reset

A factory reset on an Android device erases all user data and settings,  
but it does not remove pre-installed system apps located in the /system/app or /system/priv-app directories.  
These system apps, along with the operating system itself, are located on a separate partition that is not affected by the factory reset process.

## this usage

```JAVA
public class ContextWrapper extends Context {};
public class ContextThemeWrapper extends ContextWrapper {};
public class Activity extends ContextThemeWrapper {};
```

That is the reason when we need an argument **content** in the **activity class**,  
we can use **this** (this is the object of this activity)

## Android 14: To invoke an Activity from a Service

To invoke an Activity from a Service on Android 14,  
you must pass an Intent with the `Intent.FLAG_ACTIVITY_NEW_TASK` flag,  
but your app must also comply with Android 14's strict *Background Activity Launch (BAL) restrictions*.

### How to Start the Activity from a Service

Because a Service does not run inside an Activity context,  
Android requires a new task stack flag to launch UI elements.

```java
Intent intent = new Intent(this, TargetActivity.class);
intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
startActivity(intent);
```

### Android 14 Background Activity Launch (BAL) Rules

Starting with Android 14, the system blocks background services from abruptly popping an Activity onto the screen unless a specific exception is met.

+ Foreground State: Your app must be visible to the user or running an active,  
  legitimate Foreground Service with the correct `android:foregroundServiceType` declared in your **AndroidManifest.xml**.
+ System-Sent PendingIntent: If your app is in the background, activities can only be reliably launched if triggered by a system interaction,  
  such as a user tapping a notification.
+ Opt-In Flags: If another app binds to your service, that app must pass the `Context.BIND_ALLOW_ACTIVITY_STARTS` flag to allow your service to launch an activity.

### Best Practice Alternative

Android strongly discourages forcing an Activity to open automatically from a background service.  
Instead, use a high-priority notification:

1. Create a notification channel and build a notification.
2. Attach a `PendingIntent` to that notification.
3. Let the user tap the notification to safely open your Activity.
