# SELinux introduction

SELinux (Security-Enhanced Linux) on Android 14 serves as a core layer of  
the operating system's **Mandatory Access Control (MAC) architecture**.  
Operating in Enforcing mode, it ensures that processes, files, and network sockets are strictly restricted to  
**only the permissions they explicitly need to function**.

In Android 14, SELinux policies and underlying frameworks saw several vital updates to minimize the attack surface,  
enforce stricter sandboxing, and align with newer kernel developments (such as Generic Kernel Image / GKI requirements).

## Key Focus Areas of SELinux in Android 14

### 1. Further Lockdown of the Application Sandbox

Android 14 tightens inter-process communication (IPC) and app visibility.  
SELinux rules work alongside enhanced seccomp filters and namespace isolations to prevent apps  
from accessing unauthorized system properties, hardware nodes, or private data directories  
belonging to other apps or system services.

### 2. Enhanced Dynamic Code Loading (DCL) Restrictions

Android 14 introduces tighter constraints on apps that utilize Dynamic Code Loading.  
SELinux policies, combined with platform checks, require dynamically loaded files to be strictly marked as read-only.  
This stops a compromised app or malicious module from writing and executing arbitrary code dynamically at runtime,  
closing a common vector used by malware to bypass detection.

### 3. Stricter Vendor and Platform Isolation (Project Treble Refinements)

Android continues to enforce strict separation between the core platform (system.img)  
and vendor-specific implementations (vendor.img / odm.img):

+ **Public vs. Private Types**: Vendor policies can only interact with public platform types defined by Google (system/sepolicy/public/).  
  They are strictly barred from referencing private platform types (system/sepolicy/private/).
+ This prevents OEMs or hardware vendors from accidentally or intentionally writing overly permissive rules  
  that puncture holes in the system-level sandbox.

### 4. GKI and Kernel Compatibility (Kernel 6.6+ Alignment)

With Android 14 relying heavily on the Generic Kernel Image (GKI) framework,  
SELinux internal structures within the Linux kernel experienced foundational adjustments:

+ The global selinux_state management was refined to match modern upstream kernel configurations.
+ Standalone symbols like selinux_enforcing transitioned into fields within structured states (selinux_state),  
  making the security subsystem more resilient against low-level kernel exploits attempting to flip the global enforcement flag.

### 5. Continued Reduction of Overly Permissive Policies

Google heavily audits device-specific implementations for Android 14 releases.  
Any generic denials (block_device, socket_device, default_service)  
or loose allow rules written by OEMs for custom Hardware Abstraction Layers (HALs) are aggressively rejected during compliance testing.  
Vendor domains must follow explicit, **least-privilege principles**.

## Core Principles Maintained in Android 14

+ **Default Deny**: If an action is not explicitly permitted by the compiled SELinux policy (plat_sepolicy.cil, etc.),  
  it is unconditionally blocked.
+ **Domain Isolation**: Every system service (vold, netd, installd, surfaceflinger, etc.)  
  and application runs inside its own tightly defined security domain.  
  If a service is compromised, the attacker's movement is confined strictly to that specific domain.
+ **Neverallow Assertions**: Build-time neverallow rules act as automated guardrails.  
  If an OEM or developer attempts to compile a policy that violates baseline security parameters  
  (e.g., giving an untrusted app access to raw disk devices), the build fails outright.
