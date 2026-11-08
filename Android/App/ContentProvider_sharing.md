# Sharing data between apps with a ContentProvider

A `ContentProvider` is the standard way for one app to share data with other apps **without** sharing a UID
(the deprecated `sharedUserId`, see [../Signing/sharedUserId.md](../Signing/sharedUserId.md)).
The provider app keeps its files private and decides exactly which rows or files are exposed, and to whom.

There are 2 ways to control access:

| Pattern | Provider | Who gets access | Typical use |
| --- | --- | --- | --- |
| A. Signature permission | `exported="true"` + `android:permission` | Every app signed with your key, permanently | Your own app family shares settings or a database |
| B. Per-URI grant | `exported="false"` + `grantUriPermissions="true"` | Only the app you hand a URI to, temporarily | Share one file or record with any app (for example, `FileProvider`) |

Example names:

| Item | Value |
| --- | --- |
| Provider app (App A) | `com.example.appa` |
| Client app (App B) | `com.example.appb` |
| Authority | `com.example.appa.provider` |
| Permission | `com.example.appa.permission.READ_SETTINGS` |
| URI | `content://com.example.appa.provider/settings` |
| Provider class | `AppSettingsProvider` (not to be confused with Android's own [SettingsProvider](../AOSP_cfg/SettingsProvider_intro.md)) |

## 1. Pattern A: provider protected by a signature permission

### 1.1 App A: manifest

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <permission
        android:name="com.example.appa.permission.READ_SETTINGS"
        android:protectionLevel="signature" />

    <application>
        <provider
            android:name=".AppSettingsProvider"
            android:authorities="com.example.appa.provider"
            android:exported="true"
            android:readPermission="com.example.appa.permission.READ_SETTINGS" />
    </application>
</manifest>
```

+ `android:readPermission` / `android:writePermission` protect queries and modifications separately.
  `android:permission` sets both at once.
+ The package name comes from `namespace` / `applicationId` in Gradle. The `package` attribute in the manifest is no longer used by AGP 8+.

### 1.2 App A: provider

```kotlin
package com.example.appa

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

class AppSettingsProvider : ContentProvider() {

    private val matcher = UriMatcher(UriMatcher.NO_MATCH).apply {
        addURI(AUTHORITY, "settings", SETTINGS)
    }

    override fun onCreate(): Boolean = true   // keep it cheap: it runs on the main thread at app start

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): Cursor? = when (matcher.match(uri)) {
        // Runs on a binder thread of App A. Real code would read SQLite / DataStore here.
        SETTINGS -> MatrixCursor(arrayOf(COL_KEY, COL_VALUE)).apply {
            addRow(arrayOf("theme_mode", "dark"))
        }
        else -> null
    }

    override fun getType(uri: Uri): String? = when (matcher.match(uri)) {
        SETTINGS -> "vnd.android.cursor.dir/vnd.com.example.appa.setting"
        else -> null
    }

    // Read-only provider
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?): Int = 0

    companion object {
        const val AUTHORITY = "com.example.appa.provider"
        const val COL_KEY = "key"
        const val COL_VALUE = "value"
        private const val SETTINGS = 1
    }
}
```

### 1.3 App B: manifest

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Declare the permission here too (allowed: same signing key), so it is defined whichever app is installed first -->
    <permission
        android:name="com.example.appa.permission.READ_SETTINGS"
        android:protectionLevel="signature" />
    <uses-permission android:name="com.example.appa.permission.READ_SETTINGS" />

    <!-- Package visibility (API 30+): without this, the provider can't be resolved -->
    <queries>
        <provider android:authorities="com.example.appa.provider" />
    </queries>

    <application>
        <!-- ... -->
    </application>
</manifest>
```

### 1.4 App B: query

```kotlin
package com.example.appb

import android.content.Context
import android.net.Uri
import android.util.Log

private const val TAG = "AppB"
private val SETTINGS_URI: Uri = Uri.parse("content://com.example.appa.provider/settings")

// Call this off the main thread: it is a cross-process call into App A.
fun readSettings(context: Context): Map<String, String> {
    val result = mutableMapOf<String, String>()
    try {
        context.contentResolver.query(SETTINGS_URI, arrayOf("key", "value"), null, null, null)?.use { c ->
            val keyIdx = c.getColumnIndexOrThrow("key")
            val valueIdx = c.getColumnIndexOrThrow("value")
            while (c.moveToNext()) {
                result[c.getString(keyIdx)] = c.getString(valueIdx)
            }
        } ?: Log.w(TAG, "provider not found or returned null")
    } catch (e: SecurityException) {
        Log.e(TAG, "permission not granted (different signing key?)", e)
    }
    return result
}
```

