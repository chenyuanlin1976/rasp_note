# VINTF introduction

In Android, VINTF stands for Vendor Interface object (often referred to as the VINTF tree, VINTF object, or VINTF check).  

Introduced in Android 8.0 alongside Project Treble,  
VINTF is a critical mechanism designed to **decouple** the Android OS framework (the **system partition**)  
from the hardware-specific vendor implementation (**the vendor and odm partitions**).  

Its primary purpose is to enforce and verify compatibility between the **system software**  
and the underlying **hardware/vendor software**.

## 1. Why was VINTF needed?

Before Project Treble and VINTF, Android's core OS and chipmaker/OEM-specific drivers were tightly coupled.  
Upgrading an Android version meant rewriting and rebuidling massive portions of the kernel and hardware abstraction layers (HALs).

VINTF solves this by **introducing a standardized "contract" language using XML files**.  
It ensures that Google can update the Android framework (e.g., via an OTA update) without needing to change the vendor drivers,  
provided that both sides satisfy the **VINTF contract**.

## 2. Core Components of VINTF

VINTF relies on 2 main pillars - `Manifests` (what is provided) and `Compatibility Matrices` (what is required):

+ **Device Manifest (DM)**: Provided by the hardware vendor or OEM.  
  It lists everything the hardware platform provides to the system, including:
  + Available HAL interfaces and their versions (e.g., android.hardware.camera v2.4).
  + SEPolicy (Security Policy) version.
  + The Linux kernel version and specific kernel configuration flags (e.g., CONFIG_FOO=y).
+ **Framework Compatibility Matrix (FCM)**: Defined by Google/Android framework developers.  
  It specifies what the framework demands from the device in order to run properly  
  (e.g., minimum required HAL versions, required kernel configs).
+ **Framework Manifest & Device Compatibility Matrix**:  
  Conversely, the framework also exposes a manifest of what it provides to apps/vendors,  
  and devices have matrices demanding certain framework features.

## 3. How VINTF Works (The Compatibility Check)

During device boot-up (and during build time or OTA updates),  
the VintfObject (a system singleton) gathers and parses these XML configurations from various partitions  
(like `/vendor/manifest.xml`, `/system/compatibility_matrix.xml`, etc.).

It performs a strict compatibility check:

1. HAL Match: Does the system require a HAL version that the vendor actually provides?  
   (If the system demands Camera HAL 3.0, but the vendor only provides 2.0, it's a mismatch).
2. Kernel Match: Does the running Linux kernel support the features, SEPolicy, and architecture required by this version of Android?
3. SEPolicy Match: Are the security policy versions compatible across boundaries?

If the check passes, the device boots up or applies the OTA update successfully.  
If it fails, the system halts or rejects the update, preventing unpredictable crashes or bootloops caused by driver-framework mismatches.

## 4. Key Benefits

+ Independent Updates: Google can push generic system images (GSIs) or framework updates independently of vendor drivers.
+ Automated Testing via VTS: The Vendor Test Suite (VTS) uses VINTF rules to automatically test  
  whether a vendor's implementation complies with Android platform standards.
+ Modular Architecture: Supports modern Android features like APEX modules,  
  where system and vendor components can supply modular manifest fragments  
  (etc/vintf/manifest/) that get dynamically merged at runtime.
