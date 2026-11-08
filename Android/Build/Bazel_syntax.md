# Bazel `BUILD` files and Starlark

`BUILD` / `BUILD.bazel` files and `.bzl` extension files are written in **Starlark**, a Python-like language.
It is restricted so that files can be evaluated in parallel and always give the same result.
Concepts, workspace layout, and commands are in [Bazel_intro.md](Bazel_intro.md).

## 1. A `BUILD.bazel` file

```python
# lib/math/BUILD.bazel  ->  package //lib/math
load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")   # load() statements come first

package(default_visibility = ["//app:__pkg__"])            # then package(), then targets

cc_library(
    name = "math_utils",
    srcs = ["math_utils.cc"],
    hdrs = ["math_utils.h"],
)

cc_test(
    name = "math_utils_test",
    srcs = ["math_utils_test.cc"],
    deps = [
        ":math_utils",
        "@googletest//:gtest_main",
    ],
)
```

```python
# app/BUILD.bazel  ->  package //app
load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "calculator",
    srcs = ["main.cc"],
    deps = ["//lib/math:math_utils"],
)
```

## 2. Common attributes

| Attribute | Meaning |
| --- | --- |
| `name` | Target name, unique within the **package** |
| `srcs` | Source files that this rule processes |
| `hdrs` | (C/C++) public headers that dependents may include |
| `deps` | Targets needed to compile/link (libraries) |
| `data` | Files needed at **run time** (configs, test data). They appear in the runfiles tree |
| `visibility` | Which packages may depend on this target. Default: private to the package |
| `testonly` | Only test targets (and other `testonly` targets) may depend on it |
| `tags` | Free-form labels, for example `"manual"` (not built by `//...`) |

`visibility` values: `["//visibility:public"]`, `["//visibility:private"]`, `["//some/pkg:__pkg__"]` (that package),
`["//some/pkg:__subpackages__"]` (that package and below).

## 3. Labels

| Form | Meaning |
| --- | --- |
| `:math_utils` | Target in the **same** package |
| `//lib/math:math_utils` | Absolute label: package `lib/math` in the main repository |
| `//lib/math` | Short for `//lib/math:math` (target named like the last directory) |
| `math_utils.h`, `//lib/math:math_utils.h` | A source file is also a target |
| `@googletest//:gtest_main` | Target in an external repository (apparent name from `MODULE.bazel`) |
| `//lib/...`, `//lib/math:all` | Patterns for the command line: everything below `//lib`, all targets in a package |

## 4. Built-in functions

```python
srcs = glob(["*.cc"], exclude = ["*_test.cc"])      # files in this package (glob doesn't enter subpackages)

copts = select({                                     # value chosen by build configuration
    "@platforms//cpu:arm64": ["-march=armv8-a"],
    "//conditions:default": [],
})
```

+ `glob()` sees only files of the current package. It stops at subdirectories that have their own `BUILD` file.
+ `select()` picks an attribute value from the configuration (CPU, OS, `--define`, `config_setting` targets).
+ `package()` sets defaults for the package, such as `default_visibility`. `exports_files([...])` makes plain files usable by other packages.

## 5. Starlark restrictions

| Python habit | In Starlark |
| --- | --- |
| `def` in a `BUILD` file | Not allowed. Functions (macros) and rules go in `.bzl` files and are `load()`ed |
| `for` / `if` **statements** at top level | Not allowed (also in `.bzl`; use them inside functions). Comprehensions and `x if c else y` are fine |
| `import`, file I/O, environment, network | Not available. `BUILD` files see only `glob()`, attributes, and loaded symbols |
| Mutating shared state | A file's values are **frozen** when it finishes loading. A list from another `.bzl` can't be appended to |
| `*args`, `**kwargs` in calls | Not allowed in `BUILD` files |
| Dict / set iteration order | Deterministic (insertion order) |

```python
# Allowed in a BUILD file
srcs = ["main.cc"] + (["debug.cc"] if DEBUG else [])        # DEBUG loaded from a .bzl file
names = ["test_%d" % i for i in range(3)]

# Not allowed in a BUILD file
# if DEBUG:
#     srcs.append("debug.cc")
```

## 6. Macros and rules (`.bzl`)

```python
# tools/defs.bzl
load("@rules_cc//cc:defs.bzl", "cc_binary")

def tool_binary(name, srcs, **kwargs):                 # a macro: expands into existing rules
    cc_binary(
        name = name,
        srcs = srcs,
        copts = ["-Wall", "-Werror"],
        **kwargs
    )
```

```python
# tools/BUILD.bazel
load("//tools:defs.bzl", "tool_binary")

tool_binary(name = "dump", srcs = ["dump.cc"])
```

+ A **macro** is a function that calls existing rules. It runs while the `BUILD` file is loaded.
+ A **rule** (`rule(implementation = ..., attrs = ...)`) defines new actions and providers. It is evaluated in the analysis phase.
+ Format `BUILD` and `.bzl` files with **buildifier**, which also sorts `load()`s and lists and reports common mistakes.

## Related notes

+ [Bazel_intro.md](Bazel_intro.md), [Android_bp_intro.md](Android_bp_intro.md)

## Reference

+ [BUILD files](https://bazel.build/concepts/build-files), [Labels](https://bazel.build/concepts/labels), [Visibility](https://bazel.build/concepts/visibility)
+ [Starlark language (differences with Python)](https://bazel.build/rules/language)
+ [Built-in functions: glob, select, package, ...](https://bazel.build/reference/be/functions)
+ [Configurable attributes (select)](https://bazel.build/docs/configurable-attributes), [Macros](https://bazel.build/extending/macros)
