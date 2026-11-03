# Bazel

Bazel is Google's open-source build and test tool (the public version of its internal tool Blaze).
It builds large, multi-language code bases from an explicit **dependency graph**,
rebuilds only what changed, and can share results through a cache.
`BUILD` file syntax (Starlark) is in [Bazel_syntax.md](Bazel_syntax.md).

## 1. Key ideas

+ **Explicit dependencies**: every target lists its sources and dependencies. Bazel builds the graph and runs independent actions in parallel.
+ **Incremental and cached**: an action reruns only when its inputs change (content hashes, not timestamps).
  Results can come from a local disk cache or a shared remote cache, and actions can run on remote executors.
+ **Sandboxing / hermeticity**: actions run in a sandbox that exposes only the declared inputs, so undeclared dependencies fail.
  Builds are reproducible only if the **toolchains** are pinned too.
  An auto-detected host C++ compiler, for example, makes the output depend on the machine.
+ **Multi-language through rule sets**: C/C++, Java, Python, Go, Rust, ... are supported by rule sets
  (`rules_cc`, `rules_java`, `rules_python`, `rules_go`, `rules_rust`).
  Recent Bazel versions move even the C++/Java/Python rules out of the core into these modules, so `BUILD` files `load()` them.

## 2. Workspace layout

```text
my_project/
├── MODULE.bazel          # root of the workspace: module name + external dependencies (Bzlmod)
├── .bazelversion         # Bazel version, used by Bazelisk
├── .bazelrc              # default flags
├── app/
│   ├── BUILD.bazel       # package //app
│   └── main.cc
└── lib/math/
    ├── BUILD.bazel       # package //lib/math
    ├── math_utils.cc
    └── math_utils.h
```

+ The **workspace** is the directory tree with `MODULE.bazel` at its root.
+ A **package** is a directory that contains a `BUILD` or `BUILD.bazel` file, plus its subdirectories without their own `BUILD` file.
+ A **target** is something defined in a `BUILD` file (a rule instance) or a source file. It's addressed by a **label**: `//lib/math:math_utils`.

```python
# MODULE.bazel
module(name = "my_project", version = "0.1.0")

bazel_dep(name = "rules_cc", version = "0.1.1")      # versions come from the Bazel Central Registry
bazel_dep(name = "googletest", version = "1.15.2", dev_dependency = True)
```

External dependencies are declared with **Bzlmod** (`MODULE.bazel`), the default since Bazel 7.
The older `WORKSPACE` file is legacy and is being removed. Old projects and tutorials still use it.

## 3. Everyday commands

```shell
bazel build //app:calculator                # build one target
bazel build //...                           # build everything in the workspace
bazel run //app:calculator -- --verbose     # build and run (arguments after --)
bazel test //lib/... --test_output=errors   # run tests below //lib
bazel query 'deps(//app:calculator)'        # dependency graph
bazel query 'rdeps(//..., //lib/math:math_utils)'   # who depends on a target
bazel clean                                 # remove outputs (--expunge: also the cache)
```

+ Outputs go to `bazel-bin/`, `bazel-out/`, ... (symlinks into Bazel's output base, outside the source tree).
+ Use **Bazelisk** as the `bazel` command. It downloads the version named in `.bazelversion`, so everyone builds with the same Bazel.

## 4. Bazel in Android

| Area | Build system |
| --- | --- |
| AOSP platform (system, vendor, apps in the tree) | **Soong** (`Android.bp`) + Ninja. Not Bazel. See [Android_bp_intro.md](Android_bp_intro.md) |
| Android kernels (GKI and device kernels) | **Kleaf**, Bazel-based, since **Android 13**. `build/build.sh` isn't supported for Android 14 and later |
| Android apps (Android Studio) | Gradle. Bazel's `rules_android` exists, but it's used mainly in large monorepos |

Earlier plans to migrate the whole AOSP platform build from Soong to Bazel were stopped. `Android.bp` stays.
Its syntax looks like Bazel's (rule-like module types with `name = ...` attributes), but it is a different tool.

Build the GKI kernel with Kleaf (in an Android Common Kernel checkout, Android 13 or later):

```shell
tools/bazel run //common:kernel_aarch64_dist -- --destdir=$DIST_DIR
```

`tools/bazel` is the Bazel wrapper that ships with the kernel tree, together with prebuilt toolchains.
Device kernels and vendor modules (DDK) use the same system.

## Related notes

+ [Bazel_syntax.md](Bazel_syntax.md): `BUILD` files and Starlark
+ [Android_bp_intro.md](Android_bp_intro.md), [AOSP_build.md](AOSP_build.md), [AOSP_build_system.md](AOSP_build_system.md)

## Reference

+ [Bazel documentation](https://bazel.build/docs)
+ [External dependencies and Bzlmod](https://bazel.build/external/overview)
+ [Building kernels (AOSP, Kleaf)](https://source.android.com/docs/setup/build/building-kernels)
+ [Kleaf documentation (kernel/build)](https://android.googlesource.com/kernel/build/+/refs/heads/main/kleaf/README.md)
