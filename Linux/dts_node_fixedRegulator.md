# device tree node: Fixed Regulator

To configure a power on/off pin for a peripheral chip in a Device Tree (.dtsi),  
you typically use either a **Fixed Regulator** (best practice for power rails)  
or a Direct GPIO Enable property (if the driver natively accepts an enable line).

## 1.Define a Fixed Regulator

+ If the pin controls a dedicated power rail (such as VCC or VDD) for the peripheral, define a fixed regulator node in your .dtsi:
+ Verification: Check that the regulator node compiles correctly and appears under /sys/class/regulator/ after booting the device.

```ini
/ {
    vcc_periph: fixed-regulator-periph {
        compatible = "regulator-fixed";
        regulator-name = "vcc_periph_en";
        regulator-min-microvolt = <3300000>; // Set voltage (e.g., 3.3V)
        regulator-max-microvolt = <3300000>;
        gpio = <&gpio1 10 GPIO_ACTIVE_HIGH>; // Replace with your actual GPIO pin
		startup-delay-us = <1000>;      /* Delay when turning ON */
		off-on-delay-us = <2000>;       /* Cooldown / delay required after turning OFF */
        enable-active-high;
        regulator-boot-on; // Optional: keeps power on during boot
    };
};
```

## 2.Bind the Regulator to the Peripheral Node

+ Reference the newly created regulator inside your peripheral device node so the kernel driver automatically turns it on when `probed`:
+ Verification: Run `adb shell dmesg | grep regulator` to confirm the driver successfully requests and enables the supply rail.

```ini
&periph_device {
    vcc-supply = <&vcc_periph>;
};
```

### Alternative: Use enable-gpios Property

If the peripheral driver natively handles an enable/shutdown pin directly through a GPIO rather than the **regulator framework**,  
add the property directly inside the peripheral node:

```ini
&periph_device {
    enable-gpios = <&gpio1 10 GPIO_ACTIVE_HIGH>;
};
```

Verification: Run `adb shell cat /sys/kernel/debug/gpio` to verify the assigned GPIO pin is configured as an output and set to the correct active state.

### Hardware Safety Warning

Always verify the hardware schematic for active-high versus active-low polarity  
and correct voltage requirements before powering on the chip to prevent permanent hardware damage.

## Android control

Standard third-party Android apps **cannot** directly access or control hardware pins due to Android's strict security sandbox and SELinux policies.  
To enable or disable a peripheral power pin from an app, you must use a **system app**  
(signed with platform keys or running with system privileges) that interacts with a designated sysfs node, regulator, or custom system property.

### 1. Grant Permissions to the Control Node

Update your device's `init.rc` script so that your system app has permission to write to the hardware control node  
(for example, a regulator state or custom sysfs entry):

```bash
chown system system /sys/class/regulator/regulator.X/state
chmod 0664 /sys/class/regulator/regulator.X/state
```

+ Verification: Run `adb shell ls -l /sys/class/regulator/regulator.X/state` to confirm the owner displays as system with 0664 permissions.

### 2. Add SELinux Policy Permissions

+ Update your device's SELinux policy (such as `platform_app.te` or a custom policy file)  
  to allow your app domain to write to the hardware node without triggering security denials.  
  `allow platform_app sysfs_regulator:file rw_file_perms;`
+ Verification: Run `adb logcat | grep avc` while operating the app to verify there are no permission denial errors.

### 3. Implement File Write Logic in the App

Inside your system app code, write a routine to update the file state dynamically  
(e.g., writing "enabled" or "disabled", or "1" and "0").

```java
try {
    File file = new File("/sys/class/regulator/regulator.X/state");
    FileWriter writer = new FileWriter(file);
    writer.write("enabled");    // Use "disabled" to turn off
    delay(100)                  // Wait for your specified delay (e.g., 100 milliseconds)
    writer.close();
} catch (IOException e) {
    e.printStackTrace();
}
```

Verification: Check the device state by running `adb shell cat /sys/class/regulator/regulator.X/state` immediately after triggering the app action.

## the label property

In a device tree node, the label property provides a descriptive string name  
for a hardware component or resource (such as a power rail, LED, or switch).

+ Purpose: It helps identify the device or regulator in system logs, debugging outputs, or user-space interfaces (like /sys/class/regulator/).
+ Distinction: It is different from the node's identifier label (the name before the colon, like vdd12_sw_osm:),  
  which is used internally within the device tree for cross-referencing nodes.
