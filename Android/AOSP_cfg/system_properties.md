# System properties on Android (RK3566, Android 14)

System properties are global `name` → `value` string pairs that `init` keeps for the whole OS.
They are used for configuration, small pieces of state, and signaling between processes and `init`.
The examples assume an Android 14 BSP for the Rockchip RK3566 that you build yourself, but the mechanism is the same on any Android device.

## 1. How they work

```text
reader process                         writer process
  __system_property_get()                __system_property_set()
        |                                       |
        | mmap (read-only)                      | UNIX socket /dev/socket/property_service
        v                                       v
  /dev/__properties__/<context files>  <--  init (property service)
                                              + SELinux check (property_contexts)
                                              + persist.* also written to /data/property/
                                              + fires "on property:" triggers in .rc files
```

+ **Reads are cheap.** `init` creates the property areas under `/dev/__properties__/` (one file per SELinux context).
  Every process maps them read-only, so a read doesn't talk to `init`.
  SELinux decides which context files a process may map, which is why some properties are invisible to some processes.
+ **Writes go through `init`.** `setprop` / `__system_property_set` sends a request to `init`'s property service.
  `init` checks the caller's SELinux domain against the property's context (`property_contexts` + `set_prop` rules), then updates the value.
+ **`init` can react to changes** with `on property:<name>=<value>` triggers in `.rc` files (see section 4).

### Name prefixes

| Prefix | Behavior | Example |
| --- | --- | --- |
| `ro.*` | Set once (normally at boot from build `.prop` files), then read-only | `ro.build.version.release`, `ro.board.platform` |
| `ro.boot.*` | Read-only, filled from the kernel command line / bootconfig by the bootloader | `ro.boot.serialno` |
| `persist.*` | Survives reboots: stored in `/data/property/` and loaded after `/data` is mounted | `persist.vendor.mycust.mode` |
| `ctl.start`, `ctl.stop`, `ctl.restart` | Not stored; a command to `init` to start/stop a service (only for domains allowed to set it) | `setprop ctl.start mydaemon` |
| `init.svc.<name>` | Set by `init`: state of a service (`running`, `stopped`, `restarting`) | `init.svc.mydaemon` |
| others (`sys.*`, `vendor.*`, ...) | Normal runtime properties, lost on reboot | `sys.boot_completed`, `vendor.mydaemon.state` |

Since Android 11 (enforced for devices launching with it), properties owned by the vendor partition must use a vendor namespace:
`vendor.`, `persist.vendor.`, `ro.vendor.`, `ro.boot.`, or `ro.hardware.`.

### Limits

+ A value is at most 91 bytes (`PROP_VALUE_MAX` = 92 including the NUL). Only `ro.*` properties may be longer (since Android 8).
+ The total property area is small and fixed.
+ So properties are for **flags, modes, IDs, and short status strings**. Not for payloads, JSON, or frequently changing data.

## 2. Common uses on an embedded board

+ **Board bring-up:** display/orientation hints, camera or sensor flags, Rockchip vendor settings passed between `init` scripts, HALs, and framework code.
+ **Feature toggles and device modes:** ADB, kiosk mode, debug logging, peripheral power states.
+ **Service control:** start/stop native daemons (`ctl.start` / `ctl.stop`, or `on property:` triggers) and check `init.svc.<name>`.
+ **Cross-layer state:** a native daemon or HAL publishes `ready` or `calibrating`, and Java services or `init` triggers react to it.

## 3. Reading and writing

```shell
adb shell getprop                                  # list all (that the shell domain can read)
adb shell getprop ro.board.platform
adb shell getprop -Z vendor.rk_action.trigger      # show the SELinux context of a property
adb root                                           # userdebug/eng: setprop from the shell needs root for vendor properties
adb shell setprop vendor.rk_action.trigger 1
```

| Layer | Read | Write | Wait for a change |
| --- | --- | --- | --- |
| C/C++ (NDK, `<sys/system_properties.h>`) | `__system_property_get`, `__system_property_read_callback` | `__system_property_set` | `__system_property_wait` (API 26+) |
| C++ platform code (`libbase`, `<android-base/properties.h>`) | `android::base::GetProperty`, `GetBoolProperty` | `SetProperty` | `WaitForProperty` |
| Java platform code | `android.os.SystemProperties.get` | `SystemProperties.set` | `SystemProperties.addChangeCallback` |
| `.rc` files | `${name}` expansion | `setprop` | `on property:name=value` |

