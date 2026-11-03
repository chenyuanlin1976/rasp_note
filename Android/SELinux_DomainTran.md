# SELinux domain transition

A **domain transition** changes the SELinux domain of a process. It normally happens at `execve()`.
For example, the program `/vendor/bin/mydaemon` is started by `init`, but it shouldn't run with init's powers.
It should **switch to its own narrow domain** (`mydaemon`) when it is executed.

Analogy: a contractor arrives with the building's master key (the parent's domain).
At the door of the server room, they swap it for a key that opens only that room (the dedicated domain).

## 1. Why we need it

+ With DAC alone, a process run as **root** can do almost anything.
  If a root daemon is exploited, the whole system is exposed.
+ SELinux confines root too, but only if the process is in a **dedicated domain** with only the rules it needs (**least privilege**).
+ Without a transition, a child stays in its **parent's domain**.
  It then has either far too many rights (when the parent is `init`) or the wrong rights (when the parent is a shell or app).

## 2. The 3 elements and the rules behind them

| Element | Example (Android) | Where it comes from |
| --- | --- | --- |
| Source domain (the parent process) | `init` | Already running |
| Entry-point **file type** (label of the binary) | `mydaemon_exec` | `file_contexts`: `/vendor/bin/mydaemon u:object_r:mydaemon_exec:s0` |
| Target domain | `mydaemon` | `type mydaemon, domain;` |

A transition on `exec` needs **all** of these rules:

```text
allow init mydaemon_exec:file { getattr open read execute map };  # parent may execute the file
allow init mydaemon:process transition;                            # parent may switch to the new domain
allow mydaemon mydaemon_exec:file { entrypoint open read execute getattr map };  # file is a valid entry point
type_transition init mydaemon_exec:process mydaemon;               # make it automatic (default) on exec
```

Macros generate these rules for you:

```text
# Android (system/sepolicy te_macros)
domain_auto_trans(init, mydaemon_exec, mydaemon)
init_daemon_domain(mydaemon)            # = domain_auto_trans(init, mydaemon_exec, mydaemon) + a few extras

# Desktop Reference Policy
init_daemon_domain(myapp_t, myapp_exec_t)
```

Rule in plain words: "When a process in domain `init` executes a file labeled `mydaemon_exec`, the new process runs in domain `mydaemon`."

## 3. Other ways a process gets its domain on Android

+ **Apps** don't `exec` anything. `zygote` forks, and then calls `selinux_android_setcontext()`.
  It picks the domain and MLS categories from `seapp_contexts`, based on the UID, the signing `seinfo`, the priv-app flag, and the target SDK.
  This is a **dynamic transition** (`setcon()`), allowed by `allow zygote appdomain:process dyntransition`.
+ **`seclabel` in an `.rc` file**: init sets the domain explicitly. This is mainly for binaries on rootfs or `/system` that can't get a proper file label.
  For vendor daemons, use `file_contexts` + `init_daemon_domain` instead.
+ **`runcon`** (debug builds): `adb shell runcon u:r:mydaemon:s0 /vendor/bin/mydaemon` runs a command in a domain to test it. This only works where policy allows it.

## 4. What happens if there's no transition

### Android

+ **Services started by init**: if the binary's label has no transition out of `init`, **init refuses to start the service**.
  It logs a message like this:

  ```text
  init: Service mydaemon does not have a SELinux domain defined.
  ```

  Running things in the `init` domain is forbidden by `neverallow` rules. So on Android you *must* write a domain for every daemon.
+ **A binary run from `adb shell`**: it runs in the `shell` domain, with only the shell's rights.
  It may work in a quick test but fail later when started by init with its real domain.
+ **An unlabeled file** (`u:object_r:unlabeled:s0`, for example after copying a file to `/data` by hand):
  most domains can't execute or even read it. Run `restorecon` to apply `file_contexts`.

### Desktop Linux (Fedora/RHEL targeted policy)

+ **Run from your shell**: it stays in your user domain (usually `unconfined_t`), so it's effectively not restricted by SELinux.
+ **Started by systemd without its own policy**: a binary labeled `bin_t` (for example `/usr/bin/myapp`) is put into
  **`unconfined_service_t`** (not `init_t`). It isn't confined, but it doesn't run as `init_t` either.
+ **Binary with a custom type but missing rules**: the transition happens, and then the daemon gets **AVC denials**
  in `/var/log/audit/audit.log` for everything that wasn't allowed.

## 5. Checklist when a daemon is in the wrong domain

```shell
adb shell ls -Z /vendor/bin/mydaemon          # expect u:object_r:mydaemon_exec:s0 (not vendor_file)
adb shell ps -AZ | grep mydaemon              # expect u:r:mydaemon:s0 (not init / shell)
adb shell dmesg | grep -E 'avc|mydaemon'      # missing transition/entrypoint rules show up here
```

+ If the file label is wrong, fix `file_contexts` (the path regex must match), rebuild, and reflash (or run `restorecon`).
+ If the label is right but there is still no transition, check that `init_daemon_domain(mydaemon)` exists and that `mydaemon_exec` has `exec_type`.

## Related notes

+ [SELinux_intro.md](SELinux_intro.md), [SELinux_policy.md](SELinux_policy.md), [SELinux_domains.md](SELinux_domains.md)
+ [avc_denied.md](avc_denied.md)

## Reference

+ [SELinux concepts: domain transitions (AOSP)](https://source.android.com/docs/security/features/selinux/concepts)
+ [`te_macros` (system/sepolicy)](https://android.googlesource.com/platform/system/sepolicy/+/refs/heads/main/public/te_macros)
