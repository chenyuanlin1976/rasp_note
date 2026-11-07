# CMakeLists.txt syntax

CMake is a build-system generator. You describe the project in `CMakeLists.txt`; CMake then generates the real build files
(Makefiles, Ninja files, Visual Studio or Xcode projects) and the native tool does the compiling. The Raspberry Pi Pico SDK,
the Android NDK (Android Studio), and most C/C++ libraries use it.

This note covers the general syntax and the commands used most often, then the Pico SDK and Android additions.

## 1. Configure and build

CMake works in two steps, in a separate build directory (an "out-of-source" build, so generated files don't mix with sources):

```shell
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release   # 1. configure: read CMakeLists.txt, generate build files
cmake --build build -j8                          # 2. build: run make/ninja for you
cmake --install build --prefix /opt/myapp        # optional: install
```

+ `-G Ninja` picks the Ninja generator instead of the default (Makefiles on Linux).
+ `-D<VAR>=<value>` sets a cache variable. Values are stored in `build/CMakeCache.txt` and kept for later runs. Delete the build directory to start clean.
+ `CMAKE_BUILD_TYPE` (single-config generators): `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`.
+ Older style that does the same: `mkdir build && cd build && cmake .. && make -j8`.

## 2. Language basics

```cmake
# line comment
#[[ block
    comment ]]

cmake_minimum_required(VERSION 3.16)      # first line: minimum version, sets policies
project(myapp VERSION 1.0 LANGUAGES C CXX)

set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)   # variable
set(SOURCES main.c util.c)                     # a list is a ;-separated string: "main.c;util.c"
list(APPEND SOURCES extra.c)

option(ENABLE_LOG "Enable logging" ON)         # boolean cache option, -DENABLE_LOG=OFF to change

if(ENABLE_LOG AND CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "logging enabled")
elseif(WIN32)
    message(WARNING "Windows build")
else()
    message(STATUS "logging disabled")
endif()

foreach(f IN LISTS SOURCES)
    message(STATUS "source: ${f}")
endforeach()

function(add_tool name)                        # function: own variable scope
    add_executable(${name} tools/${name}.c)
endfunction()
add_tool(dump)
```

+ Everything is a command call: `name(arg1 arg2 ...)`. Command names are case-insensitive (lowercase is the convention); variable names are case-sensitive.
+ Arguments are separated by spaces. Quote an argument that contains spaces or `;`: `"${MY_PATH}"`.
+ `${VAR}` expands a variable; `$ENV{HOME}` reads an environment variable.
+ `function()` has its own scope (use `set(VAR value PARENT_SCOPE)` to return values); `macro()` works by text substitution in the caller's scope.

Useful built-in variables:

| Variable | Meaning |
| --- | --- |
| `CMAKE_SOURCE_DIR` / `CMAKE_BINARY_DIR` | Top-level source / build directory |
| `CMAKE_CURRENT_SOURCE_DIR` / `CMAKE_CURRENT_LIST_DIR` | Directory of the `CMakeLists.txt` (or `.cmake` file) being processed |
| `PROJECT_NAME`, `PROJECT_VERSION` | Set by `project()` |
| `CMAKE_C_STANDARD`, `CMAKE_CXX_STANDARD` | Default language standard for targets (e.g. `11`, `17`) |
| `CMAKE_C_COMPILER`, `CMAKE_CXX_COMPILER` | The compilers in use (set by the toolchain) |
| `CMAKE_BUILD_TYPE` | Build configuration |
| `CMAKE_EXPORT_COMPILE_COMMANDS` | `ON` writes `compile_commands.json` for clangd and IDEs |

## 3. Targets

Modern CMake is built around **targets** (executables and libraries) and their properties, not global settings.

| Command | Purpose |
| --- | --- |
| `add_executable(<target> <sources>...)` | Define a program |
| `add_library(<target> STATIC\|SHARED\|INTERFACE <sources>...)` | Define a library (`.a`, `.so`, or header-only/flags-only) |
| `target_sources(<target> PRIVATE <files>...)` | Add sources to an existing target |
| `target_include_directories(<target> PUBLIC\|PRIVATE <dirs>...)` | Header search paths (`-I`) |
| `target_compile_definitions(<target> PRIVATE <NAME>=<value>...)` | Preprocessor macros (`-D`) |
| `target_compile_options(<target> PRIVATE <flags>...)` | Compiler flags, e.g. `-Wall -Wextra` |
| `target_compile_features(<target> PUBLIC c_std_11 cxx_std_17)` | Require a language standard |
| `target_link_libraries(<target> PUBLIC\|PRIVATE <libs>...)` | Link libraries **and** inherit their usage requirements |

The scope keyword says who gets the setting:

| Keyword | Used by the target itself | Passed on to targets that link it |
| --- | --- | --- |
| `PRIVATE` | Yes | No |
| `PUBLIC` | Yes | Yes |
| `INTERFACE` | No | Yes (e.g. header-only libraries) |

Rule of thumb: if a library's **public headers** need it, use `PUBLIC`; if only its `.c` files need it, use `PRIVATE`.
`target_link_libraries()` without a keyword still works (old style), but don't mix both styles on the same target.

Avoid the older directory-wide commands (`include_directories()`, `add_definitions()`, `link_libraries()`) in new code; they apply to every target in the directory.

## 4. Subdirectories and dependencies

```cmake
add_subdirectory(libs/sensor)            # processes libs/sensor/CMakeLists.txt, which defines target "sensor"

find_package(Threads REQUIRED)           # installed package with a CMake config/find module
find_package(OpenSSL REQUIRED)
target_link_libraries(myapp PRIVATE sensor Threads::Threads OpenSSL::SSL)

find_package(PkgConfig REQUIRED)         # libraries that only ship a .pc file
pkg_check_modules(GPIOD REQUIRED IMPORTED_TARGET libgpiod)
target_link_libraries(myapp PRIVATE PkgConfig::GPIOD)

include(FetchContent)                    # download and build a dependency at configure time (CMake 3.14+)
FetchContent_Declare(fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG        11.0.2)
FetchContent_MakeAvailable(fmt)
target_link_libraries(myapp PRIVATE fmt::fmt)
```

+ Prefer **imported targets** like `OpenSSL::SSL` over variables like `${OPENSSL_LIBRARIES}`: the target carries include paths and flags with it.
+ `file(GLOB ...)` to collect sources works, but CMake won't notice new files until you re-run the configure step. Listing files explicitly is the usual recommendation.

## 5. Install

```cmake
include(GNUInstallDirs)
install(TARGETS myapp sensor
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}      # bin/
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}      # lib/
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES include/sensor.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
```

## 6. Complete example

```text
myapp/
├── CMakeLists.txt
├── src/main.c
└── libs/sensor/
    ├── CMakeLists.txt
    ├── include/sensor.h
    └── sensor.c
```

`libs/sensor/CMakeLists.txt`:

```cmake
add_library(sensor STATIC sensor.c)
target_include_directories(sensor PUBLIC include)   # users of "sensor" also get -I.../include
target_compile_options(sensor PRIVATE -Wall -Wextra)
```

Top-level `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.16)
project(myapp VERSION 1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_subdirectory(libs/sensor)

add_executable(myapp src/main.c)
target_compile_definitions(myapp PRIVATE APP_VERSION="${PROJECT_VERSION}")
target_link_libraries(myapp PRIVATE sensor)         # include path comes from sensor's PUBLIC setting
```

## 7. Cross-compiling with a toolchain file

To build on a PC for an ARM board (e.g. RK3566 or Raspberry Pi running 64-bit Linux), describe the target in a toolchain file:

```cmake
# aarch64-linux-gnu.cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

set(CMAKE_SYSROOT /opt/sysroot-aarch64)              # optional: copy of the target's /usr and /lib

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)         # run host tools
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)          # but find libraries/headers in the sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
```

```shell
cmake -S . -B build-arm64 -DCMAKE_TOOLCHAIN_FILE=aarch64-linux-gnu.cmake
cmake --build build-arm64 -j8
```

The toolchain file must be given on the **first** configure of a build directory. The Pico SDK and the Android NDK provide their own toolchain files, so you don't write one for them.

## 8. Raspberry Pi Pico SDK additions

| Command | Purpose |
| --- | --- |
| `include(pico_sdk_import.cmake)` | Locate the SDK (via `PICO_SDK_PATH`). Must come **before** `project()` |
| `pico_sdk_init()` | Initialize the SDK. Call after `project()` and before defining targets |
| `target_link_libraries(<t> pico_stdlib hardware_spi ...)` | SDK libraries are INTERFACE libraries; link only what you use |
| `pico_enable_stdio_usb(<t> 1)` / `pico_enable_stdio_uart(<t> 0)` | Send `printf()` to USB CDC and/or UART |
| `pico_add_extra_outputs(<t>)` | Also create `.uf2`, `.bin`, `.hex`, `.dis`, `.map` (otherwise only `.elf`) |
| `pico_generate_pio_header(<t> <file>.pio)` | Run pioasm and generate `<file>.pio.h` |
| `-DPICO_BOARD=pico2` (or `set(PICO_BOARD ...)` before the import) | Select the board: `pico`, `pico_w`, `pico2`, `pico2_w`, ... |

A complete Pico `CMakeLists.txt` is in [../Embedded/RPi_pico_Cxx_SDK.md](../Embedded/RPi_pico_Cxx_SDK.md); PIO builds are in [../Embedded/RPi_pico_PIO.md](../Embedded/RPi_pico_PIO.md).

## 9. Android NDK additions

In Android Studio, Gradle runs CMake for each ABI with the NDK's toolchain file. A JNI library is a `SHARED` library:

```cmake
add_library(native-lib SHARED native-lib.cpp)
find_library(log-lib log)                        # liblog from the NDK sysroot
target_link_libraries(native-lib PRIVATE ${log-lib})   # add "android" only for ANativeWindow, AAsset, ...
```

Outside Gradle: `cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 ...`.
See [../Android/JNI_android_studio.md](../Android/JNI_android_studio.md) for a full project.

## Related notes

+ [../Embedded/RPi_pico_Cxx_SDK.md](../Embedded/RPi_pico_Cxx_SDK.md): Pico SDK project and build
+ [../Embedded/RPi_pico_PIO.md](../Embedded/RPi_pico_PIO.md): `pico_generate_pio_header()` and PIO programs
+ [../Android/JNI_android_studio.md](../Android/JNI_android_studio.md): CMake in an Android Studio JNI project
+ [../Android/NDK_intro.md](../Android/NDK_intro.md): NDK overview
+ [../Android/AOSP_build_system.md](../Android/AOSP_build_system.md): AOSP's own build system (Soong, `Android.bp`), which doesn't use CMake

## Reference

+ CMake documentation: <https://cmake.org/cmake/help/latest/>
+ CMake tutorial: <https://cmake.org/cmake/help/latest/guide/tutorial/index.html>
+ Cross compiling (`cmake-toolchains`): <https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html>
+ Raspberry Pi Pico C/C++ SDK book: <https://datasheets.raspberrypi.com/pico/raspberry-pi-pico-c-sdk.pdf>
+ Android NDK CMake guide: <https://developer.android.com/ndk/guides/cmake>
