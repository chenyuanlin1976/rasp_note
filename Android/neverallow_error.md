# neverallow error

When you see a **never allow** (or neverallow) error during an Android platform or AOSP build  
while trying to implement hardware control like LEDs,  
you are hitting an **SELinux build-time security violation**.

Android’s build system uses neverallow assertions as strict compilation guards.  
If your code or SELinux policy (.te files) tries to grant a process permission  
to do something deemed insecure by the platform,  
the compiler immediately halts and refuses to generate the policy.

## Why Controlling LEDs Triggers a "Never Allow" Error

+ **Direct Hardware/Sysfs Access is Prohibited**:  
  LEDs are typically controlled via kernel sysfs nodes (such as `/sys/class/leds/...`) or raw device drivers.  
  Android strictly forbids apps, regular processes, or unprivileged services from directly touching sysfs or raw device files.
+ Conflicting Policy Rules:  
  To fix a runtime crash, you likely added an allow rule in your SELinux policy  
  (e.g., allowing your app or custom service to read/write to sysfs or a generic device label).  
  Because this conflicts with a core AOSP neverallow rule protecting system integrity, the build fails.

## How to Fix It (The Correct Architecture)

To control LEDs legally within Android's security model,  
you must **route your commands through the official layered Android architecture**  
rather than trying to access the hardware directly from an app or high-level service.

`[App/ Client] ---> (AIDL Interface) ---> [System Service/ HAL] ---> (Custom Label) ---> [Kernel / LEDs (/sys/class/leds)]`

### Step 1: Use a Proper HAL or Privileged Service

Never let a standard application talk to hardware files. Instead:  

+ Define your AIDL interface for LED control.
+ Implement a dedicated **System Service** or a **Vendor HAL (@vintf_stability)**  
  that runs in its own isolated, privileged SELinux domain.

### Step 2: Fix the SELinux Labeling (Instead of Bypassing neverallow)

If your native service or HAL needs to touch the LED sysfs files,  
you must use fine-grained labeling instead of broad permissions:

1. Define a specific file context in your device's `file_contexts` file rather than using generic sysfs labels:  
   `/sys/class/leds/my_custom_led(/.*)?    u:object_r:sysfs_leds:s0`
2. Grant permissions only to your specific service domain in its .te policy file, using the custom label:  

```ini
# Correct: Allow only your designated LED service to access the specific led label
allow-your_led_service_domain sysfs_leds:file { open read write };
```

## Step 3: Never Modify Core AOSP neverallow Files

If you are tempted to edit files inside `system/sepolicy/public/`  
to delete or comment out the neverallow rule blocking your build, **don't do it**.  
Doing so breaks Android platform security compliance and will cause your build to fail CTS (Compatibility Test Suite) later.  
Always solve the error by narrowing the scope of your policy and using specific custom types.

## other strict neverallow rules

While touching hardware nodes like LEDs is a classic trigger,  
Android's SELinux compiler (sepolicy) enforces several other strict neverallow rules.

If your custom service, app, or vendor partition attempts any of the following patterns,  
the build will break with a neverallow violation:

### 1. Vendor Partition Accessing Core System Data/ Properties

+ The Rule: Vendor-specific code (like something running under /vendor or /odm)  
  is never allowed to directly read or write arbitrary system properties or private system files  
  that aren’t explicitly exposed as public APIs.
+ Why it fails: Android enforces Project Treble to separate core OS updates (/system) from hardware implementation (/vendor).  
  Allowing a vendor component to grab private system properties breaks this boundary.
+ How to fix it: Define custom vendor properties with a designated prefix (e.g., vendor_myfeature_prop)  
  rather than modifying or reading core system properties (persist.sys....).

### 2. Untrusted Apps Executing Arbitrary Code / Shell Commands

+ The Rule: Standard, third-party apps (untrusted_app) or even some privileged apps  
  are never allowed to execute binaries out of writable directories (like /data) or call raw shell commands (like sh or su) directly.
+ Why it fails: This prevents code injection, remote exploit payloads, and privilege escalation vulnerabilities.
+ How to fix it: Move application logic into structured services communicating via AIDL  
  rather than bundling executable binaries inside app data directories to run via runtime shells.

### 3. Granting Broad Read/Write Access to All Files (file *)

+ The Rule: You can never write a policy rule that gives a domain broad permissions over everything,  
  such as `allow my_service app_data_file:file rw_file_perms;` across unsafe boundaries,  
  or using wildcards like `allow my_service domain:file *;`.
+ Why it fails: SELinux relies on the Principle of Least Privilege.  
  Blanket permissions violate core Android sandbox guarantees.
+ How to fix it: Specify exact file types, exact paths via custom labeling, and the bare minimum required actions  
  (open, read, etc. instead of all-inclusive wildcards).

### 4. Direct Socket or Binder Communication Between Unrelated Domains

+ The Rule: Vendor components are restricted from talking directly to arbitrary system daemons over raw sockets or binder  
  unless that interface is officially declared in the Treble manifest (vintf).
+ Why it fails: Uncontrolled IPC bypasses the service manager security architecture  
  and can leave backdoors open into secure system spaces (like keystore or radio interfaces).
+ How to fix it: Route your cross-process communication strictly through certified, declared AIDL interfaces registered with the ServiceManager.
