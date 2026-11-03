# Download and build AOSP

The steps follow source.android.com (current as of 2026). AOSP is built with Soong (`Android.bp`) and Ninja, not Bazel.
For the build system itself, see [AOSP_note.md](AOSP_note.md) and [Android_bp_intro.md](Android_bp_intro.md).

## 1. Requirements

| Item | Requirement |
| --- | --- |
| CPU / OS | 64-bit x86 Linux. Ubuntu 18.04 or later for Android 11+ (current LTS releases are typical) |
| Disk | At least **400 GB** free: about 250 GB for the checkout + 150 GB for the build (more for several targets) |
| RAM | At least **64 GB** |
| Time | Google's 72-core / 64 GB machines: about 40 min for a full build. A 6-core machine: about 6 h |

```shell
sudo apt-get install git-core gnupg flex bison build-essential zip curl zlib1g-dev libc6-dev-i386 \
    x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig
```

## 2. Install `repo`

```shell
mkdir -p ~/.bin
export PATH="$HOME/.bin:$PATH"            # add this line to ~/.bashrc as well
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
chmod a+rx ~/.bin/repo
```

How `repo` works (manifests, `repo sync`, `repo upload`): [Googles_Repo.md](Googles_Repo.md).

## 3. Download the source

```shell
mkdir aosp && cd aosp
repo init --partial-clone --no-use-superproject \
    -b android-latest-release -u https://android.googlesource.com/platform/manifest
repo sync -c -j8
```

+ AOSP now publishes source in releases (Q2 and Q4), and **`android-latest-release`** always points to the newest one.
  For a specific version, use a tag such as `android-14.0.0_rNN` (list: "Source code tags and builds").
+ `--partial-clone` downloads history on demand and saves a lot of space. `-c` fetches only the current branch.
+ An SoC vendor's SDK (for example Rockchip's RK3566 Android SDK) has its own manifest and branches. Use theirs for a board.

## 4. Build

```shell
source build/envsetup.sh                                  # defines lunch, m, mm, croot, ...
lunch aosp_cf_x86_64_only_phone-aosp_current-userdebug    # <product>-<release>-<variant>
m                                                          # parallel by default; m -jN to limit
```

+ The `lunch` target is **`<product>-<release config>-<variant>`** on current releases.
  Older releases used `<product>-<variant>`, for example `aosp_arm64-userdebug`.
  Run `lunch` without arguments to list targets.
+ Variants: `user` (production), `userdebug` (production-like, with root/debugging), `eng` (development); see [AOSP_note.md](AOSP_note.md).
+ `m` already runs as many jobs as there are CPUs. Lower it (`m -j16`) if the machine runs out of memory.
+ Partial builds: `m <module>`, `mm` (current directory), `mmm <dir>`; see [AOSP_build_helplerCmds.md](AOSP_build_helplerCmds.md).

## 5. Results

Images are in `out/target/product/<device>/`: `system.img`, `vendor.img`, `boot.img`, `super.img` (dynamic partitions), ...

```shell
launch_cvd                           # Cuttlefish virtual device (aosp_cf_* targets)
emulator                             # Android Emulator (sdk_phone* / emulator targets)
adb reboot bootloader && fastboot flashall -w    # physical device with a matching target
```

## Related notes

+ [Googles_Repo.md](Googles_Repo.md), [AOSP_note.md](AOSP_note.md), [AOSP_build_helplerCmds.md](AOSP_build_helplerCmds.md), [Android_bp_intro.md](Android_bp_intro.md)
+ [Bazel_intro.md](Bazel_intro.md): Bazel/Kleaf for Android kernels
+ [verify_platformKeys.md](verify_platformKeys.md): release-signing the build

## Reference

+ [Hardware and software requirements](https://source.android.com/docs/setup/start/requirements)
+ [Download the Android source](https://source.android.com/docs/setup/download)
+ [Build Android](https://source.android.com/docs/setup/build/building)