`android.os.SystemProperties` is `@hide`. Only platform code (system apps built with the platform) should use it.
Third-party apps that reach it through reflection depend on hidden APIs and on SELinux allowing the read, so don't build a customer interface on that.
For typed, versioned properties in platform code, see `sysprop_library` ("Implementing system properties as APIs" in the references).

## 4. Starting a native service when a property changes

`init` watches the property and starts a service declared in an `.rc` file.
The property needs its own SELinux type, so the writer can be allowed to set it.

Names used below: property `vendor.rk_action.trigger`, property type `vendor_rk_action_prop`, daemon `rk_action` in `/vendor/bin/rk_action`.

Use a compiled binary, not a `/system/bin/sh` script: a script started by `init` needs its own domain and entrypoint rules, and shell scripts as services are discouraged on modern Android.

### 4.1 SELinux policy

```text
# device/<vendor>/<board>/sepolicy/vendor/property.te
vendor_internal_prop(vendor_rk_action_prop)

# device/<vendor>/<board>/sepolicy/vendor/property_contexts
vendor.rk_action.               u:object_r:vendor_rk_action_prop:s0

# device/<vendor>/<board>/sepolicy/vendor/rk_action.te
type rk_action, domain;
type rk_action_exec, exec_type, vendor_file_type, file_type;
init_daemon_domain(rk_action)
get_prop(rk_action, vendor_rk_action_prop)

# device/<vendor>/<board>/sepolicy/vendor/file_contexts
/vendor/bin/rk_action           u:object_r:rk_action_exec:s0

# In the .te of whoever sets the property (a vendor daemon or HAL)
set_prop(<writer_domain>, vendor_rk_action_prop)
```

+ `vendor_internal_prop` may only be used by vendor domains.
  If a platform process (for example your system app) must set it, declare it with `vendor_public_prop` instead; see "Adding system properties" in the references.
+ `init` itself can always read and set properties, so the trigger doesn't need extra rules.

### 4.2 `.rc` file

```text
# /vendor/etc/init/rk_action.rc (install with init_rc: ["rk_action.rc"] in Android.bp)
service rk_action /vendor/bin/rk_action
    class main
    user system
    group system
    oneshot
    disabled

on property:vendor.rk_action.trigger=1
    start rk_action
    setprop vendor.rk_action.trigger 0
```

+ `disabled`: not started with its class at boot; only by `start`.
+ `oneshot`: runs once and isn't restarted when it exits.
+ Resetting the property to `0` lets the next `1` fire the trigger again.
+ No `seclabel` is needed: `init_daemon_domain` plus the `file_contexts` label moves the process into the `rk_action` domain.
+ Use the least privileged `user`; root doesn't bypass SELinux.

### 4.3 Verify

| Step | Check |
| --- | --- |
| Policy builds | `m selinux_policy` passes without `neverallow` or unknown-type errors |
| Property is labeled | `adb shell getprop -Z vendor.rk_action.trigger` shows `vendor_rk_action_prop` |
| Writer may set it | `setprop` from the writer's context succeeds, no `avc: denied` in `logcat` / `dmesg` |
| Trigger works | `getprop init.svc.rk_action` goes to `running`, then back to `stopped` |
| Action happened | the daemon's `logcat` output, and `adb shell dmesg \| grep -i avc` shows no denials for `rk_action` |

## 5. System properties vs a system service with AIDL

The two work at different layers. System properties are **shared key-value strings**.
AIDL is a **typed Binder RPC interface** with methods, data structures (`Parcelable`), error handling, and callbacks.
For a **customer-facing interface**, a system service with AIDL is usually the better choice; properties fit configuration, `init` triggers, and internal plumbing.