+ `query()` returns `null` if the provider is not installed or not visible (`<queries>` missing).
+ It throws `SecurityException` if App B doesn't hold the permission, for example because the apps are signed with different keys.
+ Signing rules (debug key, release key, Play App Signing, `knownSigner`) are in [../Signing/sharedUserId.md](../Signing/sharedUserId.md#51-limit-access-to-your-own-apps-signature-permissions).

## 2. Pattern B: temporary per-URI grants

The provider is **not exported**, so no app can open it on its own.
App A hands out a single URI together with a grant flag.
This is how `androidx.core.content.FileProvider` shares files.

### 2.1 App A: manifest

```xml
<provider
    android:name=".AppSettingsProvider"
    android:authorities="com.example.appa.provider"
    android:exported="false"
    android:grantUriPermissions="true" />
```

### 2.2 App A: grant access to one URI

```kotlin
val uri = Uri.parse("content://com.example.appa.provider/settings")

// Preferred: put the URI in the Intent that starts App B and add the flag.
// The grant lasts until the receiving activity's task finishes.
val intent = Intent().apply {
    setClassName("com.example.appb", "com.example.appb.ImportActivity")   // explicit target
    data = uri
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
}
startActivity(intent)

// Alternative: grant explicitly, and revoke when done.
// context.grantUriPermission("com.example.appb", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
// context.revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
```

+ Use an explicit target. With an implicit Intent, any app that matches the filter could receive the grant
  (with a chooser, the user picks the app, as in [section 3](#3-fileprovider-share-a-file)).
+ App B's `ImportActivity` must be `exported="true"`. Starting another app's activity needs no `<queries>` entry,
  even on API 30+; if App B isn't installed, `startActivity()` throws `ActivityNotFoundException`.

### 2.3 App B: read the granted URI

```kotlin
// In the activity that App A started
val uri = intent.data ?: return
contentResolver.query(uri, null, null, null, null)?.use { c ->
    if (c.moveToFirst()) {
        val value = c.getString(c.getColumnIndexOrThrow("value"))
    }
}
```

App B needs no `<uses-permission>` and no `<queries>` entry for this. The grant is attached to the Intent.

## 3. FileProvider: share a file

`androidx.core.content.FileProvider` is a ready-made pattern B provider for files.
Never share a `file://` URI: since Android 7.0 (API 24) it throws `FileUriExposedException` when it leaves the app.

```xml
<!-- App A: AndroidManifest.xml -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

```xml
<!-- App A: res/xml/file_paths.xml: only these directories can be shared -->
<paths>
    <files-path name="exports" path="exports/" />
</paths>
```

```kotlin
// App A: share filesDir/exports/report.csv with an app the user picks
val file = File(filesDir, "exports/report.csv")
val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
// -> content://com.example.appa.fileprovider/exports/report.csv
val send = Intent(Intent.ACTION_SEND).apply {
    type = "text/csv"
    putExtra(Intent.EXTRA_STREAM, uri)
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
}
startActivity(Intent.createChooser(send, null))
```

The receiving app opens it with `contentResolver.openInputStream(uri)`.

## 4. Test from adb

```shell
adb shell content query --uri content://com.example.appa.provider/settings
adb shell content query --uri content://com.example.appa.provider/settings --projection key:value --where "key='theme_mode'"
```

The `content` command runs as the `shell` user. It can read exported providers without a permission,
but it gets a `SecurityException` from a provider protected by a signature permission (pattern A) or not exported (pattern B).
That error confirms the protection works.

## 5. Why this is better than sharedUserId

+ Each app keeps its own UID, private data directory, and permissions.
+ The provider exposes only the URIs it chooses, and can check the caller in each method
  (`callingPackage`, `Binder.getCallingUid()`) for finer rules than one permission.
+ Access is granted per permission or per URI, and can be revoked, instead of full access to the other app's files.

## Related notes

+ [../Signing/sharedUserId.md](../Signing/sharedUserId.md): what `sharedUserId` was, migration, signature permissions
+ [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md): the other replacement, a bound service with AIDL
+ [../AOSP_cfg/SettingsProvider_intro.md](../AOSP_cfg/SettingsProvider_intro.md): the system's settings provider
+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md)

## Reference

+ [Create a content provider](https://developer.android.com/guide/topics/providers/content-provider-creating)
+ [Content provider basics](https://developer.android.com/guide/topics/providers/content-provider-basics)
+ [`<provider>` element](https://developer.android.com/guide/topics/manifest/provider-element)
+ [Package visibility: declaring needs](https://developer.android.com/training/package-visibility/declaring)
+ [Set up file sharing (`FileProvider`)](https://developer.android.com/training/secure-file-sharing/setup-sharing)
