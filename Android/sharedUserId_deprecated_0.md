# sharedUserId is deprecated

## Why sharedUserId is Deprecated

The android:`sharedUserId` attribute in the Android Manifest -  
which allows two or more apps signed with the same certificate to share a Linux user ID and access each other's data -  
was officially deprecated in API level 29 (Android 10) and is strongly discouraged.

## Key Reasons for Deprecation

1. Non-Deterministic Package Manager Behavior:  
   The Android package manager relies on complex ordering and parsing rules when apps share a UID.  
   If apps are installed or updated in a specific sequence, it can lead to erratic behavior, security context mismatches, and data access crashes.   
2. Security Vulnerabilities:  
   Sharing a Linux user ID means apps essentially run under the same security profile.  
   If one app in the shared group is compromised,  
   the attacker instantly gains access to the private data, internal storage, and databases of all other apps sharing that UID.
3. Incompatibility with Modern Features:  
   Modern Android features (such as App Sandbox improvements, Google Play Instant apps, and seamless package management optimization)  
   cannot handle shared UIDs securely or efficiently.

## The Migration Challenge

Removing `sharedUserId` from an existing application has traditionally been a nightmare.  
If you simply delete `android:sharedUserId` from your manifest and push an update, the Android system treats the app as changing its identity.  
The package manager will block the update with an installation error (**INSTALL_FAILED_SHARED_USER_INCOMPATIBLE**)  
because the app's sandboxed data directory permissions on the device's file system no longer match its new signature configuration,  
which would cause the app to lose access to its data or crash.

## The New Ways to Handle It

Depending on whether you are managing an existing legacy app or building a new app,  
Android provides specific approaches to move away from shared user IDs.

### 1. For Existing Apps: Using android:sharedUserMaxSdkVersion

If you have an existing app that already uses `sharedUserId` and you want to stop using it for new installations  
while keeping existing users safe, Android 13 (API level 33) introduced a safety valve attribute:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    android:sharedUserId="com.example.shared"
    android:sharedUserMaxSdkVersion="32">
    <!-- ... -->
</manifest>
```

+ How it works: For users running Android 13 (API 33) or higher who install your app for the first time,  
  Android will completely ignore the `sharedUserId` attribute. They will get a normal, isolated unique UID.
+ For legacy users who already had the app installed on Android 12 or lower,  
  the shared user ID behavior is preserved so their local data isn't wiped out or locked away.

### 2. Alternative Modern IPC Solutions (How to share data now)

If your apps need to communicate or exchange data securely without relying on a shared UID,  
you should migrate to standard Inter-Process Communication (IPC) mechanisms:

+ Content Providers (**ContentProvider**):  
  The recommended way to securely share structured data (like SQLite databases or files) between your own apps or with third-party apps.  
  You can configure read/write permissions or use per-uri permissions (`android:grantUriPermissions`) to control precisely what data another app can see.
+ **Bound Services/ AIDL** (Android Interface Definition Language):  
  If apps need to execute tasks or invoke methods across process boundaries,  
  implement an explicit bound service or use AIDL to define a formal, safe API contract between the applications.
+ Intents and Broadcasts:  
  For passing transient data, notifications, or triggering actions between application packages safely using explicit intents.

## android:protectionLevel="signature"

When using modern IPC alternatives (like **Content Providers** or **Bound Services**) with a signature-level permission  
(`android:protectionLevel="signature"`), there is no special or separate "new" type of keystore required.

Instead, it relies entirely on the standard **release or debug keystore** you already use to sign your Android apps.

### How It Works

+ The Same Certificate: When you set `android:protectionLevel="signature"`,  
  the Android operating system checks the cryptographic signature of both apps at the time of installation.
+ Match Verification: If App A (the provider/service) and App B (the consumer/client) are signed using the exact same private key/certificate file from your keystore,  
  Android automatically trusts them and grants access.

### Practical Scenarios

+ Local Development (Debug Keystore):  
  When you run both apps locally from Android Studio, they are automatically signed with your computer's default **debug keystore** (debug.keystore).  
  Because they share that debug key, the signature permission works seamlessly out of the box.
+ Production/ Google Play (Release Keystore):  
  When you publish your apps to users, both App A and App B must be signed with your production **release keystore** (.jks or .keystore).  
  + Note on Play App Signing: If you use Google Play App Signing, Google re-signs your apps on their servers.  
    As long as both apps are part of the same Google Play Console developer account and use the same signing configuration,  
    Google ensures they share the correct signing certificate roots so that signature-level permissions continue to validate successfully.
