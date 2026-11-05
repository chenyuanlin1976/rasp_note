# Linux library files (`.a`, `.so`)

A library is pre-compiled code that programs reuse. Linux has two kinds:

+ **Static library** (`.a`, "archive"): the linker copies the needed code into the executable at build time.
+ **Shared library** (`.so`, "shared object"): the executable only records the library's name; the dynamic loader (`ld-linux*.so`) maps the library into memory when the program starts.
  It is the Linux counterpart of a Windows DLL.

## 1. Static vs shared

| | `.a` static library | `.so` shared library |
| --- | --- | --- |
| What it is | An `ar` archive of `.o` object files | An ELF file, linked like an executable but without `main` |
| When code is bound | At link time (build) | Recorded at link time, loaded and resolved at program start (or later with `dlopen()`) |
| What goes into the executable | Only the archive members (`.o` files) that resolve undefined symbols | A `NEEDED` entry with the library's soname |
| Executable size | Larger | Smaller |
| Memory | Each program has its own copy | Read-only code pages are shared by all processes using the library; writable data is per process |
| Deployment | No library file needed at run time | The `.so` (correct version) must be on the target |
| Updating the library | Rebuild every program | Replace the `.so`; programs pick it up if the ABI is compatible (same soname) |
| Licensing | Linking LGPL code statically has extra obligations | Usual way to use LGPL libraries |

+ A static executable is self-contained only if **all** libraries, including the C library, are linked statically (`gcc -static`).
  Fully static glibc programs have limits (e.g. NSS name lookup and `dlopen()` still want shared libraries); musl libc is often used for static binaries instead.
+ When both `libfoo.so` and `libfoo.a` exist, `-lfoo` picks the **`.so`**. Use `-l:libfoo.a` or `-static` to force the static one.

## 2. Other related files

| File | What it is |
| --- | --- |
| `.o` | Object file: compiler output for one source file, not yet linked. A `.a` is a bundle of `.o` files |
| `.so.N` / `.so.N.M.P` | Versioned shared library (section 4) |
| `.la` | GNU Libtool text file describing a library (dependencies, paths). Many distributions delete them |
| `.lo` | GNU Libtool text file pointing to the PIC and non-PIC `.o` files of one source |
| `.pc` | pkg-config file with the compiler and linker flags to use a library (`pkg-config --cflags --libs libgpiod`) |
| `.ko` | Kernel module, loaded into the kernel, not into a user program; see [kernel_module.md](kernel_module.md) |

## 3. Build and use

Example sources:

```c
/* mylib.h */
#ifndef MYLIB_H
#define MYLIB_H
int add(int a, int b);
#endif
```

```c
/* mylib.c */
#include "mylib.h"

int add(int a, int b)
{
    return a + b;
}
```

```c
/* main.c */
#include <stdio.h>
#include "mylib.h"

int main(void)
{
    printf("2 + 3 = %d\n", add(2, 3));
    return 0;
}
```

### 3.1 Static library

```shell
gcc -c mylib.c -o mylib.o              # compile to an object file
ar rcs libmylib.a mylib.o              # r: insert/replace, c: create, s: write symbol index
gcc main.c -L. -lmylib -o myapp        # -L: search dir, -lmylib -> libmylib.so or libmylib.a
./myapp
```

Order matters with static libraries: the linker scans left to right, so put libraries **after** the files that use them (`gcc main.c -lmylib`, not `gcc -lmylib main.c`).

### 3.2 Shared library

```shell
gcc -c -fPIC mylib.c -o mylib.o                                  # position-independent code
gcc -shared -Wl,-soname,libmylib.so.1 -o libmylib.so.1.0.0 mylib.o
ln -sf libmylib.so.1.0.0 libmylib.so.1                           # soname link (used at run time)
ln -sf libmylib.so.1 libmylib.so                                 # linker name (used by -lmylib)

gcc main.c -L. -lmylib -o myapp
./myapp            # error while loading shared libraries: libmylib.so.1: cannot open shared object file
```

The program builds, but the loader doesn't search the current directory. Fix it in one of these ways:

```shell
LD_LIBRARY_PATH=. ./myapp                                 # 1. quick test only

gcc main.c -L. -lmylib -Wl,-rpath,'$ORIGIN' -o myapp      # 2. embed a search path: the executable's own directory
./myapp

sudo cp libmylib.so.1.0.0 /usr/local/lib/                 # 3. install system-wide
sudo ldconfig                                             #    creates the libmylib.so.1 link and updates /etc/ld.so.cache
```

+ `-fPIC` is required for shared libraries on most architectures, because the library can be mapped at any address.
+ `'$ORIGIN'` must be quoted so the shell doesn't expand it.
+ Don't put `LD_LIBRARY_PATH` in global startup files; it affects every program and can load the wrong library versions.

## 4. Library versions and the soname

A shared library usually has three names:

| Name | Example | Used by |
| --- | --- | --- |
| Real name (the file) | `libmylib.so.1.0.0` | The file on disk |
| soname | `libmylib.so.1` | Stored in the library (`-Wl,-soname`) and copied into every program linked against it; the loader looks for this name |
| Linker name | `libmylib.so` | `gcc -lmylib` at build time; on distributions it comes with the `-dev` package |

