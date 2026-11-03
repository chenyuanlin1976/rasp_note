# Common SELinux domains (Android and desktop Linux)

A **domain** is the SELinux type of a process. It decides what the process may do.
Android domain names have **no `_t` suffix** (`system_server`, `untrusted_app`).
Desktop Reference Policy domains end in **`_t`** (`httpd_t`, `sshd_t`).
To see the domains on a device: `adb shell ps -AZ`. On Fedora/RHEL: `ps -eZ`.

## 1. Android: app domains

The domain is chosen by `zygote` from `seapp_contexts`, based on the app's UID, signing certificate, and install location.

| Domain | Who gets it | Example |
| --- | --- | --- |
| `untrusted_app` | Normal apps that target the current SDK | Apps from the Play Store |
| `untrusted_app_32`, `untrusted_app_30`, `untrusted_app_29`, `untrusted_app_27`, `untrusted_app_25` | Normal apps with an **older `targetSdkVersion`**: they keep the older rules, so new restrictions apply only to apps that opt in by targeting newer SDKs | A legacy app targeting API 30 |
| `isolated_app` | Processes with `android:isolatedProcess="true"`: no network, no storage, minimal Binder | WebView/Chrome **renderer** processes |
| `system_app` | Apps that run with the **system UID** (`android:sharedUserId="android.uid.system"`) | Settings |
| `platform_app` | Apps **signed with the platform key** that don't run as the system UID | SystemUI, Launcher3 (AOSP) |
| `priv_app` | **Privileged** apps in `/system/priv-app`, `/product/priv-app`, ... that are **not** platform-signed | Google Play services, Play Store |
| `ephemeral_app`, `sdk_sandbox_*` | Instant apps; the privacy sandbox SDK runtime | |

Each app also gets per-app **MLS categories** (`s0:c512,c768`), so 2 apps with the same domain still can't read each other's data.

## 2. Android: core system domains

| Domain | Process | Role |
| --- | --- | --- |
| `kernel` | Kernel threads, and the first process before policy load | |
| `init` | PID 1 | Mounts filesystems, loads policy, starts services from `.rc` files |
| `vendor_init` | init's helper for **vendor** `.rc` commands | Gives vendor init scripts fewer rights than `init` |
| `ueventd` | `ueventd` | Creates `/dev` nodes and applies `ueventd.rc` permissions |
| `zygote` | `zygote`, `zygote64` | Forks every Java app process and sets its domain |
| `system_server` | `system_server` | Java system services: activities, windows, power, packages, ... |
| `servicemanager` / `hwservicemanager` / `vndservicemanager` | Binder service registries | AIDL `/dev/binder` / HIDL `/dev/hwbinder` / vendor `/dev/vndbinder` |
| `surfaceflinger` | `surfaceflinger` | Display compositor |
| `cameraserver`, `audioserver`, `mediaserver` | Media services | Front the camera/audio/media HALs for apps |
| `netd` | `netd` | Firewall (iptables/eBPF), routing, DNS |
| `vold` | `vold` | Volumes, mounting, File-Based Encryption keys |
| `installd` | `installd` | App data directories, dexopt |
| `logd`, `lmkd`, `statsd` | | Logging, low-memory killer, metrics |

## 3. Android: HAL domains

A HAL has an **attribute** and a **domain**:

+ `hal_<name>` is an **attribute** created by `hal_attribute(<name>)`.
  It comes with `hal_<name>_server` and `hal_<name>_client`.
  Policy for "any implementation of this HAL" is written against the attribute.
+ `hal_<name>_default` is the **domain** of AOSP's default implementation.
  Vendors use it or define their own, for example `hal_camera_qti`.
  The domain is linked to the attribute with `hal_server_domain(hal_camera_default, hal_camera)`.

| Attribute | Typical domain | Hardware |
| --- | --- | --- |
| `hal_audio` | `hal_audio_default` | Audio playback/recording |
| `hal_camera` | `hal_camera_default` | Camera provider (sensors, flash, ISP) |
| `hal_graphics_allocator`, `hal_graphics_composer` | `hal_graphics_allocator_default`, `hal_graphics_composer_default` | Buffer allocation, hardware composition |
| `hal_fingerprint`, `hal_face` | `hal_fingerprint_default` | Biometrics |
| `hal_power` | `hal_power_default` | Power hints, performance modes |
| `hal_light` | `hal_light_default` | LEDs, backlight |

