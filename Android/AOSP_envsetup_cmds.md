# AOSP shell helpers from `envsetup.sh`

`source build/envsetup.sh` adds shell functions for building, navigating, and searching the AOSP tree.
Most of them need a target selected with `lunch` first. The download and full-build steps are in [AOSP_build.md](AOSP_build.md).

```shell
source build/envsetup.sh
lunch aosp_cf_x86_64_only_phone-aosp_current-userdebug    # <product>-<release>-<variant>
hmm                                                       # list the helpers with a short description
```

In current AOSP, most helpers are scripts in `build/soong/bin/`, and `envsetup.sh` puts that directory on `PATH`.
Only the functions that must change the current shell (`lunch`, `croot`, `godir`, `gomod`, ...) remain in `envsetup.sh`.
The list below is from `hmm` on the AOSP `main` branch. Older trees, and vendor SDKs based on them, may lack a few helpers.

## 1. Build

| Command | Builds |
| --- | --- |
| `m [<target> ...]` | From the top of the tree, run from any directory. No argument: the default target (`droid`, all images). Otherwise a module or a phony target |
| `mm` | All modules in the **current directory**, and their dependencies |
| `mmm <dir> [<dir> ...]` | All modules in the given directories. `mmm <dir>/:<mod1>,<mod2>` builds only those modules |
| `mma`, `mmma` | Today the same as `mm` and `mmm`. In old Make-based trees they also built everything that depended on the directory |

```shell
m Settings                                # one module (the name in Android.bp, not the directory)
m systemimage                             # only system.img; also vendorimage, bootimage, ...
m installclean                            # delete installed files and images, keep intermediates (Soong also does this when the product or variant changes)
mmm packages/apps/Settings
cd hardware/interfaces/light && mm
```

The partial builds (`m <module>`, `mm`, `mmm`) still run Soong over the whole tree, so they aren't much faster to start.
They don't rebuild the images: install the new files with `adb sync`, or rebuild the image with `m`.

### 1.1 Push a rebuilt module to a `userdebug` device

```shell
m Settings
adb root && adb disable-verity && adb reboot     # disable-verity only once per device
adb root && adb remount                         # /system, /vendor, ... writable
adb sync                                        # copy changed files from $ANDROID_PRODUCT_OUT
adb reboot                                      # or: adb shell stop && adb shell start
```

`syswrite` runs the root / disable-verity / reboot / remount sequence. `installmod <module>` runs `adb install` on a module's APK.
More on `adb root` and `adb remount`: [adb_intro.md](adb_intro.md#5-reboot-root-remount).

## 2. Navigate

| Command | Does |
| --- | --- |
| `croot [<subdir>]` | `cd` to the top of the tree, or to a directory below it (`croot frameworks/base`) |
| `gomod <module>` | `cd` to the directory that defines a module |
| `pathmod <module>` | Print that directory |
| `outmod <module>` | Print the module's installed output files |
| `dirmods <dir>` | List the modules defined in a directory and below |
| `allmod` | List all modules |
| `refreshmod` | Rebuild `module-info.json`, which the `*mod` helpers read. Run it after adding or renaming modules |
| `godir <regex>` | `cd` to the directory of a file that matches. The first run indexes the whole tree into a `filelist` file |

## 3. Search

These helpers run `find` and `grep` in the **current directory** and below, skipping `out/`, `.repo/`, and `.git/`.
Run them in a subdirectory: from the top of the tree they read the whole source and are slow.

| Command | Files searched |
| --- | --- |
| `cgrep` | C/C++ (`*.c`, `*.cc`, `*.cpp`, `*.h`, ...) |
| `jgrep`, `ktgrep` | Java / Kotlin |
| `resgrep` | `res/*.xml` resources |
| `mangrep` | `AndroidManifest.xml` |
| `mgrep` | Build files: Makefiles (`*.mk`) and `*.bp` |
| `sepgrep` | SELinux policy (`sepolicy/`) |
| `rcgrep` | init `*.rc` files |
| `ggrep`, `gogrep`, `pygrep`, `rsgrep`, `jsongrep`, `tomlgrep` | Gradle, Go, Python, Rust, JSON, TOML |
| `owngrep` | `OWNERS` files |
| `sgrep` | All source files (C/C++, Java, Kotlin, XML, ...) |

```shell
cd frameworks/base && jgrep -n "LightsManager"
cd device/myco/myboard && mgrep "PRODUCT_PACKAGES"
```

## 4. Build configuration

```shell
printconfig                         # PLATFORM_VERSION, TARGET_PRODUCT, TARGET_RELEASE, TARGET_BUILD_VARIANT, OUT_DIR, ...
get_build_var TARGET_PRODUCT        # one build variable
get_build_var PRODUCT_OUT           # out/target/product/<device> (relative)
echo "$ANDROID_BUILD_TOP" "$ANDROID_PRODUCT_OUT"   # top of the tree, image output directory ($OUT is the same)
```

`tapas` and `banchan` select a target for building unbundled apps (APKs) and APEX modules without a full device product.

## Related notes

+ [AOSP_build.md](AOSP_build.md), [AOSP_build_system.md](AOSP_build_system.md), [Android_bp_intro.md](Android_bp_intro.md)
+ [Googles_Repo.md](Googles_Repo.md): `repo forall`, `repo status` across all projects
+ [adb_intro.md](adb_intro.md)

## Reference

+ [Build Android (AOSP)](https://source.android.com/docs/setup/build/building)
+ [`envsetup.sh`](https://android.googlesource.com/platform/build/+/main/envsetup.sh) and [`build/soong/bin/`](https://android.googlesource.com/platform/build/soong/+/main/bin/) (source of the helpers and of `hmm`)
