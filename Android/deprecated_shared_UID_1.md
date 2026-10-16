# Content Providers

Let's look at a concrete code example of the most common modern replacement for `sharedUserId`: Content Providers.

Suppose you have App A (which owns a database of user settings) and App B (which needs to read those settings).  
Instead of sharing a Linux UID, **App A** exposes its data securely via a **ContentProvider**,  
and **App B** queries it using a **ContentResolver**.

## Step 1: In App A (The Data Provider)

### 1. Define the Provider in App A's **AndroidManifest.xml**

You define a **ContentProvider** and protect it with a custom permission  
so only your apps (signed with the same signing key) can access it.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.appa">

    <!-- Define a custom signature-level permission -->
    <permission
        android:name="com.example.appa.PERMISSION_ACCESS_DATA"
        android:protectionLevel="signature" />

    <application>
        <provider
            android:name=".SettingsContentProvider"
            android:authorities="com.example.appa.provider"
            android:exported="true"
            android:permission="com.example.appa.PERMISSION_ACCESS_DATA" />
    </application>
</manifest>
```

Note: `android:protectionLevel="signature"` ensures that  
Android will only grant this permission to other apps signed with your exact same release/debug keystore.

### 2. Implement the Content Provider in App A

Create the provider class to handle queries:

```kotlin
package com.example.appa

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

class SettingsContentProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): Cursor? {
        // Return your app's private data securely (e.g., from SQLite or SharedPreferences)
        val cursor = MatrixCursor(arrayOf("key", "value"))
        cursor.addRow(arrayOf("theme_mode", "dark"))
        return cursor
    }

    override fun getType(uri: Uri): String = "vnd.android.cursor.dir/vnd.com.example.appa.setting"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?): Int = 0
}
```

## Step 2: In App B (The Data Consumer)

### 1. Request the Permission in App B's AndroidManifest.xml

App B must declare that it wants to use the signature-protected permission defined by App A:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.appb">

    <!-- Request App A's custom signature permission -->
    <uses-permission android:name="com.example.appa.PERMISSION_ACCESS_DATA" />

    <application>
        <!-- ... -->
    </application>
</manifest>
```

### 2. Query App A's Data from App B

Now, App B can safely query App A's **ContentProvider** using a **ContentResolver**:

```kotlin
package com.example.appb

import android.content.ContentResolver
import android.net.Uri
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        readSettingsFromAppA()
    }

    private fun readSettingsFromAppA() {
        val uri = Uri.parse("content://com.example.appa.provider/settings")
        val resolver: ContentResolver = contentResolver

        // Safely query App A's process
        resolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val keyIndex = cursor.getColumnIndex("key")
                val valueIndex = cursor.getColumnIndex("value")
                
                while (!cursor.isAfterLast) {
                    val key = cursor.getString(keyIndex)
                    val value = cursor.getString(valueIndex)
                    // Do something with the shared data securely
                    cursor.moveToNext()
                }
            }
        }
    }
}
```

## Why this is safer than sharedUserId

+ Isolated Processes: App A and App B still run in completely separate application sandboxes with their own distinct Linux UIDs.
+ Granular Control: App A explicitly chooses what data to expose and who can see it (via signature permissions),  
  rather than giving full, unmitigated access to its entire file directory.
