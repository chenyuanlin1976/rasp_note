# Deprecating a Public Function in C and C++

C and C++ have no runtime warning system and no IDE auto-refactor like Kotlin's
`ReplaceWith`. Deprecation relies on a **compiler attribute** on the declaration
(standard `[[deprecated]]` since C23 and C++14, compiler extensions before that), a
forwarding `function_a` that calls `function_b`, and clear header comments.
Sections 1 to 5 use C; section 6 adds what is different in C++.

## 1. Standard C23 `[[deprecated]]`

```c
#include <stdio.h>

int function_b(int arg1, const char *arg2) {
    /* Actual implementation lives here */
    printf("Running function_b: %d, %s\n", arg1, arg2);
    return arg1 * 2;
}

[[deprecated("Use function_b instead; it provides the same behavior.")]]
static inline int function_a(int arg1, const char *arg2) {
    return function_b(arg1, arg2);
}
```

+ Every call to `function_a(...)` produces a compiler warning with the message
  (`-std=c23`, or `-std=c2x` on older GCC/Clang).
+ `static inline` wrapper: suits header-only APIs; it forwards to `function_b` with
  no extra call overhead and keeps the logic in one place. For a shared library,
  see section 3.

## 2. Portable macro (pre-C23 / pre-C++14, GCC, Clang, MSVC)

A public header is often included from both C and C++ code, so the macro checks both:

```c
#if defined(__cplusplus) && __cplusplus >= 201402L
#  define DEPRECATED(msg) [[deprecated(msg)]]
#elif !defined(__cplusplus) && defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#  define DEPRECATED(msg) [[deprecated(msg)]]
#elif defined(__GNUC__) || defined(__clang__)
#  define DEPRECATED(msg) __attribute__((deprecated(msg)))
#elif defined(_MSC_VER)
#  define DEPRECATED(msg) __declspec(deprecated(msg))
#else
#  define DEPRECATED(msg)
#endif

int function_b(int x);

DEPRECATED("Use function_b instead.")
int function_a(int x);
```

Checking `__STDC_VERSION__` (instead of only `__has_c_attribute`) avoids using the
`[[...]]` syntax in C11/C17 mode, where some compilers accept it only as an
extension with a pedantic warning.
MSVC reports `__cplusplus` as `199711L` unless `/Zc:__cplusplus` is set, so it falls
through to the `__declspec` branch, which works as well.

| Compiler | Spelling | Diagnostic |
|---|---|---|
| Any C23 or C++14 compiler | `[[deprecated("msg")]]` | Warning |
| GCC, Clang | `__attribute__((deprecated("msg")))` | `-Wdeprecated-declarations` (on by default); `-Werror=deprecated-declarations` makes it an error |
| MSVC | `__declspec(deprecated("msg"))` | Warning C4996 |
| Other | expands to nothing | None; code still compiles |

## 3. Shared library: header vs. ABI

+ Put the attribute on the **declaration in the public header**: that is what
  customer code includes and compiles against.
+ Keep a real, exported `function_a` definition in the `.c` file that delegates to
  `function_b`. Binaries already linked against the old symbol in the
  `.so` / `.dylib` / `.dll` keep working, while new builds get the warning.

```c
/* public_api.h */
int function_b(int id);

/* Deprecated: function_a will be removed in v2.0. */
DEPRECATED("Use function_b instead; function_a will be removed in v2.0.")
int function_a(int id);
```

```c
/* public_api.c */
#include "public_api.h"

int function_b(int id) {
    return id + 1;
}

int function_a(int id) {   /* defining it doesn't warn; only calls do */
    return function_b(id);
}
```

Remove the symbol only with a major version (and a SONAME bump on Linux).

## 4. Signature differences and suppressing your own warnings

+ Different parameters or types: convert them inside the `function_a` wrapper before
  calling `function_b`, and document the mapping in the message and header comment.
+ Own tests or internal code that call `function_a` on purpose can suppress the
  warning around that call only:

```c
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    int r = function_a(42);
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif
```

On MSVC, put `#pragma warning(suppress : 4996)` on the line before the call.

## 5. Why not a function pointer alias?

It is tempting to replace the wrapper with a constant pointer:

```c
int function_b(int x);

DEPRECATED("Use function_b instead.")
int (* const function_a)(int) = function_b;   /* don't do this for a plain function */
```

Calls like `function_a(42)` still compile (and warn), but a real wrapper function is
better:

