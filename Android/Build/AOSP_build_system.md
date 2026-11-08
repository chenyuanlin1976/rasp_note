# AOSP build system: variants, Soong, Kati, Ninja

How an AOSP build is configured and executed. The download and build steps are in [AOSP_build.md](AOSP_build.md),
and `Android.bp` syntax is in [Android_bp_intro.md](Android_bp_intro.md).

## 1. Build variants

The variant is the last part of the `lunch` target (`<product>-<release>-<variant>`):

| Variant | Installs | Properties | adb |
| --- | --- | --- | --- |
| `user` | Product modules + modules tagged `user` | `ro.secure=1`, `ro.debuggable=0` | Disabled by default |
| `userdebug` | Like `user`, plus modules tagged `debug` | `ro.secure=1`, `ro.debuggable=1` | Enabled by default; `adb root` works |
| `eng` | Plus modules tagged `eng` and `debug` | `ro.secure=0`, `ro.debuggable=1`, `ro.kernel.android.checkjni=1` | Enabled by default |

+ **`user`** is what ships. **`userdebug`** behaves like `user` (performance, SELinux enforcing) but allows root and debugging,
  so it's the usual choice for development and testing on real hardware.
  **`eng`** adds extra tools and checks and is slower.
+ Check on a device: `adb shell getprop ro.build.type`.

## 2. From `m` to images

```text
m  ->  soong_ui
         1. Soong: reads all Android.bp files (Blueprint syntax)  -> out/soong/build.*.ninja
         2. Kati:  product configuration (device.mk, BoardConfig.mk) and remaining Android.mk files -> *.ninja
         3. Ninja: runs the combined graph -> binaries, APKs, system.img, vendor.img, boot.img, ...
```

| Tool | What it is | Inputs |
| --- | --- | --- |
| **Soong** | The main build system, written in Go (since Android 7). Generates Ninja files, compiles nothing itself | `Android.bp` |
| **Kati** | A fast GNU Make clone that translates Makefiles into Ninja files | `*.mk`: **product and board configuration** (still Make syntax), and legacy `Android.mk` modules |
| **Ninja** | A small build executor: runs commands in dependency order and in parallel; rebuilds by file modification time | Generated `.ninja` files |

`Android.mk` modules are deprecated in favor of `Android.bp`.
But `device.mk`, `BoardConfig.mk`, and `AndroidProducts.mk` are still Make files, so Kati remains part of every build.

## 3. Parallel jobs

+ `m` already runs about as many jobs as there are CPU threads. `m -jN` sets the number.
+ Each C++ or Java/R8 job can use several GB of RAM. If the build fails with "killed" / out-of-memory errors or starts swapping,
  **lower** `-j` instead of raising it. 64 GB of RAM is the documented minimum for a full build.
+ Outside AOSP: `make -jN`, `ninja -jN`, `cmake --build . --parallel N`. Avoid `make -j` without a number: it starts unlimited jobs.

## 4. Vendor SDK trees kept in one Git repository

SoC vendors' SDKs (for example Rockchip's RK3566 Android SDK) are sometimes shipped or kept as one big Git repository.
If build outputs were committed by mistake, adding them to `.gitignore` isn't enough, because Git keeps tracking files it already tracks:

```shell
printf 'out/\nrockdev/\n.repo/\n' >> .gitignore
git rm -r --cached out/ rockdev/ .repo/     # stop tracking; the files stay on disk
git commit -m "untrack build outputs."
```

`git rm -r --cached .` followed by `git add .` re-indexes the whole tree. It works, but it is slow for an SDK-sized repository,
and the commit shows every file whose line endings or mode change.

## Related notes

+ [AOSP_build.md](AOSP_build.md), [Android_bp_intro.md](Android_bp_intro.md), [AOSP_envsetup_cmds.md](AOSP_envsetup_cmds.md)
+ [Googles_Repo.md](Googles_Repo.md), [Bazel_intro.md](Bazel_intro.md)
+ [../SELinux/SELinux_intro.md](../SELinux/SELinux_intro.md): SELinux (MAC vs DAC) on Android

## Reference

+ [Build variants (AOSP)](https://source.android.com/docs/setup/create/new-device)
+ [Soong build system](https://source.android.com/docs/setup/build)
+ [Android.bp file format](https://source.android.com/docs/setup/reference/androidbp)
+ [Ninja manual](https://ninja-build.org/manual.html)
