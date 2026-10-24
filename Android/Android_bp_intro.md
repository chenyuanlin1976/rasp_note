# introduce Android.bp

An `Android.bp` file (short for Android **Blueprint**) is a configuration file  
used in the Android Open Source Project (AOSP) to build software components.
It serves as the core input format for Soong, Android’s modern, high-performance build system.  
Google introduced Android.bp files to completely replace the legacy, slow GNU Makefiles (`Android.mk`).

## 1. Key Characteristics of Android.bp Files

+ Declarative and JSON-like: Unlike Makefiles, which allow arbitrary shell scripting and complex procedural logic,  
  Android.bp files are strictly declarative. They describe what to build, not how to build it.
+ No Conditionals: To keep builds fast and deterministic, Android.bp files do not support conditional logic (if/else statements).  
  Any complex environment checks or conditional configurations are handled by business logic written in Go inside the Soong build engine itself.
+ Similar to Bazel: The layout, typing, and syntax closely mirror Bazel (BUILD files),  
  making it familiar to developers working with modern Google build infrastructure.

## 2. Basic Anatomy of an Android.bp File

Every Android.bp file consists of modules.  
A module starts with a module type followed by a set of properties in a name: "value" format.

```json
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

    stl: "c++_shared",
}
```

## Common Module Types:

+ `cc_binary`/ `cc_library`: For compiling C/C++ executables and shared/static libraries.
+ `android_app`: For building APKs.
+ `java_library`: For building Java/Kotlin JAR libraries.
+ `filegroup`/ `genrule`: For grouping specific source files or running custom generation scripts.

## 3. Core Features & Syntax Rules

+ **Strong Typing**: Properties are strictly typed (Booleans, integers, strings, lists of strings, and maps).
+ **Variables**: You can declare top-level variables to keep files clean, and append to them using the `+=` operator:

```json
common_srcs = [
    "foo.cpp",
    "bar.cpp",
]

cc_library {
    name: "libexample",
    srcs: common_srcs + ["extra.cpp"],
}
```

+ Globbing: File lists can use wildcards, including recursive globbing (**):  
  `srcs: ["src/**/*.java"],`
+ Defaults Modules: You can group shared configuration properties into a `cc_defaults` (or equivalent) module  
  and inherit from it to avoid code duplication across multiple targets:

```json
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

## 4. How the Build Pipeline Works with Android.bp

When you run a build command (like `m`), Android uses a multi-stage execution pipeline:

1. Blueprint to Soong: Soong parses all Android.bp files across the AOSP source tree.
2. Soong Generation: Soong resolves dependencies, handles module inheritance,  
   and translates the high-level declarative Android.bp configurations into low-level Ninja build files (build.ninja).
3. Ninja Execution: Ninja executes the actual compiler commands (GCC/Clang, javac, etc.) with extreme speed and precise dependency tracking.
