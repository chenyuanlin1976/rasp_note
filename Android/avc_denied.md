# avc: denied

An **AVC (Access Vector Cache) denial** means SELinux blocked a process from doing something to an object,
because no `allow` rule permits it.
The kernel logs the denial, and the system call fails, usually with `EACCES` ("Permission denied").
For background, see [SELinux_intro.md](SELinux_intro.md).

## 1. Read the denial

```text
avc: denied { write } for comm="mydaemon" name="brightness" dev="sysfs" ino=24617
    scontext=u:r:mydaemon:s0 tcontext=u:object_r:sysfs:s0 tclass=file permissive=0
```

| Field | Meaning |
| --- | --- |
| `{ write }` | The permission(s) that were denied |
| `comm=`, `name=`, `path=`, `dev=`, `ino=` | The process name, and the object's name/path, filesystem, and inode |
| `scontext` | **Source**: the domain of the process (`mydaemon`) |
| `tcontext` | **Target**: the label of the object (`sysfs`) |
| `tclass` | Object class (`file`, `dir`, `chr_file`, `binder`, `service_manager`, `property_service`, ...) |
| `permissive=0` / `1` | `0`: it was **blocked**; `1`: only logged (the domain or the device is permissive) |

This example reads as: "`mydaemon` tried to `write` a `file` labeled `sysfs`".
The rule that would allow it is `allow mydaemon sysfs:file write;`, but that is **not** the right fix (see section 3).

## 2. Find denials on Android

```shell
adb shell dmesg | grep 'avc: denied'           # kernel log
adb logcat -d | grep 'avc: denied'             # logd copies audit messages into logcat
adb shell getenforce                           # Enforcing / Permissive
adb shell ps -AZ | grep mydaemon               # confirm the process domain
adb shell ls -Z /sys/class/leds/red/brightness # confirm the object label
```

Some denials are hidden by `dontaudit` rules.
If something fails with "Permission denied" and nothing is logged, check the DAC owner and mode first.

## 3. Choose the right fix

Work through these questions **in order**. `audit2allow` only answers the last one.

1. **Is the target label too generic?**
   For example `tcontext` is `sysfs`, `device`, `vendor_file`, `default_prop`, `proc`, or `unlabeled`.
   Then give the object a **specific label**, and allow that label:
   + files: `file_contexts`
   + sysfs/proc: `genfs_contexts`
   + properties: `property_contexts`
   + services: `service_contexts`
2. **Is the source domain wrong?**
   For example `scontext` is `init`, `vendor_init`, or `shell`, when you expected your daemon.
   Then the domain transition is missing; see [SELinux_DomainTran.md](SELinux_DomainTran.md).
3. **Is the source a normal app** (`untrusted_app`, `priv_app`, ...)?
   Then don't grant hardware or system access to the app.
   Put the access in a HAL or system service, and let the app call it over Binder
   (see [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md) and [neverallow_error.md](neverallow_error.md)).
4. **Is it a legitimate need of this domain?**
   Then add the **minimal** rule to that domain's `.te` file, using macros:

   ```text
   # vendor/.../sepolicy/vendor/mydaemon.te
   allow mydaemon sysfs_my_led:file rw_file_perms;
   ```

Generate candidate rules on the host, then review them:

```shell
adb shell dmesg | grep avc | audit2allow -p $OUT/vendor/etc/selinux/precompiled_sepolicy
```

If the new rule breaks a `neverallow`, the build fails. That means the design is wrong, not the `neverallow`.

## 4. Test

```shell
m selinux_policy          # or a full build; then flash/sync the vendor (and odm) images
adb shell dmesg -c > /dev/null    # clear the log (root on userdebug), then repeat the action
adb shell dmesg | grep 'avc: denied'
```

While you bring up a new domain, use `permissive mydaemon;` in its `.te` file, or `adb shell setenforce 0` on userdebug.
Then you see *all* the denials at once instead of one per run.
Remove it before release: user builds must be enforcing.

## 5. Desktop Linux (Fedora/RHEL) equivalents

| Task | Command |
| --- | --- |
| Find recent denials | `sudo ausearch -m AVC -ts recent` (or `/var/log/audit/audit.log`) |
| Explain them | `sudo ausearch -m AVC -ts recent \| audit2why`, or `sealert -a /var/log/audit/audit.log` (setroubleshoot) |
| Fix a label persistently | `sudo semanage fcontext -a -t httpd_sys_content_t '/srv/www(/.*)?'` then `sudo restorecon -Rv /srv/www` |
| Temporary label (lost on relabel) | `chcon -t httpd_sys_content_t file`: only for testing |
| Toggle an existing feature | `getsebool -a \| grep httpd`, `sudo setsebool -P httpd_can_network_connect on` |
| Local policy module (last resort) | `sudo ausearch -m AVC -ts recent \| audit2allow -M myfix` → review `myfix.te` → `sudo semodule -i myfix.pp`; check with `semodule -l \| grep myfix` |

On desktop Linux, check for a **boolean** or a wrong **label** before you write a custom module.

## Related notes

+ [SELinux_policy.md](SELinux_policy.md), [SELinux_DomainTran.md](SELinux_DomainTran.md), [neverallow_error.md](neverallow_error.md)

## Reference

+ [Validating SELinux (AOSP)](https://source.android.com/docs/security/features/selinux/validate)
+ [Red Hat: Troubleshooting problems related to SELinux](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/troubleshooting-problems-related-to-selinux_using-selinux)
