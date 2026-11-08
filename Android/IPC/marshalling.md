# marshalling, unmarshalling

**Marshalling** (serialization) and **unmarshalling** (deserialization) refer to the process of  
*converting an in-memory object into a byte stream (or Parcel)*  
so it can be passed between components (like Activities or Services) or IPC boundaries,  
and then reconstructing it back into an object.  

Android provides a specialized mechanism called **Parcelable** specifically optimized  
for high-performance marshalling, far outperforming standard Java Serializable.  

## Modern Implementation (Kotlin @Parcelize)

### Instead of writing boilerplate read/write code manually

modern Android development uses the Kotlin plugin to handle marshalling automatically.

```kotlin
import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class User(
    val id: Int,
    val name: String
) : Parcelable
```

+ Passing the Marshallled Object via Intent:
  Android automatically marshalls Parcelable objects into a Bundle when passing them between components.

```kotlin
// Marshalling implicitly handled when putting into an Intent
val user = User(1, "Alice")
val intent = Intent(this, TargetActivity::class.java).apply {
    putExtra("EXTRA_USER", user)
}
startActivity(intent)
```

### Unmarshalling in the Receiving Activity

```kotlin
// Unmarshalling explicitly or implicitly via property extensions
val user = intent.getParcelableExtra("EXTRA_USER", User::class.java)
```

## Low-Level Byte Marshalling (Parcel to byte[])

If you need to manually flatten a Parcelable object into raw bytes  
(e.g., for caching or custom socket transmission), you can use Android's native Parcel class:

```kotlin
import android.os.Parcel
import android.os.Parcelable

object ParcelableUtils {

    // Marshall: Parcelable -> byte[]
    fun marshall(parcelable: Parcelable): ByteArray {
        val parcel = Parcel.obtain()
        parcelable.writeToParcel(parcel, 0)
        val bytes = parcel.marshall()
        parcel.recycle()
        return bytes
    }

    // Unmarshall: byte[] -> Parcelable
    fun <T> unmarshall(bytes: ByteArray, creator: Parcelable.Creator<T>): T {
        val parcel = Parcel.obtain()
        parcel.unmarshall(bytes, 0, bytes.size)
        parcel.setDataPosition(0)
        val result = creator.createFromParcel(parcel)
        parcel.recycle()
        return result
    }
}
```

**CAUTION**: Android's Parcel data structure is **not** version-safe and is designed for short-term IPC transport.  
**Never** use Parcel marshalling to save objects to disk (like a database or file) or transmit them over a network,  
because system updates can change how data is unmarshalled.  
Use `JSON` (via libraries like Kotlinx Serialization or Gson) or standard Java Serializable for long-term storage.
