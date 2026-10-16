# Bazel syntax

BUILD.bazel (or BUILD) files are written in **Starlark**, a lightweight, deterministic language inspired by Python.  
While it looks like Python, it has strict limitations designed to ensure builds are fast, parallelizable, and hermetic (reproducible).

## 1. Core Syntax & Structure

A `BUILD.bazel` file consists primarily of `load statements`, `package metadata declarations`, and `build rule targets`.

```python
# 1. Load extensions (.bzl files) if needed
load(":my_rules.bzl", "custom_rule")

# 2. Package-wide settings (optional, must be near the top)
package(default_visibility = ["//visibility:public"])

# 3. Target declarations (rules)
cc_library(
    name = "string_utils",
    srcs = ["string_utils.cc"],
    hdrs = ["string_utils.h"],
)

cc_binary(
    name = "app",
    srcs = ["main.cc"],
    deps = [
        ":string_utils",  # Local target reference
    ],
)
```

## 2. Key Components of a Target

Every target in a `BUILD.bazel` file follows this template.

```python
rule_name(
    name = "target_name",           # Unique identifier within this package
    srcs = ["file1.cc", ...],       # Source files required to build
    deps = ["//some/other:target"], # Dependencies on other targets
    data = ["config.json"],         # Runtime/test data files
)
```

+ **name**: The name of the target. Must be unique within that specific BUILD.bazel file.
+ **srcs**: Source files processed directly by this rule (e.g., .cc, .java, .py).
+ **deps**: Other targets that this target depends on to compile or run.
+ **data**: Files needed at runtime (not compile time), such as configuration files, scripts, or test assets.

## 3. Labels and Targeting Syntax

Bazel uses **Labels** to point to targets, packages, and files.

+ Local Target: ":string_utils" (targets in the current BUILD file).
+ Package-Relative Target: "//code/core:string_utils" (absolute path from the workspace root).
+ Shorthand Target: "//code/core" (equivalent to "//code/core:core" if the target name matches the directory name).

## 4. Starlark vs. Python (Crucial Restrictions)

Because `BUILD.bazel` files are evaluated concurrently,  
**Starlark** is heavily restricted compared to standard Python.

+ No top-level def statements: You cannot define custom functions inside a BUILD.bazel file.  
  (Custom functions/rules must be written in .bzl files and imported via load()).
+ No `for` or `if` statements at the top level: Control flow is restricted.  
  However, list comprehensions and conditional expressions (ternary operators) are allowed:

```python
# Allowed:
srcs = ["main.cc"] + (["debug.cc"] if DEBUG_MODE else [])

# NOT allowed at top-level:
# if DEBUG_MODE:
#     srcs.append("debug.cc")
```

+ No arbitrary I/O: BUILD files cannot read environment variables, access arbitrary local disk paths  
  (outside of safe built-ins like glob()), or make network requests.
+ Immutability: Once a data structure or global variable is initialized,  
  it becomes immutable to prevent race conditions during parallel processing.

## 5. Common Built-in Functions

+ glob(): Dynamically matches files in a directory.

```python
cc_library(
    name = "all_tests",
    srcs = glob(["test_*.cc"]),
    hdrs = glob(["*.h"]),
)
```

+ load(): Imports rules, macros, or constants from a .bzl extension file.  
  Must always be placed at the very top of the file (right after comments).
  `load("@rules_java//java:defs.bzl", "java_binary")`
