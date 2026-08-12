# Linux library files

In Linux, **.so** and **.a** files are both types of library files containing pre-compiled code that developers can reuse in their programs.  
However, they handle how code is integrated and executed in fundamentally different ways.

## 1. .so Files (Shared Object)

A **.so** file stands for **Shared Object**.  
It is the Linux equivalent of a **DLL (.dynamic link library)** file in Windows.

+ Dynamic Linking: The code inside a **.so** file is not copied into your final executable during compilation.  
  Instead, the executable only keeps a reference to it.  
  When the program runs, the operating system loads the **.so** file into memory.
+ Memory and Disk Efficiency: Multiple running programs can share a single instance of a **.so** file in RAM simultaneously, saving system memory.
+ Easy Updates: If a bug is fixed in a **.so** file, you can replace the file,  
  and all programs that use it will automatically use the updated version without needing to be recompiled.

## 2. .a Files (Archive / Static Library)

A **.a** file stands for **Archive**, commonly used as a **Static Library**.  
It is a collection of compiled object files bundled together.

+ Static Linking: During compilation, the compiler copies all the necessary functions and code from the **.a** file directly into your final executable binary.
+ Self-Contained Binaries: Because the library code is embedded directly into the program, the resulting executable is completely independent.  
  It does not require the **.a** file to be present on the target system to run.
+ Larger File Sizes: Executables built with static libraries are generally larger because they carry copies of all the library code they use.

## Key Differences at a Glance

| Feature         | .so (Shared Object)                                  | .a (Static Library / Archive)                         |
| --------------- | ---------------------------------------------------- | ----------------------------------------------------- |
| Linking Time    | At runtime or load time                              | At compile time                                       |
| Executable Size | Smaller (only references the library)                | Larger (contains a copy of the library code)          |
| Memory Usage    | Shared across multiple running processes             | Duplicated inside every program that uses it          |
| Portability     | Requires the .so file to exist on the target machine | Fully self-contained; no external dependencies        |
| Updates         | Updating the .so file updates all dependent apps     | Requires recompiling the application to apply updates |

## architecture-dependent

**.a and .so files are also strictly platform-specific.**  
Because they contain compiled machine code, they are bound to the specific hardware architecture and operating system environment they were built for.

### Why .a and .so Are Platform-Specific

1. CPU Architecture: A .so or .a file compiled on an Intel (x86_64) PC contains x86 machine instructions.  
   If you try to link or run it on an ARM-based device (like a Raspberry Pi or an Apple Silicon Mac),  
   the CPU will not understand the instructions, resulting in errors during compilation or execution (such as Exec format error).
2. Operating System and ABI (Application Binary Interface):  
   + OS Compatibility: A Linux .so file cannot be used directly by Windows or macOS,  
     because different operating systems use different binary formats (**Linux uses ELF, Windows uses PE, macOS uses Mach-O**).
   + ABI Compatibility: Even within the same OS, they must match the system's ABI (e.g., 32-bit vs. 64-bit, or different calling conventions).

### How They Differ from .ko Files (The Kernel Exception)

While **.a, .so, and .ko** files are all platform-specific regarding the CPU,  
.a and .so files have one major advantage over .ko files:

+ User Space vs. Kernel Space: .a and .so files typically run in user space. Because they rely on standard user-space APIs (like the C standard library, glibc),  
  they are not tightly bound to a specific Linux kernel version.
+ A .so file compiled for an Intel 64-bit Linux system running kernel 5.4 will usually still work fine on the same system running kernel 6.8,  
  whereas a .ko file compiled for kernel 5.4 will almost certainly fail to load on kernel 6.8.

## other library format

while .a, .so, and .ko are the primary compiled library formats in Linux,  
there are a few other auxiliary file types and metadata formats closely associated with libraries and the compilation process:

1. **.o** Files (Object Files):  
   + What it is: The raw output of a compiler (like GCC) after translating a single source code file (e.g., main.c) into machine code,  
     but before it has been linked into an executable or packaged into a library.  
   + Role: They are the fundamental building blocks. *A static library (.a) is essentially just a collection of bundled .o files.*
2. **.la** Files (Libtool Archive):  
   + What it is: Unlike the others, a .la file is not a binary file; it is a plain text configuration file.  
   + Role: Created by the GNU Libtool package, it acts as a metadata container.  
     It describes a library's dependencies, paths, and whether a shared (.so) or static (.a) version should be preferred by the build system.
3. **.lo** Files (Libtool Object):  
   + What it is: A specialized object file generated by GNU Libtool.  
   + Role: It contains extra metadata required by Libtool to help compile code that can be safely turned into shared libraries across various Unix-like platforms.
4. Versioned .so Files (e.g., `.so.1`, `.so.1.2.3`)
   + What it is: A naming convention variation of the standard Shared Object (.so).  
   + Role: Linux shared libraries often append version numbers to their extensions (e.g., libc.so.6).  
     This allows multiple incompatible versions of the same library to coexist peacefully on the same system,  
     letting programs link specifically to the version they were tested against.

## Compile libraries with gcc

Compiling C source files into libraries allows you to reuse code efficiently.  
Depending on your needs, you can create  

+ a **Static Library (.a)** which is bundled directly into your executable at compile time,  
+ a **Shared/Dynamic Library (.so)** which is loaded at runtime.

### 1. Creating a Static Library (.a)

A static library is essentially *a collection of object files* packed into a single archive.

1. Compile the C file into an Object File (.o): `gcc -c mylib.c -o mylib.o`
2. Create the Static Library using **ar**: `ar rcs libmylib.a mylib.o`  
   Use the archiving utility ar to **bundle** the object file into a .a file.  
   + r: Insert the files into the archive (replacing older files if they exist).
   + c: Create the archive if it does not already exist.
   + s: Write an object-file index into the archive (speeds up linking).
3. Link and Use the Static Library: `gcc main.c -L. -lmylib -o myapp`  
   + -L.: Tells the compiler to look for libraries in the current directory (.).
   + -lmylib: Links the library libmylib.a (*drop the lib prefix and the .a extension*).

### 2. Creating a Shared Library (.so)

*A shared library is loaded dynamically by programs at runtime*, saving memory and disk space.

1. Compile with Position Independent Code (**-fPIC**): `gcc -c -fPIC mylib.c -o mylib.o`  
   Shared libraries must use Position Independent Code (PIC)  
   so they can be loaded anywhere in memory. Compile your source file with -fPIC and -c:
2. Create the Shared Library (.so): `gcc -shared -o libmylib.so mylib.o`  
   Use the **-shared** flag to link the object file into a shared library.
3. Link and Use the Shared Library: `gcc main.c -L. -lmylib -o myapp`  
   Compile your main program, pointing it to the shared library just like the static library.
4. Run the Executable:  
   Because shared libraries are resolved at runtime,  
   *the operating system needs to know where to find `libmylib.so` when you run myapp.*  
   If you run it immediately, you might get a library-not-found error.  
   To fix this temporarily for your current terminal session, add the current directory to your **library path**:  
   `export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:.`
   `./myapp`
