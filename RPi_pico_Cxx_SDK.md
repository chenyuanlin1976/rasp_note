# The Raspberry Pi Pico C/C++ SDK

The Raspberry Pi Pico C/C++ SDK (Software Development Kit) provides the low-level headers, libraries,  
and build system needed to write high-performance C or C++ programs for the RP2040 and RP2350 microcontrollers.  
Unlike MicroPython, which interprets code line-by-line,  
the C/C++ SDK compiles your code directly into machine language, unlocking the absolute maximum speed and control over the hardware.

[pico-sdk](https://github.com/raspberrypi/pico-sdk)

## Why Use the C/C++ SDK?

+ Maximum Performance: Executes code significantly faster than MicroPython.
+ Predictable Timing: Critical for precise motor control or high-speed communication.
+ Low Memory Footprint: Leaves almost the entire RAM free for your data.
+ Full Feature Access: Gives you unrestricted control over every internal register and peripheral.

## Core Components of the SDK

The SDK is divided into two main layers to make coding easier:

1. High-Level Libraries (`pico_stdlib`):  
   This layer provides high-level, human-readable functions for everyday tasks.  
   It groups common hardware functions together so you do not have to write boilerplate code.  
   + `pico_stdlib`: Automatically bundles basic functions for GPIO, UART, and time tracking.
   + Standard I/O: Maps functions like `printf()` directly to the USB or UART serial output.  
2. Low-Level Hardware Drivers (`hardware_`)  
   This layer interfaces directly with the silicon registers.  
   You use these libraries when you need precise control over specific hardware modules.  
   + `hardware_gpio`: Detailed control of input/output pins.
   + `hardware_pio`: Program the unique Programmable I/O blocks for custom protocols.
   + `hardware_dma`: Direct Memory Access to move data without using the CPU.
   + `hardware_adc` / `hardware_pwm`: Control analog inputs and pulse-width modulation.

## The Build System: CMake

The Pico SDK does not use traditional, messy Makefiles.  
Instead, it relies on **CMake** to manage projects. CMake acts as a project generator.  

+ You write a simple text file called `CMakeLists.txt` to describe your project,  
+ CMake automatically finds the SDK files and prepares the compiler.

### Example CMakeLists.txt Structure

```CMakeLists.txt
cmake_minimum_required(VERSION 3.13)

# Include the Pico SDK configuration
include(pico_sdk_import.cmake)

project(my_project C CXX ASM)

# Initialize the SDK
pico_sdk_init()

# Define your executable project file
add_executable(my_blink blink.c)

# Link the standard libraries you need
target_link_libraries(my_blink pico_stdlib)

# Enable USB serial output, disable UART serial output
pico_enable_stdio_usb(my_blink 1)
pico_enable_stdio_uart(my_blink 0)
```

### Compilation Output: The .uf2 File

When you compile a project using the SDK, the compiler generates a few different file types,  
but the most important one is the **.uf2** file.

+ What it is: A plug-and-play flashing format designed by Microsoft.
+ How it works: You hold the **BOOTSEL** button on your Pico, plug it into your computer,  
  and it appears as a USB flash drive.  
  You simply drag and drop your compiled **.uf2** file into that drive,  
  and the Pico instantly programs itself and runs your C/C++ code.

### Setup and Workflow

1. The Official Tool: Install Visual Studio Code (VS Code).
2. The Extension: Install the official **Raspberry Pi Pico extension** inside VS Code.
3. Automated Setup: The extension automatically downloads the CMake tools,  
   the ARM GCC compiler (to compile code for the Pico's ARM processor), and the correct version of the SDK.
4. Coding: You can generate a new project with one click, write your code, and hit "Build" to get your **.uf2** file.
