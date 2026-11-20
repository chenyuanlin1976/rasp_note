# Deprecating a Public Function in Kotlin

To replace `functionA` with `functionB` in a public API, mark `functionA` with
`@Deprecated`, point callers to `functionB` with `ReplaceWith`, delegate the
implementation, and raise the `DeprecationLevel` over several releases.

## 1. `@Deprecated` with `ReplaceWith`

```kotlin
@Deprecated(
    message = "Use functionB instead. It provides the same behavior with a clearer name.",
    replaceWith = ReplaceWith("functionB(arg1, arg2)"),
    level = DeprecationLevel.WARNING
)
fun functionA(arg1: String, arg2: Int): Result {
    return functionB(arg1, arg2)
}

fun functionB(arg1: String, arg2: Int): Result {
    // Actual implementation lives here
    TODO()
}
```

+ `message`: says why the function is deprecated and what to use instead.
+ `replaceWith`: enables the IDE quick-fix (IntelliJ / Android Studio) that rewrites
  `functionA(...)` to `functionB(...)` at call sites. The expression may refer to
  the parameters of `functionA` by name. If `functionB` lives in another package,
  list the import as well: `ReplaceWith("functionB(arg1, arg2)", "com.example.api.functionB")`.
+ Delegation: keep the real logic in `functionB` and let `functionA` forward to it,
  so there is no duplicate code and no behavior drift. Never let `functionB` call
  `functionA`; that would raise deprecation warnings inside your own library.

## 2. Deprecation levels

| Level | Effect on source callers | Effect on compiled callers |
|---|---|---|
| `WARNING` (default) | Compiles, with a warning | Keep working |
| `ERROR` | Compilation error with the message | Keep working (symbol still exists) |
| `HIDDEN` | Not visible: unresolved reference, not in autocomplete | Keep working (symbol still in bytecode) |

The deprecation is also visible to Java callers: `WARNING` and `ERROR` show up as a
normal Java deprecation; `HIDDEN` declarations become synthetic and can't be called
from Java source.

## 3. Signature or behavior differences

If `functionB` is not a drop-in replacement for `functionA`:

+ Different parameter order or types: write the `ReplaceWith` expression to match
  `functionB`, e.g. `ReplaceWith("functionB(arg2, arg1.toInt())")`, and convert the
  arguments inside `functionA`.
+ Different nullability or return type: describe the difference in `message` and in
  the KDoc, so customers aren't surprised after accepting the quick-fix.

## 4. Rollout lifecycle

For external customers, deprecation is a release and communication process, not
just an annotation:

1. Ship `functionB` before or together with the deprecation of `functionA`.
2. Start with `WARNING` in a minor/feature release, with release notes that explain
   the change and the planned removal version.
3. Replace `functionA` in docs, samples, quickstarts, and tests.
4. Escalate to `ERROR`, then `HIDDEN` or removal, only on announced version
   boundaries (typically a major version or after a defined deprecation window).

## 5. Equivalent mechanisms in other languages

| Language | Mechanism |
|---|---|
| Java | `@Deprecated(since = "2.1", forRemoval = true)` (Java 9+) + Javadoc `@deprecated Use {@link #functionB} instead.` |
| Scala | `@deprecated("Use functionB instead", since = "2.1")` (lowercase annotation) |
| TypeScript / JavaScript | JSDoc `/** @deprecated Use functionB instead. */` (shown as strikethrough in editors) |
| C# / .NET | `[Obsolete("Use FunctionB instead.", error: false)]`; `error: true` later to block compilation |
| Python | `@warnings.deprecated` (3.13+) or `warnings.warn(..., DeprecationWarning)`, see [deprecation_python.md](deprecation_python.md) |
| C, C++ | `[[deprecated("msg")]]` (C23, C++14) or compiler attributes, see [deprecation_c_cpp.md](deprecation_c_cpp.md) |

## Related notes

+ [deprecation_python.md](deprecation_python.md): the same task in Python
+ [deprecation_c_cpp.md](deprecation_c_cpp.md): the same task in C and C++

## Reference

+ Kotlin `@Deprecated`: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-deprecated/
+ Kotlin `ReplaceWith`: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-replace-with/
+ Kotlin `DeprecationLevel`: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-deprecation-level/
