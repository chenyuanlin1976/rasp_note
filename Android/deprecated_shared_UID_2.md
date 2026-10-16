# Bound Services/ AIDL

To show how to use **Bound Services/ AIDL** (Android Interface Definition Language) as an alternative to `sharedUserId`,  
let's look at how **App A** can host a service that exposes a method, and **App B** can bind to it across process boundaries to execute that method securely.

## Step 1: Define the Interface using AIDL (.aidl file)

**AIDL allows you to define a programming interface that both client and service agree upon so they can communicate across process boundaries (IPC).**
Create a file named `IMyService.aidl` in both App A and App B under the exact same package directory  
(e.g., src/main/aidl/com/example/shared/IMyService.aidl):

```java
// Package statement must match your directory structure
package com.example.shared;

interface IMyService {
    // Define a method that App B can call on App A
    String getSecureData();
}
```

## Step 2: In App A (The Service Provider)

### 1. Implement the Stub in App A

Create a service that extends the generated IMyService.Stub class:

```kotlin
package com.example.appa

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.example.shared.IMyService

class DataSharingService : Service() {

    // Implement the AIDL interface stub
    private val binder = object : IMyService.Stub() {
        override fun getSecureData(): String {
            // Perform work inside App A and return data to App B securely
            return "Hello from App A's private process!"
        }
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }
}
```

### 2. Declare the Service in App A's AndroidManifest.xml

Protect the service with a signature-level permission so only apps signed with your certificate can bind to it.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.appa">

    <!-- Define a signature-level permission -->
    <permission
        android:name="com.example.appa.PERMISSION_BIND_SERVICE"
        android:protectionLevel="signature" />

    <application>
        <service
            android:name=".DataSharingService"
            android:exported="true"
            android:permission="com.example.appa.PERMISSION_BIND_SERVICE" />
    </application>
</manifest>
```

### Step 3: In App B (The Client)

1. Request the Permission in App B's `AndroidManifest.xml`,  
   App B must ask for the signature-level permission to bind to App A's service:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.appb">

    <!-- Request App A's signature permission -->
    <uses-permission android:name="com.example.appa.PERMISSION_BIND_SERVICE" />

    <application>
        <!-- ... -->
    </application>
</manifest>
```

2. Bind to App A and Call the Method from App B,  
   In your Activity or component in App B, create an explicit Intent targeting App A's service, bind to it, and use the interface:


```kotlin
package com.example.appb

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.example.shared.IMyService

class MainActivity : AppCompatActivity() {

    private var myService: IMyService? = null
    private var isBound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            // Convert the raw IBinder into your AIDL interface
            myService = IMyService.Stub.asInterface(service)
            isBound = true

            // Safely call the method across process boundaries
            val data = myService?.secureData()
            Log.d("AppB", "Data received from App A: $data")
        }

        override fun onServiceDisconnected(className: ComponentName) {
            myService = null
            isBound = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bindToAppAService()
    }

    private fun bindToAppAService() {
        val intent = Intent().apply {
            // Explicitly target App A's package and service class
            setComponent(ComponentName("com.example.appa", "com.example.appa.DataSharingService"))
        }
        // Bind to the service securely
        bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isBound) {
            unbindService(connection)
            isBound = false
        }
    }
}
```

## Key Takeaways

+ Process Separation: App A and App B remain safely separated in their own sandboxes with distinct Linux user IDs.
+ Controlled Access: Using `android:protectionLevel="signature"` guarantees that  
  only apps signed with your specific keystore can ever bind to this service or call its functions.