A custom HAL follows the same pattern; see [AIDL_HAL_impl.md](AIDL_HAL_impl.md#4-selinux).

## 4. Android: debug domains

| Domain | When |
| --- | --- |
| `shell` | `adb shell`: a deliberately limited domain, even on userdebug |
| `su` | Root shell after `adb root` / `su`. It **exists only in userdebug/eng policy**; user builds don't contain it at all |
| `adbd` | The adb daemon |

## 5. Desktop Linux (Reference Policy, Fedora/RHEL) domains

SELinux is enabled by default on Fedora, RHEL, and their rebuilds (CentOS Stream, Rocky, Alma).
Debian can use it but doesn't enable it by default, and Ubuntu uses **AppArmor** by default.

| Area | Domain | Process / role |
| --- | --- | --- |
| Boot | `kernel_t` | Kernel threads (and everything before policy load) |
| | `init_t` | systemd (PID 1) |
| | `initrc_t` | Legacy SysV init scripts |
| | `udev_t` | udev: device nodes, hotplug |
| | `unconfined_service_t` | Services started by systemd that have **no** policy of their own (binary labeled `bin_t`/`usr_t`) |
| Users | `unconfined_t` | Default for logged-in users in the targeted policy (not restricted much) |
| | `user_t`, `staff_t`, `sysadm_t` | Confined users: unprivileged / can `sudo` to admin / administrator |
| | `secadm_t` | Security administrator (MLS setups) |
| Remote / security | `sshd_t` | OpenSSH server |
| | `firewalld_t` | firewalld |
| | `fail2ban_t` | fail2ban |
| | `policykit_t` | polkitd |
| Logging | `syslogd_t` | rsyslogd and journald |
| | `auditd_t` | auditd: writes AVC denials to `/var/log/audit/audit.log` |
| | `logrotate_t` | logrotate |
| Servers | `httpd_t` | Apache **and nginx** (`/usr/sbin/httpd`, `/usr/sbin/nginx`) |
| | `mysqld_t` | MySQL/MariaDB (`/var/lib/mysql`) |
| | `postfix_master_t` | Postfix (`/usr/libexec/postfix/master`) |
| Virtualization | `virtd_t` | libvirtd |
| | `svirt_t`, `svirt_tcg_t` | Individual VMs (KVM / TCG), separated by MCS categories |
| | `container_t`, `container_runtime_t` | Podman/Docker containers / the container engine (from `container-selinux`) |

There's no `shell_t` domain: shells run in the user's domain (for example `unconfined_t` or `staff_t`), and `shell_exec_t` is the **file** type of `/bin/bash`.

### Example: what a server domain buys you

+ `httpd_t` may read `httpd_sys_content_t` (`/var/www/html`) and write its logs.
  It **can't** read `/etc/shadow` (`shadow_t`), write system binaries, or connect to arbitrary ports
  unless a boolean allows it (`setsebool -P httpd_can_network_connect on`).
  A PHP exploit is limited to what `httpd_t` can do.
+ `mysqld_t` may manage `mysqld_db_t` files in `/var/lib/mysql`, but can't touch home directories or the web root.

This is the same idea as Android's `untrusted_app` vs `system_server`: each program is limited to its own job.

## Related notes

+ [SELinux_intro.md](SELinux_intro.md), [SELinux_policy.md](SELinux_policy.md), [SELinux_DomainTran.md](SELinux_DomainTran.md)
+ [sharedUserId.md](sharedUserId.md): why system-UID apps (`system_app`) are being phased out

## Reference

+ [`seapp_contexts` and app domains (system/sepolicy)](https://android.googlesource.com/platform/system/sepolicy/+/refs/heads/main/private/seapp_contexts)
+ [SELinux concepts (AOSP)](https://source.android.com/docs/security/features/selinux/concepts)
+ [Red Hat: Using SELinux (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/)
