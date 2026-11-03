# HAL vs sysfs nodes

Writing to `/sys/class/...` (sysfs) and calling a HAL are **2 different levels of abstraction**, not 2 alternatives.

+ **sysfs** is a *kernel → user-space* interface: the kernel exposes driver attributes as files.
+ A **HAL** is a *user-space → framework* interface: a standard API, and its implementation often uses sysfs internally.

## 1. What sysfs is

**sysfs** is a virtual (RAM-only) filesystem mounted at `/sys`.
The kernel uses it to export its device model: devices, drivers, buses, and classes.
Each **sysfs node** (attribute) is a small file.
Reading it, or writing it, calls the driver's `show()` or `store()` callback **synchronously**.

```shell
cat  /sys/class/leds/red_led/max_brightness
echo 255 > /sys/class/leds/red_led/brightness       # store() -> driver sets the LED
```

+ Any language works (C, C++, shell): `open` / `read` / `write` / `close`.
+ Rule of thumb: one value per file, in text format.
+ `/sys/class/<class>/<name>` entries are **symlinks** to the real device path under `/sys/devices/...`.

## 2. What a HAL is

A HAL is a **standard API contract** that the Android framework calls.
The vendor implements it in user space.

Legacy `libhardware` Lights HAL (in-process C API, up to Android 7):

```c
/* the light ID is chosen when the device is opened */
light_device_t* dev;
module->methods->open(module, LIGHT_ID_BACKLIGHT, (hw_device_t**)&dev);
dev->set_light(dev, &state);              /* struct light_state_t: color, flashMode, ... */
```

Current AIDL Lights HAL (`android.hardware.light.ILights`, called over Binder):

```java
interface ILights {
    void setLightState(in int id, in HwLightState state);
    HwLight[] getLights();
}
```

## 3. Comparison

| | sysfs node (`/sys/...`) | HAL |
| --- | --- | --- |
| What it is | Kernel-to-user-space interface (files) | Framework-to-vendor API (functions/methods) |
| Lives in | Kernel (exposed as files) | User space (a vendor process on modern Android) |
| Format | Text read/write, one value per file | Typed calls (`int`, structs, parcelables) |
| Portability | **Low**: paths and names depend on the driver, kernel version, and board | **High**: the framework sees the same interface on every device |
| Access control | DAC (owner/mode) **and SELinux** labels | Binder + SELinux (`hal_client_domain`), and the HAL's own checks |

On Android, sysfs access needs both of these:

+ **DAC**: set the owner and mode at boot with `ueventd.rc`.
  sysfs attributes go back to their defaults on every boot, so a one-time `chmod` doesn't persist.

  ```text
  # ueventd.rc: <sysfs path> <attribute> <mode> <uid> <gid>
  /sys/class/leds/red_led   brightness   0664   system   system
  ```

+ **SELinux**: label the files with `genfscon` (or `genfs_contexts`), then allow the HAL's domain to use them.

  ```text
  # genfs_contexts (path is the real /sys/devices/... path)
  genfscon sysfs /devices/platform/leds/leds/red_led   u:object_r:sysfs_leds:s0

  # hal_light_default.te
  allow hal_light_default sysfs_leds:dir search;
  allow hal_light_default sysfs_leds:file rw_file_perms;
  ```

## 4. How they work together

A real Lights HAL implementation is often just a thin wrapper around sysfs:

```text
system_server (LightsService)
    |  Binder: ILights.setLightState(id, state)
    v
Lights HAL (vendor process)
    |  writes "255" to /sys/class/leds/red_led/brightness
    v
LED class driver: brightness_set()  ->  GPIO / PWM / PMIC register
```

1. The framework calls `setLightState()` over Binder.
2. The HAL maps the light `id` to a sysfs path and converts the ARGB color to a brightness value.
3. The HAL writes the value to the sysfs file.
4. The kernel calls the LED driver's `store()` → `brightness_set()`, and the driver programs the hardware.

The AOSP *default* Lights HAL (`hardware/interfaces/light/aidl/default`) is only a stub that logs.
Device HALs (under `device/<vendor>/...` or `vendor/...`) contain the real sysfs code.

## 5. When do you need a HAL and not plain sysfs?

+ **Need a HAL** when the *framework* or other partitions call into vendor code, or when apps are involved.
  Example: the framework's LightsService must work on any device.
+ **Plain sysfs is fine** inside a single vendor daemon or script that already owns the hardware.
  Example: a vendor init script that sets an LED trigger at boot.

## 6. Analogy

+ **sysfs** is the wiring behind the wall: it works, but it's raw and different in every house.
+ The **HAL** is the standard wall switch: everyone uses the same "on/off", and the electrician (the vendor) wires it to whatever is behind the wall.

## Related notes

+ [HAL_intro.md](HAL_intro.md), [hw_control_sysfs.md](hw_control_sysfs.md)
+ [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md): an AIDL service that writes LED sysfs nodes
+ [Led_control.md](Led_control.md)

## Reference

+ [sysfs (kernel docs)](https://docs.kernel.org/filesystems/sysfs.html)
+ [LED class (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
+ [Lights AIDL interface (hardware/interfaces/light/aidl)](https://android.googlesource.com/platform/hardware/interfaces/+/refs/heads/main/light/aidl/)
