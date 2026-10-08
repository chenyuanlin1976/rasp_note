# AIDL intro 3

To allow a 3rd-party Android APK to communicate with a custom AIDL service implemented in AOSP,  
you have to **bridge the security and architectural gap**.  
By default, standard Android applications are sandboxed and CANNOT directly access custom system-level or native binder services  
due to:

+ **SELinux policies** blocking untrusted apps from reaching custom service managers.
+ Hidden API restrictions (preventing direct usage of android.os.ServiceManager in standard apps).
+ Missing client-side interfaces.

Here is the step-by-step guide on what you need to do on both the AOSP side and the 3rd-party APK side.

## Step 1: Choose Your Architecture Pattern

Depending on how you implemented your GPIO service in AOSP,  
choose one of these 2 approaches for the 3rd-party APK:

### Approach A: Bound Service via a System App (Recommended)

Your low-level AOSP daemon/service talks to a persistent System App,  
which in turn exposes a standard Android Bound Service using your AIDL.  
The 3rd-party APK simply binds to this system app using an explicit Intent.

### Approach B: Direct Native/System AIDL Service (Advanced)

Your service is registered directly with **servicemanager** (e.g., via C++ or Java in system_server).  
To let a 3rd-party APK talk to it, you must relax **SELinux policies** and provide a custom SDK wrapper or permission library.

## Step 2: Provide the .aidl File to the 3rd-Party App

Regardless of the approach, the 3rd-party app needs a local copy of your `.aidl` file  
to generate the proper Binder proxy classes during compilation.

1. In your Android Studio project for the 3rd-party APK,  
   create an AIDL directory matching your package structure:  
   `app/src/main/aidl/com/yourcompany/gpio/IGpioService.aidl`
2. Ensure the package name and method signatures inside this .aidl file  
   exactly match the ones defined in your AOSP source code.

## Step 3: Implement the Connection in the 3rd-Party APK

If you are using Approach A (Bound Service), the 3rd-party app connects like any standard remote service:

```kotlin
class GpioControllerClient(private val context: Context) {
    private var gpioService: IGpioService? = null
    private var isBound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            // Cast the binder to your AIDL interface stub
            gpioService = IGpioService.Stub.asInterface(service)
            isBound = true
        }

        override fun onServiceDisconnected(className: ComponentName) {
            gpioService = null
            isBound = false
        }
    }

    fun bindService() {
        val intent = Intent("com.yourcompany.action.CONTROL_GPIO").apply {
            setPackage("com.yourcompany.systemserviceapp") // Package name of the system host app
        }
        context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    fun setGpioPin(pin: Int, high: Boolean) {
        if (isBound) {
            gpioService?.setGpio(pin, high)
        }
    }
}
```

Note: If your app targets Android 11 (API level 30) or higher,  
make sure to add a `<queries>` tag in your app's AndroidManifest.xml so it can discover the system service package:

```xml
<queries>
    <package android:name="com.yourcompany.systemserviceapp" />
</queries>
```

## Step 4: Adjust AOSP Permissions & SELinux (If using Direct Access)

If you chose Approach B (the app talks directly to a **system/native binder service**):

1. Custom Permission: Define a custom signature-level or normal permission in AOSP  
   (`frameworks/base/core/res/AndroidManifest.xml`)  
   and enforce it in your service's onTransact() or using getContext().enforceCallingPermission().
2. SELinux Policies: Modify your device's SELinux policy  
   (e.g., in `device/your_vendor/your_board/sepolicy/untrusted_app.te` or a custom domain policy)  
   to allow untrusted apps to find and call your service:  
   (Without this, the kernel will throw an avc: denied error when the 3rd-party APK tries to invoke the service).

```ini
allow untrusted_app gpio_service:service_manager find;
allow untrusted_app gpio_device:chr_file { read write open ioctl };
```

## another way: provide JAR

you can provide a pre-built JAR (or .aar) file to the 3rd-party app developer  
so they don't have to deal with raw .aidl files or manual stub generation.

However, because AIDL interfaces compile down to standard Java binder proxy classes  
(.stub and .asInterface), you need to package those compiled classes properly into a library.

### How to Create and Provide the JAR/AAR

+ Compile the AIDL into Stubs:  
  In your AOSP or an internal Android Studio library module containing your .aidl file, build the project.  
  Android will automatically generate the Java source file from your .aidl under the `build/generated/source/aidl/` directory.
+ Package as a JAR or AAR:  
  + If your interface only contains pure Java interfaces and parcelables, you can compile them into a standard .jar file.
  + If your wrapper library includes Android context dependencies, resources, or manifest entries, package it as an .aar (Android Archive) instead.
+ Provide Wrapper APIs (Best Practice):  
  Instead of just giving them raw binder stubs, create a clean wrapper class inside your library (e.g., GpioManager)  
  that handles finding the service and calling the binder methods safely under the hood.  
  This shields the 3rd-party developer from dealing with raw IBinder calls.

## Which one to use

Choosing between sharing the raw .aidl file or a pre-compiled .jar/.aar  
depends on how much control you want to give the 3rd-party developer and how tightly you want to manage your API surface.

### When to Give the .aidl File

+ Custom wrapper implementation: The 3rd-party developer prefers to write their own abstraction layer  
  or connection manager around the raw binder interface.
+ Build system flexibility: The developer wants Gradle to automatically generate the Java stub classes directly  
  inside their own Android Studio project build pipeline.
+ Trusted partner ecosystem: You are working closely with an external team and source-level integration is preferred or already established.

### When to Give the .JAR or .AAR File

+ Encapsulation and safety: You want to hide the raw binder mechanics and provide a clean, high-level SDK wrapper  
  (for example, a GpioManager class) so they only call simple methods like setPinState().
+ Version control: You want to prevent API mismatches caused by developers accidentally modifying or using outdated versions of the .aidl file.
+ Bundling extra logic or dependencies: Your client-side implementation requires helper utility classes, error handling,  
  or context management packaged alongside the interface (use an .aar if you need to package Android resources or manifests).