| Problem | Explanation |
|---|---|
| ABI break | `function_a` changes from a function symbol to a data object. Binaries already linked against the function `function_a` now jump into data; this is the opposite of what section 3 needs. |
| Multiple definitions in a header | In C (unlike C++), a file-scope `const` object has external linkage. Defining it in a header included by several `.c` files gives "multiple definition" link errors; you need `extern` in the header plus one definition in a `.c` file. |
| Different type of `&function_a` | `&function_b` is `int (*)(int)`, but `&function_a` is `int (* const *)(int)`, a pointer to the pointer. Code that took the function's address no longer type-checks. |
| Extra indirection | Each call loads the pointer first, unless the optimizer proves the target; a `static inline` wrapper or direct call has no such cost. |
| Windows DLLs | Exporting/importing a data object (`__declspec(dllimport)` on a variable) works differently from a function, so customer code may need changes. |
| No argument adaptation | A pointer can't reorder or convert parameters; differing signatures need a wrapper anyway. |

Function pointers are the right tool only when the API already **is** a pointer:

+ A struct of callbacks (ops table / vtable): keep the old member, so the struct
  layout stays ABI-compatible, and deprecate it. GCC, Clang, and C23 accept the
  attribute on struct members:

```c
struct ops {
    DEPRECATED("Use compute_v2 instead.")
    int (*compute)(int);           /* old member: keep it, same offset */
    int (*compute_v2)(int, int);   /* new member: append at the end */
};
```

+ A pluggable hook (logger, allocator): deprecate the old **setter function** and
  let it forward to the new one, instead of exporting a second pointer variable
  that would not stay in sync with the first:

```c
typedef int (*log_fn_t)(const char *msg);

void set_logger(log_fn_t fn);

DEPRECATED("Use set_logger instead.")
void set_log_callback(log_fn_t fn);   /* defined in the .c file as set_logger(fn) */
```

For ordinary functions, use the wrapper from sections 1 to 3: `&function_a` keeps
the type `int (*)(int)`, the symbol stays a function, and all logic stays in
`function_b`.

## 6. C++

`[[deprecated]]` and `[[deprecated("msg")]]` are standard since C++14. Put the attribute
on the declaration in the header. It isn't needed again on the out-of-line definition.

```c++
// math_api.h
#pragma once

int add_values(int a, int b);

[[deprecated("Use add_values(int, int) instead")]]
int add_legacy(int a, int b);
```

```c++
// math_api.cpp
#include "math_api.h"

int add_values(int a, int b) { return a + b; }

int add_legacy(int a, int b) { return add_values(a, b); }   // forward, keep one implementation
```

A call such as `add_legacy(1, 2)` gives, in GCC:
`warning: 'int add_legacy(int, int)' is deprecated: Use add_values(int, int) instead [-Wdeprecated-declarations]`.

C++ allows the attribute on more kinds of entities than C:

```c++
struct Calculator {
    [[deprecated("Use compute() instead")]]
    int run(int x);                          // member function
};

void process(int x);
[[deprecated("Pass a value, not a raw pointer")]]
void process(const int* p);                  // only this overload warns

using OldHandler [[deprecated("Use NewHandler instead")]] = void (*)(int);   // alias

class [[deprecated("Use Widget2 instead")]] Widget;                          // class

enum class Mode { Fast, Slow [[deprecated("Use Fast")]] };                   // enumerator (C++17)

namespace [[deprecated("Use lib::v2 instead")]] v1 { /* ... */ }             // namespace (C++17)
```

Differences from C:

+ **Header-only code**: a deprecated `inline` function or template is compiled into the
  caller, so there is no exported symbol to keep. For a compiled `.so`, keep the real
  function exported as in section 3.
+ **Function pointer alias**: the reasons in section 5 apply as well. In C++, a
  namespace-scope `const` object has **internal** linkage, so a header definition
  doesn't cause "multiple definition" errors, but every `.cpp` file gets its own copy and
  there is still no function symbol for old binaries.
+ **Name mangling**: a C++ symbol name includes the parameter types. Changing
  `int f(int)` to `int f(int, int = 0)` still compiles for callers, but it removes the
  old symbol `_Z1fi`, so old binaries fail to load. Keep the old signature exactly and
  add a new function instead.
+ **C library used from C++**: wrap the header declarations in `extern "C" { ... }`
  (guarded by `#ifdef __cplusplus`); the `DEPRECATED` macro from section 2 works inside it.

## Related notes

+ [deprecation_kotlin.md](deprecation_kotlin.md): the same task in Kotlin, plus the release rollout lifecycle
+ [deprecation_python.md](deprecation_python.md): the same task in Python
+ [../Linux/Others/static_shared_lib.md](../Linux/Others/static_shared_lib.md): shared libraries, soname, and what breaks the ABI

## Reference

+ C attribute `deprecated` (cppreference): https://en.cppreference.com/w/c/language/attributes/deprecated
+ C++ attribute `deprecated` (cppreference): https://en.cppreference.com/w/cpp/language/attributes/deprecated
+ GCC common function attributes: https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html
+ GCC diagnostic pragmas: https://gcc.gnu.org/onlinedocs/gcc/Diagnostic-Pragmas.html
+ MSVC `deprecated` declspec: https://learn.microsoft.com/en-us/cpp/cpp/deprecated-cpp
