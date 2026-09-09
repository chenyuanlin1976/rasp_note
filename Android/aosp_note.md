# AOSP note

## build type

| Variant    | Description                                             |
| ---------- | ------------------------------------------------------- |
| user       | ro.debuggable=0; adb is disabled by default             |
| user-debug | ro.debuggable=1; adb is enabled by default              |
| eng        | ro.debuggable=1; adb is enabled by default; ro.secure=0 |

[Ref](https://source.android.com/docs/setup/create/new-device)

## SELinux: Security Enhanced Linux

SELinux, is a mandatory access control (MAC) system for the Linux operating system.  
A MAC system consults a central authority for a decision on all access attempts.

Ttraditional linux is discretionary access control (DAC) environments.  
In a DAC system, a concept of ownership exists, whereby an owner of a particular resource controls access permissions associated with it.

[Ref](https://source.android.com/docs/security/features/selinux/concepts)

## git tips

+ To make your `.gitignore` changes work, you must untrack the files that Git is already tracking.
  + Unstage and untrack everything: `git rm -r --cached .`
    Run the command to clear Git's cache/index.  
    Do not worry - this will not delete any files from your actual hard drive.  
    It only stops Git from tracking them.
  + specify the folder:`git rm -r --cached out/ .repo/ rockdev/`

## Parallel compilation jobs

Parallel compilation jobs run multiple compiler tasks at the same time to reduce total build time.

### How It Works

+ Core Utilization: Instead of compiling one source file after another,  
  the build system uses multiple CPU cores or threads.
+ Speed Improvement: Building large projects takes a fraction of the time compared to single-threaded compilation.

### Common Commands and Flags

+ GNU Make: Use the -j flag followed by the number of jobs  
  (for example, make -j4 for 4 jobs or make -j for unlimited).
+ CMake / Ninja: Use --parallel or -j followed by the job count (like cmake --build . --parallel 4).
+ Visual Studio / MSBuild: Use /m for parallel project builds and /MP for multi-processor compilation on individual files.

### Best Practices

+ Job Count Rule: Set the job count to the number of physical CPU cores, or up to the number of logical threads (cores × 1.5)  
  to maximize speed without overloading system memory.
+ Memory Limits: Running too many parallel jobs can consume all available RAM, causing the system to slow down or crash due to swapping.