| | System properties (`vendor.*`, `persist.vendor.*`) | System service + AIDL |
| --- | --- | --- |
| API for customers | Raw string keys; no method signatures or types | Typed methods, easy to wrap in an SDK (JAR/AAR) |
| Data | Short strings (≤ 91 bytes); flags, modes, IDs | Typed values, `Parcelable`s, lists, file descriptors |
| Access control | SELinux domains only (`property_contexts` + `.te`); can't tell apps apart | Android permissions (e.g. `signature`), UID/package checks, plus SELinux |
| Change notification | Polling, native wait, or `init` triggers; no public app callback | AIDL callback interfaces (`oneway`, so a slow client can't block the service) |
| Validation and errors | None: anyone allowed to write can set any string; the writer can't tell whether it took effect | The service checks arguments and state, and returns values or errors (`ServiceSpecificException`) |
| Evolution | Customers hard-code property names; hard to change later | Versioned AIDL interfaces |
| Effort | Low | Higher: service, SELinux domain, AIDL, client library |

Why AIDL usually wins for customer interfaces:

+ **Security boundary.** To let an app write a property, SELinux must allow the app's whole domain to set it, so every app in that domain can flip it.
  A service sits in the middle: it checks the caller's permission or identity, validates the arguments, and decides whether to act.
+ **Developer experience.** Customers call documented methods such as `setRelayState(id, enabled)` or `registerStatusCallback(cb)`
  instead of writing magic strings and polling to see whether the change happened.
+ **No hidden API workarounds.** `android.os.SystemProperties` is `@hide`, which pushes app developers toward reflection or JNI (section 3).

**Use properties** when the interaction is simple and close to `init` or native code:
boot-time configuration (including early boot, before framework services run), `persist.vendor.*` flags read at boot, starting/stopping `init` services,
read-only device metadata or a readiness flag with write access locked down,
and internal plumbing where your own privileged service writes a property to wake a daemon or HAL.
A property used as a quick control switch during board bring-up is fine too, but replace it with a service before shipping.

**Use a system service + AIDL** when customers build real applications on the device:
GPIO/relay/LED/backlight, serial/CAN, display, USB/ADB/kiosk policy, power and watchdog control;
anything that needs callbacks, per-app permissions, structured data, readback, or multi-step operations with preconditions.
Two writers setting the same property race each other, and nobody gets an answer, so hardware control in particular belongs behind a service.
For GPIO and LEDs the full stack is: device tree → kernel GPIO character device / LED class → native AIDL HAL in `vendor` → system app → customer app
([../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md), [../HW/gpio_control.md](../HW/gpio_control.md), [../HW/Led_control.md](../HW/Led_control.md)).

### Hybrid pattern (usually the best fit)

```text
customer app --(Binder, AIDL + permission check)--> your system app / system service
                                                         | validates the request
                                                         +--> sets a vendor.* property --> init trigger / native daemon
                                                         +--> or calls an AIDL HAL directly
```

The properties stay internal (or read-only for apps), so customers get a stable, documented API and no app needs broad property write access.

## 6. Exposing properties to customer apps: caveats

+ Third-party apps all run in the `untrusted_app` domain. A rule for that domain applies to **every** installed app, so never grant it write access to your properties.
  Third-party apps should reach device functions through a system app's bound service ([../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md)).
+ Reading a non-sensitive, read-only property (for example a firmware tag) is acceptable if your policy makes it readable, but treat its name as a public API you can't rename.
  Some standard properties are deliberately unreadable for apps, for example `ro.serialno`; see [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md#6-example-device-info-and-bluetooth-control) for what apps can and can't read and how a system app provides the rest.
+ Apps you build into the image (platform-signed system apps) get their own domain (`system_app`, `platform_app`) and can be granted `get_prop` / `set_prop` on specific types.
+ There is no change listener for apps, no types, and no validation; wrap anything more than a flag in a service (section 5).

## Related notes

+ [../Native/native_daemon.md](../Native/native_daemon.md): `.rc` services, `init.svc.*`, talking to a daemon
+ [../SELinux/SELinux_policy.md](../SELinux/SELinux_policy.md), [../SELinux/avc_denied.md](../SELinux/avc_denied.md), [../SELinux/neverallow_error.md](../SELinux/neverallow_error.md)
+ [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md), [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md), [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md)
+ [SettingsProvider_intro.md](SettingsProvider_intro.md): `Settings.*` as the app-level alternative for user settings
+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md)

## Reference

+ [Adding system properties (AOSP)](https://source.android.com/docs/core/architecture/configuration/add-system-properties)
+ [Implementing system properties as APIs (AOSP)](https://source.android.com/docs/core/architecture/configuration/sysprops-apis)
+ [Android init language (system/core/init/README.md)](https://android.googlesource.com/platform/system/core/+/main/init/README.md)
+ [SELinux for Android (AOSP)](https://source.android.com/docs/security/features/selinux)
