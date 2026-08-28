# AndroidManifest

The `AndroidManifest.xml` file is an essential control center located at the root of every Android app's **project** source set.  
It provides essential information about your application to the Android system,  
which the OS must have before it can run any of the app's code.

## Key Components Declared in the Manifest

+ App Components: Every Activity, Service, Broadcast Receiver, and Content Provider in your app must be declared here so the system knows they exist.
+ Permissions: Requests for protected system features or user data  
  (e.g., `<uses-permission android:name="android.permission.INTERNET" />`).
+ Hardware & Software Features: Hardware requirements like camera availability, Bluetooth capabilities, or minimum required OpenGL ES versions.
+ App Identity & Metadata: The app's package name, launcher icon, theme, app label, and version codes.

## Example Manifest Structure

```XML
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissions required by the app -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.MyApplication">

        <!-- Main/Launcher Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Other app components go here -->
    </application>

</manifest>
```

## Crucial Attributes

+ android:exported: Since Android 12 (API level 31), any component (Activity, Service, Receiver) containing an intent filter  
  must explicitly set `android:exported="true"` if it can be launched by other apps (like the system home screen launching your main activity),  
  or false if it is strictly internal.
+ Intent Filters: Tell the Android system which intents components are willing to receive, defining entry points to your application.
