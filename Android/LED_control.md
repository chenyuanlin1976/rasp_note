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

## control GPIO output for Led

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

#### when an exit code of 1

An **exit code** of 1 (often accompanied by a *write error: Invalid argument* message) means  
the kernel explicitly rejected the number 80.  
This happens for a few common reasons on Rockchip systems:  

##### Why the Export Fails

+ **Incorrect Global Pin Offset**: Unlike older Linux kernels where GPIOs started sequentially at 0,  
  modern RK3566 kernels often register GPIO banks with specific dynamic base offsets  
  (e.g., chips starting at 32, 64, or 128 depending on the device tree).  
  A hardcoded number like 80 may fall into a gap or point to a non-existent line.
+ **Pin Already Claimed**: If the pin is already reserved or in use by a kernel driver  
  (such as for Wi-Fi, an LED, or a regulator), the kernel will block userspace export.
  + Confirm Which Driver Holds the Pin: `adb shell cat /sys/kernel/debug/gpio`
+ **Pin Function MUX Conflict**: The pin might currently be assigned to a peripheral function (like UART, SPI, or PWM) rather than pure GPIO mode.

#### Programmatic Kotlin Example (Requires Root/File access permissions)

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

## **sysfs** GPIO interface

The `sysfs` GPIO interface is a legacy Linux mechanism (/sys/class/gpio)  
that allowed userspace applications to control hardware pins using standard file operations  
(such as *writing pin numbers to an export file to create control nodes*).

### Why it fails on modern RK3566 systems

+ Kernel Deprecation: The Linux kernel community officially deprecated the `sysfs` GPIO interface years ago  
  due to security flaws, race conditions, and architectural limits.
+ Disabled in Defconfig: Most modern Rockchip Android SDKs (running kernel versions 4.19, 5.10, or newer on the RK3566)  
  disable `CONFIG_GPIO_SYSFS` entirely in the kernel configuration.  
  When this option is turned off, the `/sys/class/gpio` directory or its export file does not exist,  
  causing shell commands to fail with "No such file or directory" or permission errors.
