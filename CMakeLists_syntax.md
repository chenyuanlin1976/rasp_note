# common in CMakeLists.txt

Here are the most common functions and commands used in a Raspberry Pi Pico **CMakeLists.txt** file,  
along with a brief explanation of what they do:

## 1. Project Setup & Initialization

+ `cmake_minimum_required(VERSION <version>)`: Sets the minimum version of CMake required to build the project  
  (typically VERSION 3.13 or higher for the Pico SDK).
+ `project(<proj_name> [Languages])`: Names your project and specifies the programming languages used (usually C CXX ASM).
+ `pico_sdk_init()`: Initializes the Raspberry Pi Pico SDK. This must be called right after project().

## 2. Defining Targets & Sources

+ `add_executable(<target_name> <source_files>)`: Defines an executable binary target and lists the source files (e.g., main.c) required to build it.
+ `target_sources(<target_name> PRIVATE <files>)`: Adds additional source or header files to an existing target later in the file.

## 3. Linking Libraries & Dependencies

+ `target_link_libraries(<target_name> <libraries>)`: Links hardware drivers or libraries to your target  
  (e.g., pico_stdlib, hardware_spi, hardware_i2c, hardware_adc).

## 4. Input/Output Configuration (USB/UART)

+ `pico_enable_stdio_usb(<target_name> <0|1>)`: Enables (1) or disables (0) standard input/output (like printf) over the USB port (CDC).
+ `pico_enable_stdio_uart(<target_name> <0|1>)`: Enables (1) or disables (0) standard input/output over the physical UART pins (TX/RX).

## 5. Build Outputs & Binaries

+ `pico_add_extra_outputs(<target_name>)`: Generates extra binary formats needed for the Pico,  
   most notably the .uf2 file used for drag-and-drop flashing via USB, as well as .hex and .bin files.

## 6. Include Directories & Compile Options

+ `target_include_directories(<target_name> PRIVATE <dir>)`: Adds custom include directories (folders containing your header files) to the target's search path.
+ `target_compile_definitions(<target_name> PRIVATE <macro>)`: Defines preprocessor macros for your code (e.g., setting custom baud rates or debugging flags).
