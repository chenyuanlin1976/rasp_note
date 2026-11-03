# Writing Android SELinux policy

This note covers how to write SELinux policy for an AOSP device: the files, the rule syntax, the macros,
a complete example, and how to build and debug it.
For the concepts (labels, domains, deny-by-default), see [SELinux_intro.md](SELinux_intro.md).
The desktop Linux (Reference Policy) style is compared in [section 7](#7-desktop-linux-reference-policy-is-different).

## 1. Where policy lives

| Location | Partition | Set by |
| --- | --- | --- |
| `system/sepolicy/public/` | platform, **public** (vendor may use these types) | AOSP |
| `system/sepolicy/private/` | platform, private | AOSP |
| `system/sepolicy/vendor/` | vendor, AOSP defaults (e.g. `hal_*_default`) | AOSP |
| `device/<vendor>/<board>/sepolicy/vendor/` | vendor | `BOARD_VENDOR_SEPOLICY_DIRS += ...` (`BOARD_SEPOLICY_DIRS` is the older name) |
| `.../sepolicy/system_ext/{public,private}` | system_ext | `SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS`, `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS` |
| `.../sepolicy/product/{public,private}` | product | `PRODUCT_PUBLIC_SEPOLICY_DIRS`, `PRODUCT_PRIVATE_SEPOLICY_DIRS` |

Device-specific work belongs in your **vendor** directory. Don't edit `system/sepolicy` for a device.

## 2. The policy files

| File | What it does | Example line |
| --- | --- | --- |
| `*.te` | Types, attributes, rules (Type Enforcement) | `allow mydaemon gpio_device:chr_file rw_file_perms;` |
| `file_contexts` | Labels for files on real filesystems (by path regex) | `/vendor/bin/mydaemon  u:object_r:mydaemon_exec:s0` |
| `genfs_contexts` | Labels for pseudo filesystems (`sysfs`, `proc`, `debugfs`) | `genfscon sysfs /devices/platform/leds u:object_r:sysfs_leds:s0` |
| `property_contexts` | Labels for system properties (by prefix) | `vendor.mydaemon.  u:object_r:vendor_mydaemon_prop:s0` |
| `service_contexts` | Labels for Binder services in `servicemanager` (AIDL) | `vendor.example.IFoo/default  u:object_r:hal_foo_service:s0` |
| `hwservice_contexts` | Labels for HIDL services (legacy) | `vendor.example.foo::IFoo  u:object_r:hal_foo_hwservice:s0` |
| `seapp_contexts` | Which domain and data label an **app** gets | `user=_app seinfo=platform name=com.example.x domain=my_app type=app_data_file levelFrom=all` |

## 3. Rule syntax

```text
type      mydaemon, domain;                       # declare a type and add it to attribute(s)
attribute my_attr;                                 # declare an attribute (a named group of types)
typeattribute mydaemon my_attr;                    # add an existing type to an attribute

allow      <source> <target>:<class> { <perms> };  # grant
neverallow <source> <target>:<class> { <perms> };  # build-time assertion: must never be granted
dontaudit  <source> <target>:<class> { <perms> };  # deny silently (no avc log)
auditallow <source> <target>:<class> { <perms> };  # allow but still log
allowxperm <source> <target>:<class> ioctl { 0x4001-0x4010 };   # restrict individual ioctl numbers

type_transition <source> <parent_type>:<class> <new_type>;     # label new objects automatically
```

+ **source**: the domain of the process (the subject).
+ **target**: the type of the object (file, socket, property, Binder service, or another domain).
  `self` means the source itself.
+ **class**: `file`, `dir`, `chr_file`, `blk_file`, `lnk_file`, `sock_file`, `unix_stream_socket`, `process`,
  `binder`, `property_service`, `service_manager`, `capability`, ...
+ **perms**: `read`, `write`, `open`, `getattr`, `ioctl`, `execute`, `find`, `add`, `call`, `set`, ...

## 4. Macros you will use

Android policy is processed with **m4**. The macro definitions are in `system/sepolicy/public/global_macros` and `te_macros`.

**Permission sets** (`global_macros`):

| Macro | For |
| --- | --- |
| `r_file_perms`, `w_file_perms`, `rw_file_perms` | Reading/writing existing files (`rw_file_perms` includes `ioctl`, `lock`, `append`) |
| `x_file_perms`, `rx_file_perms` | Executing files |
| `create_file_perms` | Creating/deleting files (`create`, `rename`, `unlink`, plus `rw_file_perms`) |
| `r_dir_perms`, `rw_dir_perms`, `create_dir_perms` | Directories |

**Rule macros** (`te_macros`):

| Macro | Meaning |
| --- | --- |
| `init_daemon_domain(d)` | `init` executing `d_exec` transitions to domain `d` (see [SELinux_DomainTran.md](SELinux_DomainTran.md)) |
| `domain_auto_trans(src, exec_type, dst)` | General auto-transition on `exec` |
| `file_type_auto_trans(d, dir_type, file_type)` | Files/dirs that `d` creates in `dir_type` get `file_type` |
| `binder_use(d)`, `binder_call(c, s)`, `binder_service(d)` | Binder use, calls from `c` to `s`, being a service |
| `add_service(d, svc_type)` | Register a Binder service with `servicemanager` |
| `hal_attribute(name)`, `hal_server_domain(d, hal_name)`, `hal_client_domain(d, hal_name)`, `hal_attribute_service(hal_name, svc_type)` | AIDL HAL server/client wiring (see [AIDL_HAL_impl.md](AIDL_HAL_impl.md)) |
| `get_prop(d, prop_type)`, `set_prop(d, prop_type)` | Read/write system properties |

Prefer these macros to long hand-written permission lists: they stay correct as the kernel adds permissions.

## 5. Complete example: a vendor daemon

The daemon `/vendor/bin/mydaemon` is started by init.
It keeps state in `/data/vendor/mydaemon/`, reads `/dev/gpiochip*`, and sets a `vendor.mydaemon.*` property.

```text
# device/<vendor>/<board>/sepolicy/vendor/mydaemon.te

# 1. Domain + executable type; init -> mydaemon on exec
type mydaemon, domain;
type mydaemon_exec, exec_type, vendor_file_type, file_type;
init_daemon_domain(mydaemon)

# 2. Private data directory (/data/vendor/mydaemon)
type mydaemon_data_file, file_type, data_file_type;
allow mydaemon mydaemon_data_file:dir create_dir_perms;
allow mydaemon mydaemon_data_file:file create_file_perms;

# 3. GPIO character devices (custom label, see file_contexts)
type gpio_device, dev_type;
allow mydaemon gpio_device:chr_file rw_file_perms;

# 4. Its own property namespace
vendor_internal_prop(vendor_mydaemon_prop)
set_prop(mydaemon, vendor_mydaemon_prop)
```

```text
# device/<vendor>/<board>/sepolicy/vendor/file_contexts
/vendor/bin/mydaemon              u:object_r:mydaemon_exec:s0
/data/vendor/mydaemon(/.*)?       u:object_r:mydaemon_data_file:s0
/dev/gpiochip[0-9]+               u:object_r:gpio_device:s0
```

```text
# device/<vendor>/<board>/sepolicy/vendor/property_contexts
vendor.mydaemon.                  u:object_r:vendor_mydaemon_prop:s0
```

```text
# vendor init .rc: create the data dir with the right owner; init applies the label from file_contexts
on post-fs-data
    mkdir /data/vendor/mydaemon 0770 system system

service mydaemon /vendor/bin/mydaemon
    class main
    user system
    group system
```

You don't need `seclabel` in the `.rc` file, because `init_daemon_domain` plus the `file_contexts` label does the transition.

## 6. Build, install, debug

```shell
# Rebuild just the policy (also run as part of a full build; neverallow violations fail here)
m selinux_policy

# Device state
adb shell getenforce                 # Enforcing / Permissive
adb shell ps -AZ | grep mydaemon     # process label
adb shell ls -Z /vendor/bin/mydaemon # file label
adb shell restorecon -R /data/vendor/mydaemon   # re-apply file_contexts labels

# Denials
adb shell dmesg | grep 'avc: denied'
adb logcat -b all -d | grep 'avc: denied'

# Turn denials into candidate rules (host side; review them, don't paste blindly)
adb shell dmesg | grep avc | audit2allow -p $OUT/vendor/etc/selinux/precompiled_sepolicy
```

Development tips:

+ While you bring up a new domain, `permissive mydaemon;` in the `.te` file logs instead of denying.
  It is allowed only on userdebug/eng builds and must be removed before release.
+ Run `audit2allow` output through the "least privilege" filter.
  If the suggestion says `allow mydaemon device:chr_file ...`, the real fix is a specific label in `file_contexts`, not a rule on `device`.
+ If a rule hits a `neverallow`, change the design. For example, move the access into a HAL instead of an app.
  See [neverallow_error.md](neverallow_error.md).

## 7. Desktop Linux (Reference Policy) is different

Notes on the web often show **Reference Policy** syntax (Fedora/RHEL). It does **not** work in AOSP:

| | Android (`system/sepolicy`) | Reference Policy (Fedora/RHEL) |
| --- | --- | --- |
| Type names | `mydaemon`, `mydaemon_exec` | `myapp_t`, `myapp_exec_t` |
| Module header | none | `policy_module(myapp, 1.0.0)` |
| Files | `.te` + `file_contexts`, `*_contexts` | `.te` + `.fc` (file contexts) + `.if` (interfaces) |
| Daemon macro | `init_daemon_domain(d)` | `init_daemon_domain(myapp_t, myapp_exec_t)` |
| Perm sets | `r_file_perms`, `rw_file_perms`, `create_file_perms` | `read_file_perms`, `rw_file_perms`, `manage_file_perms` |
| Helpers | `te_macros` (`binder_call`, `hal_client_domain`, ...) | Interfaces (`files_read_etc_files`, `logging_send_syslog_msg`, ...) |
| Build/load | Built into the image (`m selinux_policy`) | `make -f /usr/share/selinux/devel/Makefile myapp.pp` → `semodule -i myapp.pp` |

A minimal Reference Policy module, for comparison:

```text
# myapp.te
policy_module(myapp, 1.0.0)

type myapp_t;
type myapp_exec_t;
init_daemon_domain(myapp_t, myapp_exec_t)     # declares the domain + entrypoint + systemd transition

type myapp_log_t;
logging_log_file(myapp_log_t)
allow myapp_t myapp_log_t:file append_file_perms;
logging_log_filetrans(myapp_t, myapp_log_t, file)   # new files in /var/log get myapp_log_t

files_read_etc_files(myapp_t)
logging_send_syslog_msg(myapp_t)
```

```text
# myapp.fc
/usr/sbin/myapp     --  gen_context(system_u:object_r:myapp_exec_t,s0)
/var/log/myapp(/.*)?    gen_context(system_u:object_r:myapp_log_t,s0)
```

```shell
make -f /usr/share/selinux/devel/Makefile myapp.pp
sudo semodule -i myapp.pp
sudo restorecon -Rv /usr/sbin/myapp /var/log/myapp
# scaffolding generator: sepolicy generate --init /usr/sbin/myapp
```

## Related notes

+ [SELinux_intro.md](SELinux_intro.md), [SELinux_DomainTran.md](SELinux_DomainTran.md), [SELinux_domains.md](SELinux_domains.md)
+ [avc_denied.md](avc_denied.md), [neverallow_error.md](neverallow_error.md)
+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md), [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md): policy for real HALs

## Reference

+ [Writing SELinux policy (AOSP)](https://source.android.com/docs/security/features/selinux/implement)
+ [Customizing SELinux (AOSP)](https://source.android.com/docs/security/features/selinux/customize)
+ [`system/sepolicy` source](https://android.googlesource.com/platform/system/sepolicy/)
+ [SELinux Reference Policy](https://github.com/SELinuxProject/refpolicy)
