# android note

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
