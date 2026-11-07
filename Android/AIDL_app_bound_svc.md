# AIDL bound service in Android Studio (Kotlin)

This note walks through an app-level AIDL service and its client, end to end, with current Android Studio/AGP (Android 14+, API 34+).
The **service** answers requests; the **client** binds to it and calls it.
For the concepts, see [AIDL_intro.md](AIDL_intro.md).

## 1. Enable AIDL in Gradle

Starting with **AGP 8.0**, AIDL compilation is **off by default**. Enable it in the module's `build.gradle.kts`, then sync Gradle:

```kotlin
android {
    namespace = "com.example.aidldemo"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.aidldemo"
        minSdk = 24
        targetSdk = 34
    }

    buildFeatures {
        aidl = true   // required on AGP 8+
    }
}
```

## 2. Create the `.aidl` file

Put it under `app/src/main/aidl/`, in a directory that **matches the package name**.
You can also right-click the module and choose **New > AIDL > AIDL File**.

```java
// app/src/main/aidl/com/example/aidldemo/IMyAidlInterface.aidl
package com.example.aidldemo;

interface IMyAidlInterface {
    int getPid();
    int add(int a, int b);
    String getMessage(String name);
}
```

Then run **Build > Make Project**. AGP generates the Java file
`app/build/generated/aidl_source_output_dir/<variant>/out/com/example/aidldemo/IMyAidlInterface.java`.
It contains `IMyAidlInterface.Stub`.

## 3. Implement the service

```kotlin
package com.example.aidldemo

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Process
import android.util.Log

class MyAidlService : Service() {

    // Runs on binder threads, NOT the main thread -> must be thread-safe
    private val binder = object : IMyAidlInterface.Stub() {
        override fun getPid(): Int = Process.myPid()

        override fun add(a: Int, b: Int): Int {
            Log.d(TAG, "add($a, $b)")
            return a + b
        }

        override fun getMessage(name: String?): String =
            "Hello from AIDL service, ${name ?: "Guest"}!"
    }

    override fun onBind(intent: Intent): IBinder = binder

    private companion object { const val TAG = "MyAidlService" }
}
```

## 4. Declare the service in `AndroidManifest.xml`

```xml
<application ... >
    <!-- Same-app clients only: exported="false" -->
    <!-- Other apps must bind: exported="true" + an intent-filter, protected by a permission -->
    <service
        android:name=".MyAidlService"
        android:exported="true"
        android:permission="com.example.aidldemo.permission.BIND_MY_SERVICE">
        <intent-filter>
            <action android:name="com.example.aidldemo.IMyAidlInterface" />
        </intent-filter>
    </service>
</application>

<permission
    android:name="com.example.aidldemo.permission.BIND_MY_SERVICE"
    android:protectionLevel="signature" />
```

+ Use `exported="false"` if only your own app binds.
+ If `exported="true"`, protect the service with `android:permission`. A `signature` permission allows only apps signed with your key.
  Otherwise, any app can call your service.

## 5. Bind from a client (Activity)

```kotlin
package com.example.aidldemo

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.RemoteException
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private var aidlService: IMyAidlInterface? = null
    private var isBound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            aidlService = IMyAidlInterface.Stub.asInterface(service)
            // Note: this callback runs on the MAIN thread. A remote call here blocks the UI
            // until the server replies, so move slow calls to a background thread / coroutine.
            try {
                Log.d(TAG, "remote pid=${aidlService?.pid}, 10+20=${aidlService?.add(10, 20)}")
            } catch (e: RemoteException) {
                Log.e(TAG, "remote call failed", e)
            }
        }

        // Called only when the service process crashes / is killed, NOT on unbindService().
        // The binding itself stays registered (the system reconnects later),
        // so keep isBound = true and still call unbindService() in onStop().
        override fun onServiceDisconnected(name: ComponentName) {
            aidlService = null
        }
    }

    override fun onStart() {
        super.onStart()
        // Same app: explicit class
        val intent = Intent(this, MyAidlService::class.java)
        // Other app: action + package (setPackage is required; implicit service intents are rejected)
        // val intent = Intent("com.example.aidldemo.IMyAidlInterface").setPackage("com.example.aidldemo")
        isBound = bindService(intent, connection, Context.BIND_AUTO_CREATE)   // false: not found / not allowed
    }

    override fun onStop() {
        super.onStop()
        if (isBound) {
            unbindService(connection)
            isBound = false
            aidlService = null
        }
    }

    private companion object { const val TAG = "MainActivity" }
}
```

Notes:

+ Kotlin maps the AIDL method `getPid()` to the property `aidlService?.pid`.
+ Pair `bindService` with `unbindService` in matching lifecycle callbacks (`onStart`/`onStop` or `onCreate`/`onDestroy`).
  Otherwise the `ServiceConnection` leaks.
  `isBound` tracks the *binding* (the result of `bindService()`), not whether the service is currently connected.
+ `ServiceConnection` also has `onBindingDied()` (API 26+: the binding is dead for good, so unbind and bind again)
  and `onNullBinding()` (API 28+: the service returned `null` from `onBind()`).

## 6. Cross-app checklist

+ The client app needs its **own copy of the same `.aidl` file**, with the same package and the same signatures.
  Alternatively, ship a JAR/AAR (see [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)).
+ **Package visibility (API 30+)**: the client declares the server package in its manifest:

  ```xml
  <queries>
      <package android:name="com.example.aidldemo" />
  </queries>
  ```

+ The client requests the permission with `<uses-permission android:name="com.example.aidldemo.permission.BIND_MY_SERVICE" />`.
+ On the server, you can also check the caller with `Binder.getCallingUid()` and `packageManager.getPackagesForUid()`.

## 7. Best practices

+ **Threading**: server methods run on binder threads, so make them thread-safe.
  Client calls block, so don't make slow calls on the main thread (ANR risk).
+ **Errors**: every remote call can throw `RemoteException` / `DeadObjectException`. Handle these exceptions.
+ **Background limits (Android 8+ / 14)**: a bound service lives only while clients are bound.
  If it has to keep running after that, it must become a foreground service with a declared `foregroundServiceType` (required on Android 14).

## Related notes

+ [AIDL_intro.md](AIDL_intro.md), [AIDL_call_flow.md](AIDL_call_flow.md)
+ [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)
+ [sharedUserId.md](sharedUserId.md): why cross-app calls use a bound service instead of a shared UID; [ContentProvider_sharing.md](ContentProvider_sharing.md)

## Reference

+ [AIDL (developer.android.com)](https://developer.android.com/develop/background-work/services/aidl)
+ [Bound services overview](https://developer.android.com/develop/background-work/services/bound-services)
