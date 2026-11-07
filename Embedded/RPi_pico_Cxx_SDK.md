# Raspberry Pi Pico C/C++ SDK

The Pico SDK provides the headers, libraries, and CMake build system for writing C and C++ programs for the
RP2040 (Pico, Pico W) and RP2350 (Pico 2, Pico 2 W) microcontrollers. Programs are compiled to native machine code and run without an operating system.

Source: <https://github.com/raspberrypi/pico-sdk> (examples: <https://github.com/raspberrypi/pico-examples>)

## 1. C/C++ SDK vs MicroPython

| | C/C++ SDK | MicroPython |
| --- | --- | --- |
| Execution | Compiled to native code | Python compiled to bytecode on the board, then interpreted |
| Speed and timing | Fast and predictable | Much slower; garbage collection can add pauses |
| Memory | Only what your program uses | The interpreter and heap take a large part of the RAM |
| Hardware access | Every peripheral and register, PIO, DMA, both cores | Most peripherals through the `machine` and `rp2` modules |
| Workflow | Edit, build, flash | Edit and run immediately over the REPL |

Use the SDK for tight timing (motor control, fast protocols), maximum throughput, or full control. MicroPython is quicker for prototyping.

## 2. Library layers

The SDK is a set of CMake **INTERFACE libraries**: you link only the ones you use.

| Layer | Examples | Purpose |
| --- | --- | --- |
| `hardware_*` | `hardware_gpio`, `hardware_uart`, `hardware_spi`, `hardware_i2c`, `hardware_pwm`, `hardware_adc`, `hardware_dma`, `hardware_pio` | Thin APIs over one peripheral's registers |
| `pico_*` | `pico_stdlib`, `pico_stdio_usb`, `pico_multicore`, `pico_time`, `pico_cyw43_arch_*` (Wi-Fi on Pico W) | Higher-level functions built on the hardware libraries |
| `pico_stdlib` | GPIO, UART, time, `stdio` | Convenience bundle that most programs link |

+ `stdio_init_all()` connects `printf()` / `getchar()` to the `stdio` targets enabled in CMake: UART (GPIO 0/1 by default) and/or USB CDC.
  On a Linux host, USB `stdio` appears as `/dev/ttyACM0`; see [../Comm/USB_CDC.md](../Comm/USB_CDC.md).
+ `hardware_pio` programs the PIO state machines; see [RPi_pico_PIO.md](RPi_pico_PIO.md).

## 3. Example program

`blink.c`:

```c
#include <stdio.h>
#include "pico/stdlib.h"

int main(void)
{
    stdio_init_all();                        /* USB and/or UART, as enabled in CMakeLists.txt */

    const uint led = PICO_DEFAULT_LED_PIN;   /* GPIO 25 on Pico and Pico 2 */
    gpio_init(led);
    gpio_set_dir(led, GPIO_OUT);

    while (true) {
        gpio_put(led, 1);
        printf("LED on\n");
        sleep_ms(500);
        gpio_put(led, 0);
        sleep_ms(500);
    }
}
```

On the Pico W and Pico 2 W the LED is connected to the CYW43 wireless chip, not to a GPIO, and `PICO_DEFAULT_LED_PIN` is not defined.
Use `cyw43_arch_init()` and `cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1)`, and link `pico_cyw43_arch_none`.

## 4. Build system: CMake

CMake generates the actual build files (Makefiles or Ninja); you describe the project in `CMakeLists.txt`.

```cmake
cmake_minimum_required(VERSION 3.13)

# Copy pico_sdk_import.cmake from the SDK's external/ directory into the project.
# It must be included before project().
include(pico_sdk_import.cmake)

project(blink C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(blink blink.c)
target_link_libraries(blink pico_stdlib)

# stdio over USB CDC, not UART
pico_enable_stdio_usb(blink 1)
pico_enable_stdio_uart(blink 0)

# also create .uf2, .bin, .hex, .dis, .map (without this you only get .elf)
pico_add_extra_outputs(blink)
```

Build from the command line:

```shell
export PICO_SDK_PATH=~/pico/pico-sdk         # where the SDK is cloned (with submodules, for TinyUSB and CYW43)
mkdir build && cd build
cmake -DPICO_BOARD=pico2 ..                  # pico (default), pico_w, pico2, pico2_w, ...
make -j"$(nproc)"                            # -> blink.uf2, blink.elf, ...
```

`PICO_BOARD` selects the chip and board pin definitions; use a fresh build directory when you change it.
The compiler is `arm-none-eabi-gcc` (the RP2350 can also run RISC-V code, with a RISC-V toolchain).

## 5. Flashing

**UF2 drag and drop**: UF2 is a USB flashing format created by Microsoft (for MakeCode).

1. Hold **BOOTSEL** while plugging in the USB cable (or while pressing reset on boards that have one).
2. The board appears as a USB mass-storage drive (`RPI-RP2` for RP2040, `RP2350` for RP2350).
3. Copy the `.uf2` file to the drive. The board writes it to flash, reboots, and runs the program.

**picotool** (also needs BOOTSEL mode, or a running program that includes USB `stdio` reset support):

```shell
picotool info -a                 # show what is on the board
picotool load -x blink.uf2       # load and execute (-f forces a running device into BOOTSEL mode first)
```

**SWD debug**: with a Raspberry Pi Debug Probe (or a second Pico running debugprobe) and OpenOCD/GDB, you can flash `.elf` files and debug with breakpoints.

## 6. VS Code workflow

The official **Raspberry Pi Pico** extension for VS Code can download the SDK, the toolchain, CMake, Ninja, and picotool,
create a new project from a template, and build, flash, and debug it. This is the easiest setup on Windows and macOS.
The command-line build in section 4 works the same way underneath.

## Related notes

+ [RPi_pico_PIO.md](RPi_pico_PIO.md): PIO state machines and `pioasm`
+ [../Comm/USB_CDC.md](../Comm/USB_CDC.md): USB CDC serial (`stdio` over USB)
+ [../DevTools/CMakeLists_syntax.md](../DevTools/CMakeLists_syntax.md): CMake syntax
+ [RTOS_intro.md](RTOS_intro.md): running an RTOS (e.g. FreeRTOS) on microcontrollers

## Reference

+ Raspberry Pi Pico C/C++ SDK book: <https://datasheets.raspberrypi.com/pico/raspberry-pi-pico-c-sdk.pdf>
+ Getting started with Raspberry Pi Pico-series: <https://datasheets.raspberrypi.com/pico/getting-started-with-pico.pdf>
+ Pico SDK API documentation: <https://www.raspberrypi.com/documentation/pico-sdk/>
+ Pico microcontroller documentation: <https://www.raspberrypi.com/documentation/microcontrollers/>
+ picotool: <https://github.com/raspberrypi/picotool>
