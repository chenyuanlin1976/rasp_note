# HAL introduction

## 1. What a HAL is

**HAL = Hardware Abstraction Layer.**
A HAL is a layer of software that sits between the hardware and the software above it (the OS, a framework, or an application).
It hides the **manufacturer-specific** details of a device behind a **standardized interface**.

+ **Upper side (the users)** calls a generic operation, such as "read the accelerometer" or "turn the torch on".
+ **Lower side (the vendor implementation)** turns that request into the register accesses,
  kernel driver calls, or firmware commands that *this particular chip* needs.

The goal is **portability**: the same upper-layer code runs on many different chips, and only the HAL implementation changes.

## 2. The word "HAL" means different things in different places

| Where | What "HAL" is | Runs as | Example |
| --- | --- | --- | --- |
| **Android** | A vendor implementation behind a **stable interface** (AIDL; HIDL/libhardware on older devices) | Usually a separate **vendor process**, called over Binder | Camera provider HAL, Lights HAL, Audio HAL |
| **Microcontrollers** | A vendor C library that wraps the chip's registers | A library compiled into the firmware; plain function calls | STM32 HAL `HAL_GPIO_WritePin()`: see [HAL_STM32_example.md](HAL_STM32_example.md) |
| **Desktop OS kernels** | The lowest kernel layer that hides motherboard differences | Part of the kernel | Windows `hal.dll` (interrupt controllers, timers, ACPI) |

Linux has **no single "HAL" layer**. Hardware is abstracted by **kernel driver subsystems**
(gpiolib, LED class, IIO, V4L2, ...), and hardware is described through **device tree** (ARM) or **ACPI** (x86).
An Android HAL is a **user-space** layer on top of those drivers.

## 3. Where the HAL sits in the Android stack

| Layer | What it does | How the layer above talks to it | Example |
| --- | --- | --- | --- |
| App | UI and business logic (Java/Kotlin) | n/a | Flashlight app |
| Framework / system services | Public Android APIs, policy, arbitration between apps | **Binder** (AIDL) from the app process | `CameraManager` → `cameraserver` |
| **HAL** | Vendor-specific implementation of a standard interface | **Binder** (stable AIDL / HIDL) | Camera provider HAL in `/vendor/bin/hw/` |
| Kernel driver | Owns the hardware, exposes it to user space | System calls: `ioctl()`, sysfs files, char devices | V4L2 flash control, LED class driver |
| Hardware | Chips, pins, registers | Memory-mapped registers, I2C/SPI, ... | Flash LED driver IC |

**JNI is not one of these layers.**
JNI is an *in-process* bridge between Java and native code: a Java class calls a C/C++ function loaded into the **same** process.
Some framework code uses JNI internally, but the boundaries between app, system service, and HAL are crossed with **Binder IPC**.
See [JNI_intro.md](JNI_intro.md) and [libgpiod_HAL.md](libgpiod_HAL.md).

## 4. Example: turning on the flashlight

```text
[ App (Kotlin) ]           CameraManager.setTorchMode(id, true)
       |  Binder (AIDL ICameraService)
       v
[ cameraserver ]           native system service (/system/bin/cameraserver)
       |  Binder (camera provider HAL interface: HIDL @2.x on older devices, AIDL on newer ones)
       v
[ Camera provider HAL ]    vendor process (/vendor/bin/hw/...), written by the SoC/OEM
       |  ioctl() / sysfs
       v
[ Kernel driver ]          V4L2 flash controls or LED class (flash) driver
       |  registers, I2C, GPIO
       v
[ Flash LED hardware ]
```

### Step 1: App

```kotlin
val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager

// Pick a camera that actually has a flash unit (don't hard-code "0")
val torchId = cameraManager.cameraIdList.firstOrNull { id ->
    cameraManager.getCameraCharacteristics(id)
        .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
}
torchId?.let { cameraManager.setTorchMode(it, true) }
```

### Step 2: Framework → `cameraserver` (Binder, not JNI)

`CameraManager` is Java code in the app's process.
It calls the **Binder proxy** of `ICameraService`, and the request runs in the native `cameraserver` process.
`cameraserver` checks permissions and arbitration (for example, whether the camera is busy).
Then `CameraProviderManager` forwards the request to the HAL.

The deprecated `android.hardware.Camera` API went through JNI (`libcamera_client`) inside the app process first,
but even there the step to `cameraserver` was Binder.

### Step 3: `cameraserver` → camera provider HAL

The standard HAL interface (for example `ICameraDevice::setTorchMode()`) is the **contract**.
`cameraserver` does not know whether the device is a Pixel, a Samsung, or a Rockchip board.
The vendor's HAL implementation in its own process turns the call into the commands that its kernel driver needs.

### Step 4: Kernel driver → hardware

The driver programs the flash LED driver IC (over I2C, a GPIO, or a PWM), and the LED turns on.

### Why this architecture matters

+ **Separation of concerns**: Google maintains the framework and `cameraserver` without knowing the vendor hardware.
+ **Vendor flexibility**: the OEM can change the hardware.
  If the new HAL implementation still meets the standard interface, the framework and apps don't change.
+ **Independent updates (Project Treble)**: the framework (system partition) and the HAL (vendor partition)
  are versioned separately, so the OS can be updated without rebuilding vendor code.
+ **Security and stability**: each HAL runs in its **own process and SELinux domain**, with only the privileges it needs.
  A crashing HAL doesn't take down `system_server` or the app, and apps never get direct access to device nodes.

## Related notes

+ [HAL_history.md](HAL_history.md): libhardware → HIDL → AIDL
+ [HAL_sysfsNodes.md](HAL_sysfsNodes.md): how a HAL relates to sysfs
+ [HAL_libgpiod.md](HAL_libgpiod.md): GPIO HAL with libgpiod
+ [HAL_STM32_example.md](HAL_STM32_example.md): what a microcontroller "HAL" does
+ [AIDL_HAL.md](AIDL_HAL.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md): writing an AIDL HAL

## Reference

+ [Hardware abstraction layer (HAL) overview](https://source.android.com/docs/core/architecture/hal)
+ [Camera HAL](https://source.android.com/docs/core/camera)