+ The **major number** (`.1`) changes only when the ABI breaks (removed functions, changed structs or signatures).
  Programs keep using `libmylib.so.1` while `libmylib.so.2` can be installed next to it.
+ Minor updates (`1.0.0` → `1.1.0`) keep the same soname, so existing programs use the new file without a rebuild.
+ `ldconfig` reads `/etc/ld.so.conf` (and `/etc/ld.so.conf.d/*`), creates soname links, and builds the cache the loader uses.

Loader search order (simplified): `DT_RPATH` (old-style, if no `RUNPATH`), `LD_LIBRARY_PATH`, `DT_RUNPATH`, `/etc/ld.so.cache`, then the default dirs (`/lib`, `/usr/lib`, and the multiarch dirs such as `/usr/lib/aarch64-linux-gnu`).

## 5. Inspect libraries and programs

```shell
file libmylib.so.1.0.0        # ELF 64-bit LSB shared object, ARM aarch64, ...
ldd ./myapp                   # shared libraries the program needs and where they resolve
readelf -d ./myapp            # dynamic section: NEEDED, RUNPATH
readelf -d libmylib.so.1.0.0 | grep SONAME
nm -D libmylib.so.1.0.0       # exported dynamic symbols (T = function defined here)
nm -C libmylib.a              # symbols of each object in the archive (-C demangles C++)
ar t libmylib.a               # list the .o members
objdump -T /lib/x86_64-linux-gnu/libc.so.6 | grep GLIBC_2.3   # versioned glibc symbols
```

`ldd` may run the program's loader; don't use it on untrusted binaries (`readelf -d` or `objdump -p` are safe alternatives).

## 6. Libraries are platform-specific

`.a` and `.so` files contain machine code, so they only work where they were built for:

+ **CPU architecture**: an x86-64 library can't be used on an ARM board (Raspberry Pi, RK3566). Linking fails with
  `file in wrong format` / `skipping incompatible`; running an x86-64 program on ARM gives `Exec format error`.
  Build for the target with a cross compiler (`aarch64-linux-gnu-gcc`) or on the board.
+ **Binary format and OS**: Linux uses ELF, Windows PE (`.dll`), macOS Mach-O (`.dylib`). Files can't be shared between them.
+ **ABI**: 32-bit vs 64-bit, hard-float vs soft-float on 32-bit ARM, C++ standard library and compiler ABI.
+ **C library**: a program or library built against glibc needs glibc on the target, and at least the **same or newer version** it was built with.
  Running a binary built on a newer distribution on an older one fails with errors like `version 'GLIBC_2.34' not found`.
  Build on the oldest system you support. Programs built against musl (Alpine) or Android's Bionic are not compatible with glibc either.

**User-space vs kernel modules**: `.so` and `.a` files talk to the kernel only through system calls, and Linux keeps that interface stable.
So a library built on a system with kernel 5.4 normally still works after upgrading to kernel 6.8 (if the C library is compatible).
A `.ko` kernel module is different: it is tied to the exact kernel version and configuration it was built for (`vermagic`), see [kernel_module.md](kernel_module.md).

## 7. Loading at run time: `dlopen()`

Plugins are shared libraries loaded on request instead of at startup:

```c
#include <dlfcn.h>
#include <stdio.h>

int main(void)
{
    void *h = dlopen("./libmylib.so.1", RTLD_NOW);
    if (h == NULL) {
        fprintf(stderr, "%s\n", dlerror());
        return 1;
    }

    int (*add)(int, int) = (int (*)(int, int))dlsym(h, "add");
    if (add == NULL) {
        fprintf(stderr, "%s\n", dlerror());
        dlclose(h);
        return 1;
    }

    printf("%d\n", add(2, 3));
    dlclose(h);
    return 0;
}
```

Build with `gcc plugin.c -o plugin` (glibc 2.34 and newer have `dlopen` in libc; older versions need `-ldl`).
Android's JNI `System.loadLibrary()` uses the same mechanism.

## Related notes

+ [kernel_module.md](kernel_module.md): `.ko` kernel modules and why they are tied to one kernel
+ [../CMakeLists_syntax.md](../CMakeLists_syntax.md): `add_library(STATIC|SHARED)`, cross-compiling toolchain files
+ [../Android/NDK_intro.md](../Android/NDK_intro.md): `.so` libraries in Android apps (Bionic, per-ABI builds)
+ [apt_dpkg_cmd.md](apt_dpkg_cmd.md): installing `-dev` packages that provide headers and linker names

## Reference

+ Program Library HOWTO (static, shared, dynamically loaded libraries): <https://tldp.org/HOWTO/Program-Library-HOWTO/>
+ `ld.so(8)` loader and search order: <https://man7.org/linux/man-pages/man8/ld.so.8.html>
+ `ldconfig(8)`: <https://man7.org/linux/man-pages/man8/ldconfig.8.html>
+ `dlopen(3)`: <https://man7.org/linux/man-pages/man3/dlopen.3.html>
+ GCC link options: <https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html>
