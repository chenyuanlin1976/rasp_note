# Fallbacks in shell scripts and C

A **fallback** is the alternative a program uses when the preferred value, resource, or code path is missing or fails:
a default value, a second tool, a software implementation.
A good fallback is **explicit and logged**. A fallback that silently hides an error makes bugs harder to find.

| Kind | Shell | C |
| --- | --- | --- |
| Default value | `${VAR:-default}` | `getenv()` + `?:`, `#ifndef` |
| Alternative resource | `[ -r a ] \|\| use b` | `fopen()` returns `NULL` → try the next path |
| Alternative tool / implementation | `command -v x \|\| ...` | Function pointer, chosen at init |
| Retry, then give up | `until`/`for` loop | Loop on the error code |

The shell examples were run with Bash 5.2. The C example was compiled with `gcc -Wall -Wextra`.

## 1. Shell

```shell
port="${PORT:-8080}"                  # unset or empty -> 8080
: "${LOG_DIR:=/tmp/logs}"             # also assign the default (':' is a no-op command)
: "${API_KEY:?API_KEY must be set}"   # no fallback: stop with an error

editor=$(command -v nvim || command -v vim || command -v vi || echo nano)   # first tool that exists

cfg="/etc/myapp.conf"
[ -r "$cfg" ] || { echo "warn: $cfg missing, using defaults" >&2; cfg="./default.conf"; }

fetch() {                              # alternative implementation
    if command -v curl >/dev/null; then curl -fsSL "$1"
    elif command -v wget >/dev/null; then wget -qO- "$1"
    else echo "need curl or wget" >&2; return 1
    fi
}

for i in 1 2 3; do                     # retry, then fail loudly
    fetch "$url" > out.json && break
    echo "attempt $i failed" >&2; sleep 2
done
```

`cmd1 || cmd2` runs `cmd2` when `cmd1` fails. `a && b || c` is **not** if/else: `c` also runs when `b` fails.
More on `${...}`: [brackets.md](brackets.md#5-parameter-expansion).

## 2. C

C has no exceptions or `??` operator. Fallbacks are explicit checks of return values, the preprocessor, and function pointers:

```c
#include <stdio.h>
#include <stdlib.h>

#ifndef BUF_SIZE                       /* compile-time default, override with -DBUF_SIZE=512 */
#define BUF_SIZE 256
#endif

static const char *env_or(const char *name, const char *fallback)
{
    const char *v = getenv(name);
    return (v != NULL && v[0] != '\0') ? v : fallback;
}

static int crc_hw(const void *d, size_t n, unsigned *out);   /* hardware accelerator: may fail */
static int crc_sw(const void *d, size_t n, unsigned *out);   /* portable software version */

int main(void)
{
    printf("port=%s buf=%d\n", env_or("PORT", "8080"), BUF_SIZE);

    FILE *f = fopen("/etc/myapp.conf", "r");                  /* resource fallback */
    if (f == NULL) {
        fprintf(stderr, "warn: /etc/myapp.conf missing, using ./default.conf\n");
        f = fopen("./default.conf", "r");
    }
    if (f == NULL) {
        perror("config");                                      /* no fallback left: fail */
        return EXIT_FAILURE;
    }
    fclose(f);

    int (*crc)(const void *, size_t, unsigned *) = crc_hw;    /* implementation fallback */
    unsigned c;
    if (crc("abc", 3, &c) != 0) {
        crc = crc_sw;
        crc("abc", 3, &c);
    }
    return 0;
}
```

The `crc_hw` / `crc_sw` bodies are omitted. In a driver, the same pattern picks a DMA path and falls back to PIO when DMA setup fails.

## Related notes

+ [bash_basic.md](bash_basic.md), [brackets.md](brackets.md), [bash_recipes.md](bash_recipes.md)

## Reference

+ [Bash manual: Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
+ [`getenv(3)`](https://man7.org/linux/man-pages/man3/getenv.3.html), [`fopen(3)`](https://man7.org/linux/man-pages/man3/fopen.3.html)
