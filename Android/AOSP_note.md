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

## Soong and Ninja 

In the Android Open Source Project (AOSP), building a massive operating system requires tools  
that can handle tens of millions of lines of code efficiently.  
**Soong and Ninja** are 2 core parts of the modern AOSP build architecture that replaced the old, slow GNU Make system.

### What is Soong?

+ The Role: **Soong** is Google's primary modern build system for Android, written in **Go**.  
+ How it works: It reads declarative build configuration files named **Android.bp** (which replaced the old Android.mk makefiles).
+ What it outputs: Soong doesn't actually compile your C++, Java, or Rust files itself.  
  Instead, **it parses the Android.bp tree**, resolves module dependencies, and generates low-level instructions for **Ninja**  
  (specifically a massive file named build.ninja).

### What is Ninja?

+ The Role: Ninja is a small, hyper-fast, low-level execution engine.
+ How it works: **Think of Ninja as an "assembler" for build graphs.**  
  It doesn't use a high-level programming language or logic;  
  it only reads text manifest files (.ninja files) that explicitly list every single file, dependency, and command required to build the project.
+ What it does: Ninja evaluates dependencies and schedules parallel compilation jobs (-j16, etc.) across your CPU cores  
  as fast as physically possible, monitoring file modification times (mtime) to handle incremental builds.

### How They Work Together in AOSP

When you run a build command like m (or make) in your terminal, an orchestrator called soong_ui runs a multi-stage pipeline:

1. Soong Phase: Soong parses all **Android.bp** files across the entire SDK repository  
   and compiles them into Ninja build manifest files (out/soong/build.ninja).  
2. Kati Phase (Legacy bridge): If your SDK still uses older parts written in legacy makefiles (Android.mk),  
   a tool called Kati translates those into Ninja manifests as well.
3. Ninja Execution Phase: Ninja takes all combined manifest files, builds a massive dependency graph,  
   and kicks off the actual compilation of binaries, libraries, and system images (system.img, boot.img, etc.).
