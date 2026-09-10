# pre-installed APKs

When you compile a custom Android system image (like AOSP),  
pre-installed APKs are placed inside the system partition directories under the `out/` build output folder,  
which are ultimately packed into **system.img** or product.img

## Final Location on the Built Device Image (out/.../system/)

Depending on how the module is defined in the Android build system (via `Android.mk` or `Android.bp`),  
the compiled APK ends up in one of these paths:

+ Standard System Apps: `/system/app/<AppName>/<AppName>.apk`  
  + Used for ordinary pre-installed system applications.
+ Privileged System Apps: `/system/priv-app/<AppName>/<AppName>.apk`  
  + Used for system apps that require signature-level or privileged permissions  
    (e.g., SettingsProvider, SystemUI components).
+ Product Partition Apps: `/product/app/` or `/product/priv-app/`  
  + Used for modern modular builds where OEM apps reside in the dedicated product image.

## How to Include a Pre-Installed APK During Compilation

To add a custom or prebuilt APK into your Android build, follow these steps:

1. Place the APK and build file in your source tree  
   (commonly under `vendor/<vendor>/prebuilts/apps/<AppName>/` or `packages/apps/<AppName>/`).
2. Define the module using an `Android.bp` or `Android.mk` file:
   + Example `Android.bp` snippet:

   > android_app_import {
   >     name: "MyApp",
   >     apk: "MyApp.apk",
   >     presigned: true,
   >     privileged: false,
   > }

3. Add the module name to your device or product makefile  
   (`device/<vendor>/<device>/<device>.mk` or a `common .mk` file) via **PRODUCT_PACKAGES**:

   > PRODUCT_PACKAGES += MyApp

## To remove a pre-installed APK

To remove a pre-installed APK when compiling an Android system image (AOSP),  
you need to remove it from the build configuration *makefiles*  
and ensure it isn't pulled back in through dependencies or system configurations.

### Locate and remove the package name from PRODUCT_PACKAGES

Search your device or product makefiles (usually found in `device/<vendor>/<product>/` or `build/make/target/product/`)  
for the package name inside the **PRODUCT_PACKAGES** variable, then delete it.

> Example in `device.mk` or `product.mk`
> PRODUCT_PACKAGES += \
>     UnwantedApp

### Check for inclusion dependencies

If the app isn't explicitly listed in your product makefiles,  
it may be pulled in via **LOCAL_REQUIRED_MODULES** by another package,  
or inherited from a base makefile (like `handheld_product.mk` or `common_full.mk`).  
Trace where the package is defined using `grep -rn "PackageName" .` in your root source directory and remove those references.

### Remove corresponding system configuration XML entries

Modern Android versions use *preinstalled-packages allowlists*.  
If the app has an entry in a system configuration XML file,  
locate it under `build/make/target/product/sysconfig/` or your device folder and remove its block:

```xml
<!-- Remove this entry if present -->
<kit-package name="com.example.unwantedapp" />
```

### Clean the build and recompile

Because build artifacts and dependency trees are cached, you must clear out old outputs before recompiling:

```bash
make clean
# Or if usingsoong/lunch:
m clobber
lunch your_device-userdebug
m
```

### Verification

Flash the newly compiled image to your device or emulator,  
and check the app drawer or run `adb shell pm list packages` to confirm the package is gone.
