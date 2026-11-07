# Linux kernel coding style (summary)

A condensed summary of the kernel's [coding style](https://docs.kernel.org/process/coding-style.html) document,
for writing drivers and patches. The full text is the reference. Read it once; this note is the checklist.
The C examples below compile as a module, and `checkpatch.pl` reports 0 errors and 0 warnings for them.

## 1. Check it with tools

```shell
./scripts/checkpatch.pl --strict -f drivers/misc/mydrv.c     # in a kernel tree: check a file
./scripts/checkpatch.pl --strict 0001-my-change.patch        # check a patch before sending it
./scripts/checkpatch.pl --no-tree -f mydrv.c                 # out-of-tree, e.g. with /lib/modules/$(uname -r)/build/scripts/
clang-format -i mydrv.c                                      # the kernel ships a .clang-format; review the result, it isn't perfect
```

## 2. Layout

| Rule | Detail |
| --- | --- |
| Indentation | **Tabs, 8 columns wide**. Never spaces (except in comments, documentation, and Kconfig help text) |
| Nesting | More than 3 levels deep means the function should be split |
| `switch` | `case` labels in the **same column** as `switch` |
| Line length | 80 columns preferred. Up to 100 is accepted when it reads better (checkpatch warns above 100) |
| Strings | **Never split user-visible strings** (log messages), so they stay greppable |
| One statement per line | No `if (x) do_this;` on one line, no comma tricks to avoid braces |
| Trailing whitespace | None |

### 2.1 Braces and spaces

```c
static unsigned long parse_size(unsigned long mem, char suffix)
{                                       /* functions: opening brace on its own line */
	switch (suffix) {               /* everything else: K&R, brace on the same line */
	case 'G':
	case 'g':
		mem <<= 30;
		break;
	case 'M':
	case 'm':
		mem <<= 20;
		break;
	default:
		break;
	}
	return mem;
}
```

+ No braces around a single statement, **unless** another branch of the same `if`/`else` needs them; then use braces on all branches.
+ A space after the keywords `if`, `switch`, `case`, `for`, `do`, `while`.
  No space after `sizeof`, `typeof`, `alignof`, `__attribute__`: `sizeof(*p)`.
+ No spaces inside parentheses: `if (x)`, not `if ( x )`.
+ The `*` binds to the name: `char *buf`, `int *f(void)`.
+ Spaces around binary and ternary operators (`a + b`, `x ? y : z`). None after unary operators (`!x`, `-x`, `*p`, `&v`, `x++`) and none around `.` and `->`.

## 3. Names and types

+ Global names are **descriptive**: `count_active_users()`, not `cntusr()`.
  Local names are short: `i`, `tmp`, `ret`.
+ `lower_case_with_underscores`. No Hungarian notation. Avoid "master/slave" and "blacklist/whitelist" in new code.
+ **Don't `typedef` structs or pointers** (`struct my_dev *d`, not `my_dev_t d`). Typedefs are for opaque types,
  the sized integers `u8`/`u16`/`u32`/`u64` (`__u32` in user-visible headers), and sparse-checked types (`__le32`).
+ Use `bool` for true/false values, not `int` flags.

## 4. Functions

+ Short, doing one thing: 1–2 screens, about 5–10 local variables.
+ Separate functions with one blank line. Put `EXPORT_SYMBOL()` right after the function.
+ Name the parameters in prototypes. Don't use `extern` on function declarations.
+ **Return values**: a function that *does* something returns an `int` error code (`0` = success, `-Exxx` = error).
  A predicate (`is_...`, `has_...`) returns `bool`.

### 4.1 Centralized cleanup with `goto`

```c
static int my_dev_setup(struct my_dev *d, size_t n)
{
	int *table;
	int ret;

	d->buf = kmalloc(BUF_LEN, GFP_KERNEL);
	if (!d->buf)
		return -ENOMEM;

	table = kcalloc(n, sizeof(*table), GFP_KERNEL);
	if (!table) {
		ret = -ENOMEM;
		goto err_free_buf;
	}

	if (n > 16) {
		dev_err(d->dev, "too many entries: %zu\n", n);
		ret = -EINVAL;
		goto err_free_table;
	}

	kfree(table);
	return 0;

err_free_table:
	kfree(table);
err_free_buf:
	kfree(d->buf);
	d->buf = NULL;
	return ret;
}
```

Label names say what they undo (`err_free_buf`), not `err1:` / `err2:`.
In drivers, `devm_*` allocations and helpers often remove the need for most cleanup labels.

## 5. Comments

```c
/*
 * Multi-line comments look like this: say WHAT the code does and WHY,
 * not HOW. Put them at the top of functions, not between statements.
 */

/**
 * my_dev_reset() - Clear the device state.
 * @d: device to reset
 *
 * Context: Process context. Takes no locks.
 */
```

`/** ... */` is **kernel-doc**, which generates documentation. Use it for exported functions and public structures.

## 6. Macros, enums, inline

+ Prefer `enum` and `static inline` functions over macros. Macro constants are CAPITALIZED.
+ Wrap multi-statement macros in `do { } while (0)`, parenthesize the arguments, and don't hide `return` or `goto` inside a macro.

```c
#define my_dev_reset(d)			\
	do {				\
		(d)->flags = 0;		\
		(d)->buf[0] = '\0';	\
	} while (0)
```

  `checkpatch --strict` flags this macro ("argument reuse"): `my_dev_reset(p++)` would increment twice. A `static inline` function avoids the problem.
+ `inline` only for very small functions (a few lines). The compiler decides better for larger ones.
+ Use existing helpers instead of writing your own: `ARRAY_SIZE()`, `min()`/`max()`/`clamp()`, `sizeof_field()`, `container_of()`, `BIT()`, `GENMASK()`.

## 7. Kernel APIs

| Topic | Rule |
| --- | --- |
| Logging | `dev_err(dev, ...)`/`dev_info()` when a `struct device` exists, otherwise `pr_err()`/`pr_info()` with a `pr_fmt` prefix. End messages with `\n`, and don't log in hot paths |
| Allocation | `p = kmalloc(sizeof(*p), GFP_KERNEL);` (size from the variable, not the type). Arrays: `kmalloc_array()`/`kcalloc()` (overflow-checked). No cast of the `void *` result |
| `#ifdef` | Avoid it in `.c` files. Put stubs in a header, or use `if (IS_ENABLED(CONFIG_FOO))` so that both branches are compiled and checked |
| Errors | Don't `BUG()` / `BUG_ON()` for recoverable conditions. Use `WARN_ON_ONCE()` and return an error |
| Kconfig | Tabs for indentation, help text indented one more tab plus 2 spaces. Mark experimental or dangerous options clearly |
| Editor cruft | No vim/emacs modelines in source files |

## Related notes

+ [kernel_build.md](kernel_build.md), [kernel_module.md](kernel_module.md), [dts_coding_style.md](dts_coding_style.md)

## Reference

+ [Linux kernel coding style](https://docs.kernel.org/process/coding-style.html)
+ [checkpatch.pl](https://docs.kernel.org/dev-tools/checkpatch.html), [clang-format](https://docs.kernel.org/dev-tools/clang-format.html)
+ [Writing kernel-doc comments](https://docs.kernel.org/doc-guide/kernel-doc.html)
