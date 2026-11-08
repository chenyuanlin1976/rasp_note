# SELinux introduction

**SELinux (Security-Enhanced Linux)** is a Linux kernel security module (LSM) that adds **Mandatory Access Control (MAC)**
on top of normal Unix permissions.
Android has used it in **enforcing** mode for all domains since **Android 5.0**.
Since then, every process, file, socket, property, and Binder service on a device is checked against a policy.

## 1. DAC vs MAC

| | DAC (classic Unix permissions) | MAC (SELinux) |
| --- | --- | --- |
| Who decides | The **owner** of the object (`chmod`, `chown`) | The **system policy**, written by the OS/device builder |
| Based on | User/group IDs (UID/GID) and mode bits | **Security labels** (types) of the process and the object |
| root | Bypasses most checks | Confined like everyone else: root in a restricted domain is still restricted |
| Default | Whatever the mode bits allow | **Deny** unless an `allow` rule exists |

Both checks run, and an access must pass **both** DAC and MAC.
Most "permission denied" errors on Android are either DAC (owner/mode) or an SELinux `avc: denied`.

## 2. Core concepts

+ **Security context (label)**: every subject (process) and object (file, socket, ...) has a label of the form `user:role:type:level`.
  + Android: `u:r:untrusted_app:s0:c512,c768` (a process) or `u:object_r:system_file:s0` (a file).
  + Fedora/RHEL: `system_u:system_r:httpd_t:s0`.
+ **Type** (the 3rd field) is what the policy rules use (**Type Enforcement**).
  A process type is called a **domain**.
  On Android, types have no `_t` suffix; on desktop Linux (Reference Policy), they end in `_t`.
+ **Rules**: `allow <domain> <type>:<class> { <permissions> };`, for example `allow netd proc_net:file { read open };`.
  Anything not allowed is denied, and the kernel logs an **AVC denial** (see [avc_denied.md](avc_denied.md)).
+ **Level** (MLS/MCS) on Android: categories such as `c512,c768` separate apps and users from each other,
  even when 2 apps share the same type (`untrusted_app`).
+ **Modes**: *enforcing* (deny and log) or *permissive* (log only).
  Check with `adb shell getenforce`.
  `setenforce 0` works only on userdebug/eng builds, and production (user) builds must be enforcing.

## 3. Policy flavors

| | Android policy | Desktop Linux "targeted" policy (Fedora/RHEL) |
| --- | --- | --- |
| Source | `system/sepolicy` (AOSP) + device/vendor directories | Reference Policy (`selinux-policy` package) |
| Scope | **Everything** is confined; there is no unconfined domain | Mainly network-facing services; users are mostly `unconfined_t` |
| Changes | Built into the image; no runtime module loading | Loadable modules (`semodule -i x.pp`) |
| Guardrails | `neverallow` rules checked at build time and by CTS | Mostly per-module |

Other desktop policy types are `mls` (multi-level) and `minimum`. "Strict" is an old name, and "enforcing" is a **mode**, not a policy type.
How to write Android policy is in [SELinux_policy.md](SELinux_policy.md).

## 4. Android-specific design

+ **Domain isolation**: every system service (`vold`, `netd`, `installd`, `surfaceflinger`, every HAL) runs in its own domain.
  A compromised service stays inside what its domain allows.
  The common domains are listed in [SELinux_domains.md](SELinux_domains.md).
+ **App sandbox**: apps get their domain from `seapp_contexts`
  (`untrusted_app`, `platform_app`, `priv_app`, ...), plus per-app MLS categories.
+ **Treble split (Android 8+)**: the policy is built from the **platform** part (`/system`, `/system_ext`, `/product`)
  and the **vendor** part (`/vendor`, `/odm`).
  + Vendor policy may reference only **public** platform types (`system/sepolicy/public`), never private ones (`system/sepolicy/private`).
  + Versioned **mapping files** keep an old vendor policy working with a newer platform.
  + On boot, `init` compiles the CIL pieces (`plat_sepolicy.cil`, `vendor_sepolicy.cil`, mapping files),
    or loads `precompiled_sepolicy` if it still matches.
+ **`neverallow` guardrails**: AOSP ships thousands of `neverallow` rules,
  for example "no app may write block devices" or "vendor code may not access core system data".
  A policy that violates one **fails to build**, and CTS checks them again on the device.
  You fix the design; you never edit the `neverallow` (see [neverallow_error.md](neverallow_error.md)).
+ **Generic labels are red flags**: rules that grant access to catch-all types such as `block_device`, `device`,
  `default_prop`, `default_service`, or `sysfs` usually mean a missing specific label.
  Many of them are blocked by `neverallow` rules.

## 5. Android 14 notes

These Android 14 changes are related to the sandbox. Several of them are enforced by the **framework or runtime**, not by SELinux policy.

+ **Safer dynamic code loading**: apps targeting API 34 must mark dynamically loaded DEX/JAR files **read-only**.
  Otherwise, the runtime throws an exception.
  This check is in ART/the framework, not in an SELinux rule.
+ **Intent and broadcast hardening**: implicit intents reach only exported components,
  and runtime-registered receivers must declare `RECEIVER_EXPORTED` / `RECEIVER_NOT_EXPORTED`. This is a framework change.
+ **Per-target-SDK app domains continue**: apps that target older SDKs are placed in `untrusted_app_32`, `untrusted_app_30`, ... (see [SELinux_domains.md](SELinux_domains.md)).
  Then newer restrictions apply only to apps that target newer SDKs.
+ **GKI**: Android 14 devices launch with `android14-5.15` or `android14-6.1` GKI kernels.
  SELinux in the kernel is upstream code; vendors may not patch it in GKI.

## Related notes

+ [SELinux_policy.md](SELinux_policy.md): writing Android policy (`.te`, `file_contexts`, macros, build, debug)
+ [SELinux_DomainTran.md](SELinux_DomainTran.md): how a process gets its domain
+ [SELinux_domains.md](SELinux_domains.md): common Android and desktop domains
+ [avc_denied.md](avc_denied.md), [neverallow_error.md](neverallow_error.md)

## Reference

+ [SELinux in Android](https://source.android.com/docs/security/features/selinux)
+ [SELinux concepts (AOSP)](https://source.android.com/docs/security/features/selinux/concepts)
+ [Android 14 behavior changes](https://developer.android.com/about/versions/14/behavior-changes-14)
