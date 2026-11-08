# Android Keystore system

The **Android Keystore system** lets an app create and use cryptographic keys that **can't be extracted** from the device.
The app gets a handle to the key, not the key bytes. Operations run in the keystore service, or in secure hardware when the device has it.

This is not the same thing as a keystore **file** (`.jks` / `.p12`) used to sign APKs on a build machine.
For those, see [keytool_cmds.md](keytool_cmds.md) and [sign_apk.md](sign_apk.md).

## 1. What it provides

+ **Non-extractable keys**: key material never enters the app process. With hardware backing, it never leaves the secure hardware in plain form.
+ **Usage restrictions**, set when the key is created and enforced outside the app:
  purposes (encrypt, sign, ...), algorithms and modes, validity period, "user must have authenticated within N seconds",
  "only while the device is unlocked".
+ **Key attestation** (Android 7.0+): a certificate chain that proves to a server that a key lives in secure hardware on a genuine device.

APIs:

| API | Since | Use |
| --- | --- | --- |
| `KeyChain` | Android 4.0 (API 14) | System-wide credentials (for example client certificates installed by the user or an admin) that apps request with user consent |
| `AndroidKeyStore` JCA provider | Android 4.3 (API 18) | App-private keys through the standard `KeyStore`, `KeyGenerator`, `KeyPairGenerator`, and `Cipher` / `Signature` classes |
| `KeyGenParameterSpec` | Android 6.0 (API 23) | Describes a new key and its restrictions |

## 2. Where keys live

```text
app (AndroidKeyStore provider) --Binder--> keystore2 daemon --> KeyMint HAL (AIDL) --> KeyMint TA in the TEE (e.g. Trusty)
                                                                                 \--> StrongBox KeyMint (secure element, optional)
```

+ The keystore daemon (`keystore2` since Android 12, `keystore` before) stores only **encrypted key blobs**,
  which only the KeyMint trusted app (TA) can use.
+ **KeyMint** (Android 12) replaced the **Keymaster** HAL.
+ **StrongBox** (Android 9+, optional): a separate secure element. Request it with `setIsStrongBoxBacked(true)`.
  If StrongBox doesn't support the algorithm, you get a `StrongBoxUnavailableException`; retry without it.
+ Check where a key ended up with `KeyInfo.getSecurityLevel()` (API 31+), or `isInsideSecureHardware()` on older releases.
+ CDD §9.11: a device with a **secure lock screen** must back the keystore with an isolated execution environment (TEE),
  and implement RSA, AES, ECDSA, ECDH (with KeyMint), 3DES, HMAC, MD5, SHA-1, and SHA-2 there.
  Every device must allow at least 8,192 keys.

## 3. Example: AES-GCM key for app data

```kotlin
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private const val ALIAS = "app_data_key"

fun getOrCreateKey(): SecretKey {
    val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }

    val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
    generator.init(
        KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
    )
    return generator.generateKey()
}

fun encrypt(plain: ByteArray): Pair<ByteArray, ByteArray> {
    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())   // the keystore picks a random IV
    return cipher.iv to cipher.doFinal(plain)             // store the IV next to the ciphertext
}

fun decrypt(iv: ByteArray, data: ByteArray): ByteArray {
    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
    return cipher.doFinal(data)
}
```

The encrypted bytes can go anywhere: a file, SQLite, DataStore. Only the key stays in the keystore.

+ Keys are deleted when the app is uninstalled, and they aren't part of backups.
  Data encrypted with them can't be restored on another device.
+ `EncryptedSharedPreferences` / `EncryptedFile` (`androidx.security:security-crypto`) wrapped this pattern.
  The library **deprecated all its APIs in 2025** in favour of the platform APIs and direct use of the Android Keystore,
  so new code should use the pattern above (or a library such as Tink).

## Related notes

+ [sign_apk.md](sign_apk.md), [keytool_cmds.md](keytool_cmds.md): build-time keystore files, a different topic
+ [../IPC/Binder_intro.md](../IPC/Binder_intro.md): how the app reaches the keystore daemon

## Reference

+ [Android Keystore system](https://developer.android.com/privacy-and-security/keystore)
+ [Hardware-backed Keystore (AOSP)](https://source.android.com/docs/security/features/keystore)
+ [Key and ID attestation (AOSP)](https://source.android.com/docs/security/features/keystore/attestation)
+ [AndroidX Security release notes (security-crypto deprecation)](https://developer.android.com/jetpack/androidx/releases/security)
+ [Android Compatibility Definition Document](https://source.android.com/docs/compatibility/cdd)
