# LED control

Android provides standard, public APIs to control device lights.

## NotificationManager

Historically, hardware notification LEDs on the front of phones were controlled implicitly via the **NotificationManager**.

+ How it works: You do not turn the LED on directly;  
  instead, you post a notification and tell Android you want it to blink.  
  The OS handles it when the screen turns off.

```kotlin
val channel = NotificationChannel("id", "Name", NotificationManager.IMPORTANCE_DEFAULT).apply {
    enableLights(true)
    lightColor = Color.RED // Request a Red LED blink
}
```

+ Hardware Note: Most modern Android phones have removed the front physical notification LED in favor of "Always On Displays" (AOD).

## For System & Input Device Lights (Android 12+)

Starting in Android 12 (API 31), Google introduced a formal framework to directly control hardware lights via the LightsManager.  
This can target microphone mute LEDs, keyboard backlights, or attached game controller player-ID LEDs

+ Permission needed: `<uses-permission android:name="android.permission.CONTROL_DEVICE_LIGHTS" />`
+ Kotlin Code Example:

```kotlin
val lightsManager = getSystemService(LightsManager::class.java)
val targetLights = lightsManager.lights // List of available hardware lights

if (targetLights.isNotEmpty()) {
    val session = lightsManager.openSession()
    val firstLight = targetLights[0]
    
    // Construct a request to turn it on with a specific color/brightness
    val request = LightsRequest.Builder()
        .setLight(firstLight, LightState.Builder().setColor(Color.GREEN).build())
        .build()
        
    session.requestLights(request) // Applies the light state
}
```

+ Security Note: While LightsManager is a standard API, CONTROL_DEVICE_LIGHTS is a signature/protected permission.  
  Normal apps downloaded from the Play Store cannot use it to control internal phone chassis components;  
  it is primarily intended for system apps, device manufacturers, or specialized hardware accessories

## LED, GPIO

Because vanilla Android is designed for consumer smartphones, it does not expect apps to directly toggle CPU pins.  
To control an RGB LED on a custom Android board (like a Raspberry Pi, Rockchip, or Allwinner embedded board),  
you have to interact with the underlying Linux Kernel GPIO Subsystem.

### Path 1: The Standard Linux Sysfs Interface (Most Common)

If you have Root privileges or if the hardware manufacturer opened the file permissions,  
you can write directly to the Linux `/sys/class/gpio` file nodes from Java/Kotlin or NDK C++  
using shell execution or basic file stream writing.

An RGB LED requires 3 GPIO Pins (one each for Red, Green, and Blue).

```bash
# 1. Export the 3 pins to user-space (Replace 101, 102, 103 with your actual chip pin numbers)
echo 101 > /sys/class/gpio/export
echo 102 > /sys/class/gpio/export
echo 103 > /sys/class/gpio/export

# 2. Configure them as output channels
echo out > /sys/class/gpio/gpio101/direction
echo out > /sys/class/gpio/gpio102/direction
echo out > /sys/class/gpio/gpio103/direction

# 3. Mix colors by pulling pins HIGH (1) or LOW (0)
echo 1 > /sys/class/gpio/gpio101/value  # Red ON
echo 0 > /sys/class/gpio/gpio102/value  # Green OFF
echo 1 > /sys/class/gpio/gpio103/value  # Blue ON (Results in Purple/Magenta)
```

+ Programmatic Kotlin Example (Requires Root/File access permissions)

```kotlin
import java.io.FileOutputStream

fun setLedColor(rPin: Int, gPin: Int, bPin: Int, red: Boolean, green: Boolean, blue: Boolean) {
    try {
        // Write the state directly to the underlying Linux node
        FileOutputStream("/sys/class/gpio/gpio$rPin/value").use { it.write(if (red) b(49) else b(48)) }
        FileOutputStream("/sys/class/gpio/gpio$gPin/value").use { it.write(if (green) b(49) else b(48)) }
        FileOutputStream("/sys/class/gpio/gpio$bPin/value").use { it.write(if (blue) b(49) else b(48)) }
    } catch (e: Exception) {
        e.printStackTrace()
    }
}
private fun b(ascii: Int): ByteArray = byteArrayOf(ascii.toByte())
```

+ Limitation: Pure GPIO is binary (ON/OFF).  
  Using this approach limits the RGB LED to just 7 block colors (Red, Green, Blue, Yellow, Cyan, Magenta, White) and Off.  
  You cannot achieve subtle shades or smoothly dim the colors without PWM (Pulse Width Modulation)

### Path 2: Using standard PWM nodes (For full 16-Million Color blending)

To get exact color blending (like standard hex codes FF5733),  
the hardware pins must pulse using PWM (Pulse Width Modulation) instead of simple GPIO.  
Look to see if your board exposes the pins through the Linux PWM driver instead  
`/sys/class/pwm/pwmchip0/`

### Path 3: The Custom Hardware Vendor HAL (The Commercial Way)

If you are developing a commercial hardware product, the standard design pattern is:

1. Bind the 3 GPIO pins to a custom Linux leds-gpio kernel driver inside the board's device tree (.dts).
2. This creates clean system properties like `/sys/class/leds/red/brightness`.
3. Write a small native Android HAL (Hardware Abstract Layer) service in C++.
4. Expose that HAL service to your app layer using an AIDL/HIDL interface or a custom System Service.