+ BUT `zcat /proc/config.gz | grep CONFIG_GPIO_SYSFS`, result is `CONFIG_GPIO_SYSFS=y`.
  + If it returns `CONFIG_GPIO_SYSFS=y`: The feature is enabled,  
    meaning your previous command failure was likely due to permissions or missing root access.
  + If it returns nothing (or outputs an error that the file doesn't exist):  
    Your kernel has CONFIG_PROC_FS or IKCONFIG disabled, so you must check via Method 2.

#### if Pin Already Claimed

`adb shell cat /sys/kernel/debug/gpio`

```bash
gpiochip0: GPIOs 0-31, parent: platform/fdd60000.gpio, gpio0:
 gpio-0   (                    |watchdog            ) out hi 
 gpio-5   (                    |vcc5v0-otg-regulator) out lo 
 gpio-6   (                    |vcc5v0-host-regulato) out hi 
 gpio-8   (                    |irblaster           ) out lo 
 gpio-13  (                    |GTP_INT_IRQ         ) in  hi 
 gpio-14  (                    |GTP_RST_PORT        ) out hi 
 gpio-16  (                    |bt_default_wake     ) out lo 
 gpio-18  (                    |gpio-regulator      ) out lo 
 gpio-21  (                    |vcc3v3-lcd1-n       ) out lo 
 gpio-23  (                    |vcc3v3-lcd0-n       ) out lo 
 gpio-28  (                    |wifi-en             ) out hi 

gpiochip1: GPIOs 32-63, parent: platform/fe740000.gpio, gpio1:
 gpio-37  (                    |work                ) out hi 
 gpio-38  (                    |i2s-lrck            ) in  hi 

gpiochip2: GPIOs 64-95, parent: platform/fe750000.gpio, gpio2:
 gpio-77  (                    |bt_default_rts      ) out hi 
 gpio-79  (                    |bt_default_reset    ) out lo 
 gpio-80  (                    |bt_default_wake_host) in  lo IRQ 

gpiochip3: GPIOs 96-127, parent: platform/fe760000.gpio, gpio3:
 gpio-119 (                    |reset               ) out hi ACTIVE LOW
 gpio-122 (                    |dvb-en              ) out hi 
 gpio-123 (                    |dvb-rf              ) out hi 

gpiochip4: GPIOs 128-159, parent: platform/fe770000.gpio, gpio4:
 gpio-146 (                    |sysfs               ) out hi 
 gpio-148 (                    |ir-blaster-pw       ) out hi
```

##### check source code: rk3566-evb2-lp4x-v10-390k.dtsi

```bash
&leds {
   dvb_rf: dvb-rf {
      gpios = <&gpio3 RK_PD3 GPIO_ACTIVE_HIGH>;
      default-state = "on";
   };

   ir_blaster_pw: ir-blaster-pw {
      gpios = <&gpio4 RK_PC4 GPIO_ACTIVE_HIGH>;
      default-state = "on";
   };
};
```

+ LED1_G_OSM: `adb shell "echo 0 > /sys/class/leds/dvb-rf/brightness"`
+ LED1_G_OSM: `adb shell "echo 1 > /sys/class/leds/dvb-rf/brightness"`
+ LED1_B_OSM: `adb shell "echo 0 > /sys/class/leds/ir-blaster-pw/brightness"`
+ LED1_B_OSM: `adb shell "echo 1 > /sys/class/leds/ir-blaster-pw/brightness"`

### The Modern Replacement

Instead of sysfs, modern Linux and Android environments use the GPIO character device interface,  
which utilizes `/dev/gpiochip*` nodes.

+ Tooling: Interaction is handled via **libgpiod** utilities (`gpiodetect`, `gpiofind`, `gpioget`, `gpioset`).
+ Programming: Software developers use the libgpiod API instead of opening file streams to `/sys/class/gpio`.

## `libgpiod` Utilities

+ `gpiodetect`: Lists all available GPIO controller chips (gpiochip0, gpiochip1, etc.)  
  present on the RK3566 system along with their total number of lines.
+ `gpioinfo`: Dumps detailed information for every pin on a specified chip, including current direction, state,  
  and whether a pin is claimed by a driver.  
+ `gpiofind`: Looks up a pin name (e.g., matching a schematic label like GPIO3_C4) and returns its exact chip name and line offset.  
+ `gpioget`: Reads the current logic level (0 or 1) of a specified GPIO line.  
+ `gpioset`: Drives a GPIO line high (1) or low (0). Unlike the old sysfs interface where you wrote to export and direction files separately,  
  gpioset configures and holds the line state immediately.  
+ `gpiomon`: Monitors a pin for hardware edge events (rising or falling voltage transitions).

### Replacing the Sysfs Command

To replicate `echo 80 > /sys/class/gpio/export` using the modern character device framework, you no longer need to "export" a global index.  
Instead, target the specific *GPIO controller chip* and *line offset*:

+ Calculate the chip and offset: On the RK3566, GPIOs are typically grouped into banks of 32 lines  
  (gpiochip0 for GPIO0, gpiochip1 for GPIO1, etc.).  
  A global number like 80 usually maps to gpiochip2 (since 32 x 2 = 64, meaning line 80 is offset 16 on gpiochip2).
+ Drive the pin: Use gpioset directly to configure and set the line:  
  `adb shell gpioset gpiochip2 16=1`

### Availability on Android

Most production Android builds for the RK3566 do **not** include `libgpiod` command-line utilities out of the box.  
If running gpiodetect via adb shell returns "not found," you will need to cross-compile the libgpiod tools for Android (ARM64)  
or extract them from a vendor-provided debug toolset and push them to `/system/bin/` or `/data/local/tmp/`.
