# AOSP note

## build type

| Variant | Description |
|--|--|
| user | ro.debuggable=0; adb is disabled by default |
| user-debug | ro.debuggable=1; adb is enabled by default |
| eng | ro.debuggable=1; adb is enabled by default; ro.secure=0 |

[Ref](https://source.android.com/docs/setup/create/new-device)

## SELinux: Security Enhanced Linux

SELinux, is a mandatory access control (MAC) system for the Linux operating system.  
A MAC system consults a central authority for a decision on all access attempts.

Ttraditional linux is discretionary access control (DAC) environments.  
In a DAC system, a concept of ownership exists, whereby an owner of a particular resource controls access permissions associated with it.

[Ref](https://source.android.com/docs/security/features/selinux/concepts)
