'https://stackoverflow.com/questions/8531926/how-to-start-a-service-when-apk-is-installed-for-the-first-time'

# All applications, upon installation, are placed in a "stopped" state.
This is the same state that the application winds up in after the user force-stops the app from the Settings application.
While in this "stopped" state, the application will not run for any reason, except by a manual launch of an activity.
Notably, no BroadcastReceviers will be invoked, regardless of the event for which they have registered, until the user runs the app manually.

The app won't run any services or broadcast receivers unless it's in started state.
It's in started state after it's been run from launcher or via ADB.

# Applications installed on the /system partition are not subject to being placed into the "stopped" state after installation.
a. /system/app: For standard system applications.
b. /system/priv-app: For privileged system applications that require special permissions or access to hidden APIs.

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

# factory reset
A factory reset on an Android device erases all user data and settings,
but it does not remove pre-installed system apps located in the /system/app or /system/priv-app directories.
These system apps, along with the operating system itself, are located on a separate partition that is not affected by the factory reset process.
