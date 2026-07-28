# android keystore

[keystore](https://developer.android.com/privacy-and-security/keystore)  

The Android Keystore system lets you **store cryptographic keys in a container** to make them more difficult to extract from the device.  
Once keys are in the keystore, you can use them for cryptographic operations, with the key material remaining non-exportable.  
Also, the keystore system lets you **restrict when and how keys can be used**,  
such as requiring user authentication for key use or restricting keys to use only in certain cryptographic modes.  

**Android Keystore System** provides 3 main functions.

1. generate the keys randomly.
2. limit the usage of the keys (encrypt, decrypt, varify, ...)
3. store the keys safely.

Usually data is put in these places: **SharedPreferences, SQLite, Internal Storage**  

~~The keystore system is used by the KeyChain API, introduced in Android 4.0 (API level 14),~~  
as well as **the Android Keystore provider feature, introduced in Android 4.3 (API level 18)**.  

The Android Keystore system protects key material from unauthorized use in 2 ways.  

1. it reduces the risk of unauthorized use of key material from outside the Android device  
   by preventing the extraction of the key material from application processes and from the Android device as a whole.  
2. the keystore system reduces the risk of unauthorized use of key material within the Android device  
   by making apps specify the authorized uses of their keys and then enforcing those restrictions outside of the apps' processes.

## Hardware-backed Keystore

[keystore security](https://source.android.com/docs/security/features/keystore)

## Android Compatibility Definition Document

[CDD](https://source.android.com/docs/compatibility/cdd)

**MUST** have hardware backed implementations of RSA, AES, ECDSA and HMAC cryptographic algorithms  
and MD5, SHA1, SHA-2 Family hash functions to properly support the Android Keystore system's supported algorithms.

## EncryptedSharedPreferences
