# Android.bp (Soong module definitions)

An `Android.bp` file (Android **Blueprint**) describes the modules that the AOSP build system **Soong** builds:
native binaries and libraries, Java libraries, apps, AIDL interfaces, prebuilt files.
`Android.bp` replaced `Android.mk` module definitions starting with Android 7.0.
`Android.mk` still works (through Kati) but is deprecated.

How Soong, Kati, and Ninja fit together is in [AOSP_build_system.md](AOSP_build_system.md).

## 1. Key characteristics

+ **Declarative**: a file only lists modules and their properties. It has no shell commands and no procedural logic,
  unlike Makefiles. Logic lives in Soong itself, written in Go.
+ **No `if`/`else`**: variation between architectures, host/device, or products is expressed with
  special property blocks (section 4). Anything more complex belongs in Go code, not in the `.bp` file.
+ **Bazel-like in spirit**: one file per directory, named modules, explicit dependencies.
  The syntax differs, though: Bazel `BUILD` files are Starlark function calls (see [Bazel_intro.md](Bazel_intro.md)).

## 2. Basic syntax

A module is a module type followed by properties in `name: value` form.

```bp
// Comments use // or /* */. Trailing commas are allowed.
cc_binary {
    name: "my_native_tool",

    srcs: [
        "main.cpp",
        "utils.cpp",
    ],

    shared_libs: [
        "liblog",
        "libcutils",
    ],

    cflags: ["-Wall", "-Werror"],
}
```

+ `name` must be unique in the whole tree (unless you use `soong_namespace`).
+ Dependencies are referenced by module name (`liblog`), not by path.
+ Platform modules use `libc++` as the C++ STL by default. You don't need an `stl` property.
  NDK-style values such as `c++_shared` are only for modules that set `sdk_version`.

### Property types

| Type | Example |
| --- | --- |
| Boolean | `vendor: true` |
| Integer | Supported, but rare in module properties |
| String | `name: "libfoo"` |
| List of strings | `srcs: ["a.cpp", "b.cpp"]` |
| Map (nested property set) | `target: { android: { ... } }` |

Soong checks the types: a string where a list is expected is a build error.

### Variables

Top-level variables hold values that several modules share. Use `+` to concatenate.
`+=` appends to a variable, but only before the variable is first used.

```bp
common_srcs = [
    "foo.cpp",
    "bar.cpp",
]
common_srcs += ["baz.cpp"]

cc_library {
    name: "libexample",
    srcs: common_srcs + ["extra.cpp"],
}
```

### Globs

File lists accept `*` and recursive `**`. `exclude_srcs` removes matches.

```bp
java_library {
    name: "gpio-sdk-lib",
    srcs: ["src/**/*.java"],
    exclude_srcs: ["src/**/test/**/*.java"],
}
```

### Defaults modules

Shared properties go into a `*_defaults` module (`cc_defaults`, `java_defaults`, ...),
and other modules inherit them with `defaults`:

```bp
cc_defaults {
    name: "my_project_defaults",
    cflags: ["-Wall", "-Werror"],
}

cc_library {
    name: "libmylib",
    defaults: ["my_project_defaults"],
    srcs: ["mylib.cpp"],
}
```

## 3. Common module types

| Module type | Builds |
| --- | --- |
| `cc_binary` | Native executable |
| `cc_library`, `cc_library_shared`, `cc_library_static` | Native library (`cc_library` builds both shared and static variants) |
| `java_library` | Java/Kotlin JAR |
| `android_library` | Android library with resources and a manifest (the Soong counterpart of an AAR, see [jar_aar_intro.md](jar_aar_intro.md)) |
| `android_app` | APK |
| `aidl_interface` | AIDL interface with generated Java/C++/NDK/Rust backends (see [AIDL_intro.md](AIDL_intro.md)) |
| `prebuilt_etc` | Installs a file under `etc/`, e.g. a config file or VINTF fragment |
| `filegroup` | Named group of source files that other modules reference as `":name"` |
| `genrule` | Runs a custom command to generate sources |

An app in the tree, for example a system app that exposes a service:

```bp
android_app {
    name: "GpioService",
    srcs: ["src/**/*.java"],
    // AndroidManifest.xml and res/ are taken from the module directory by default
    platform_apis: true,
    certificate: "platform",
    privileged: true,
    system_ext_specific: true,
}
```

Unlike Gradle, Soong has no `namespace` setting; the `package` attribute stays in `AndroidManifest.xml`
(see [AndroidManifest.md](AndroidManifest.md)).

## 4. Variation and install location

### Architecture and target

```bp
cc_library {
    name: "libgpio_helper",
    srcs: ["gpio.cpp"],
    arch: {
        arm64: {
            srcs: ["gpio_arm64.cpp"],
        },
    },
    target: {
        android: {
            shared_libs: ["liblog"],
        },
        host: {
            cflags: ["-DHOST_BUILD"],
        },
    },
    host_supported: true,
}
```

+ `arch: { arm, arm64, x86, x86_64 }` and `target: { android, host, linux, ... }` add or override properties.
+ Product-dependent settings use `soong_config_module_type` together with Soong config variables set from the product makefiles.
  Newer AOSP releases also support `select()` expressions for configurable properties.

### Partition

| Property | Installs to |
| --- | --- |
| (none) | `/system` |
| `system_ext_specific: true` | `/system_ext` |
| `product_specific: true` | `/product` |
| `vendor: true` (or `soc_specific: true`) | `/vendor` |
| `device_specific: true` | `/odm` |

`relative_install_path: "hw"` on a vendor binary installs it in `/vendor/bin/hw/`, the usual place for HAL services
(see [AIDL_HAL_impl.md](AIDL_HAL_impl.md)).

## 5. Tools

| Command | Purpose |
| --- | --- |
| `m <module>` | Build one module (after `source build/envsetup.sh` and `lunch`) |
| `bpfmt -w Android.bp` | Format the file in place |
| `androidmk Android.mk > Android.bp` | Convert a legacy `Android.mk` (check the result by hand) |

More build commands: [AOSP_envsetup_cmds.md](AOSP_envsetup_cmds.md).

## Related notes

+ [AOSP_build_system.md](AOSP_build_system.md), [AOSP_build.md](AOSP_build.md), [AOSP_envsetup_cmds.md](AOSP_envsetup_cmds.md)
+ [Bazel_intro.md](Bazel_intro.md), [Bazel_syntax.md](Bazel_syntax.md)
+ [AIDL_intro.md](AIDL_intro.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md), [native_daemon.md](native_daemon.md)
+ [AndroidManifest.md](AndroidManifest.md), [jar_aar_intro.md](jar_aar_intro.md)

## Reference

+ [Android.bp file format](https://source.android.com/docs/setup/reference/androidbp)
+ [Soong build system](https://source.android.com/docs/setup/build)
+ [Soong README](https://android.googlesource.com/platform/build/soong/+/refs/heads/main/README.md)
