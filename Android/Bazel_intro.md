# Bazel introduction

## Part 1: Understanding Bazel and BUILD.bazel

### What is Bazel?

Bazel is an open-source, fast, scalable build and test system created by Google (derived from its internal tool, Blaze).  
It is designed to handle massive codebases with complex dependency graphs efficiently.  
Key design philosophies of Bazel include:

+ Hermetic and Reproducible Builds: Bazel ensures that builds are isolated from the host system environment,  
  meaning the same source code will always produce the exact same output binary regardless of the machine building it.
+ Incremental Caching: It tracks inputs and outputs meticulously, only recompiling what has actually changed.
+ Multi-Language Support: It natively builds C++, Java, Python, Go, Rust, and more.

### What is a BUILD.bazel file?

A BUILD.bazel (or simply BUILD) file is a plain text script placed inside project directories  
to tell Bazel **how to build software components within that directory**.  
It uses Starlark, a safe, restricted subset of Python.  
Inside a BUILD.bazel file, you define targets using rules.

+ Rules: Functions that define how to transform a set of input files into output files  
  (e.g., compiling C++ code, packaging an archive, or building a kernel).  
  Examples include cc_library, java_binary, or custom-written macros.
+ Targets: Specific instances of rules. For example, a target might be a specific C++ library module.
+ Dependencies (deps): Explicitly declared links between targets,  
  letting Bazel know which targets must be built before another can start.

### Example of a BUILD.bazel file

```python
package(default_visibility = ["//visibility:public"])

cc_library(
    name = "math_utils",
    srcs = ["math_utils.cc"],
    hdrs = ["math_utils.h"],
)

cc_binary(
    name = "calculator",
    srcs = ["main.cc"],
    deps = [
        ":math_utils",
    ],
)
```

### Bazel's Role in Android (AOSP)

While core AOSP traditionally uses Soong (Android.bp files) combined with Ninja for platform compilation,  
Bazel plays a crucial role in modern Android development -  
most notably powering Kleaf, the Bazel-based build framework for building Android kernels starting from Android 13.

## Part 2: How to Compile AOSP (Android Open Source Project)

Compiling the full AOSP source tree requires a heavy-duty Linux workstation, substantial disk space, and patience.

### Step 1: System Requirements & Preparation

+ Operating System: Linux (Ubuntu LTS 20.04/22.04 or compatible distributions are standard).
+ Hardware:
  + At least 64GB of RAM (compilation is extremely memory-intensive).
  + 300 GB to 500 GB of free disk space (preferably on a fast NVMe SSD).
+ Packages Installation: Install essential build tools (Git, Python, OpenJDK, GNU Make, etc.).

### Step 2: Install the Repo Tool

Google uses **repo** to manage multiple Git repositories within AOSP.

```bash
mkdir -p ~/.bin
PATH="${HOME}/.bin:${PATH}"
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
chmod a+rx ~/.bin/repo
```

### Step 3: Download the AOSP Source Tree

1. Create a working directory: `mkdir aosp && cd aosp`
2. Initialize the repository (replace <branch-name> with your desired branch,  
   e.g., main or a specific release tag like android-14.0.0_r20):  
   `repo init -u https://android.googlesource.com/platform/manifest -b <branch-name>`
3. Sync the source code (this will download tens of gigabytes and may take hours depending on your internet connection):
   `repo sync -c -j8`

### Step 4: Set Up the Build Environment

Initialize the environment variables and target definitions using the built-in envsetup script:  
`source build/envsetup.sh`

### Step 5: Select a Build Target

Use the lunch command to choose which device architecture or emulator target you want to build for  
(e.g., aosp_arm64-userdebug for a generic 64-bit ARM device configuration):  
`lunch aosp_arm64-userdebug`

### Step 6: Start Compilation

Trigger the build using the m command. The -j flag tells Make/Soong how many parallel threads to spawn  
(match this to your CPU core count): `m -j$(nproc)`

### Step 7: Locate Output Images

Once the build completes successfully, you will find the compiled images  
(such as boot.img, system.img, and userdata.img) inside the `out/target/product/<device_name>/` directory.  
You can flash these onto a physical reference device or run them inside the Android Emulator (emulator).
