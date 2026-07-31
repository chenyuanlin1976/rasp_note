# the PIO of RPi pico

Programmable Input/Output (PIO) is a specialized hardware subsystem on the Raspberry Pi Pico's RP2040 chip  
designed to build custom, deterministic hardware interfaces.  
It operates independently of the main dual-core ARM CPUs, executing precise assembly code to offload timing-critical tasks  
like handling WS2812B LEDs, custom SPI/I2C variants, or video output.

## Hardware Overview

+ Two Blocks: The RP2040 features 2 independent PIO hardware blocks.
+ State Machines: Each block contains 4 state machines, totaling 8 execution units.
+ Shared Memory: Each block shares a 32-instruction memory space for assembly code.
+ FIFOs: Dedicated TX (Transmit) and RX (Receive) buffers handle main-CPU communication.

## The 9 Base Instructions

PIO programs are written in a dedicated assembly language consisting of exactly nine core instructions:

+ `JUMP`: Moves execution to a different instruction address based on a condition.
+ `WAIT`: Pauses execution until a pin, IRQ flag, or bit meets a specific state.
+ `IN`: Shifts data bits from a source (pins, scratch) into the Input Shift Register (ISR).
+ `OUT`: Shifts data bits out of the Output Shift Register (OSR) to a destination.
+ `PUSH`: Sends data from the ISR to the main memory RX FIFO.
+ `PULL`: Fetches data from the main memory TX FIFO into the OSR.
+ `MOV`: Copies data from a source location to a destination location.
+ `IRQ`: Sets, clears, or waits on interrupt request flags across the system.
+ `SET`: Directly writes immediate values (0–31) to configured pins or scratch registers.

## Key Concept: Delay and Wrapping

+ Side-Set and Delays: Every instruction can include a trailing delay like [19],  
  pausing the hardware for **up to 31 clock cycles** without consuming extra memory lines.
+ Automatic Wrapping: The `.wrap_target` and `.wrap` keywords loop the state machine automatically in hardware.  
  This configuration costs zero execution time and uses zero instruction spaces.

## program .pio file

A .pio file contains the hardware assembly instructions and setup configurations for the Raspberry Pi Pico's Programmable I/O (PIO) state machines.  
When compiled by the tool **pioasm**, it outputs a C/C++ header file (**.pio.h**) that integrates into your application.

### Structure of a .pio File

A standard **.pio** file is divided into 3 primary segments:

1. Directives: Configures the state machine properties and marks the program entry point.
2. Assembly Instructions: The 9 core commands that control the hardware state machine.
3. C Software Helper Block (Optional): Embedded C code to auto-generate state machine setup helper functions.

```C
; Comments start with a semicolon

.program hello_blink     ; 1. Directives: Defines the program name
.side_set 1 opt          ; Configures side-set behavior

wrap_target              ; 2. Assembly Instructions: Program loop start
    set pins, 1   side 0 ; Turn LED on, clear side-set pin
    set pins, 0   side 1 ; Turn LED off, set side-set pin
wrap                     ; Program loop end

% c-sdk {                // 3. Embedded C SDK Helper Block
static inline void hello_blink_program_init(PIO pio, uint sm, uint offset, uint pin) {
    pio_sm_config c = hello_blink_program_get_default_config(offset);
    sm_config_set_set_pins(&c, pin, 1);
    pio_gpio_init(pio, pin);
    pio_sm_set_consecutive_pindirs(pio, sm, pin, 1, true);
    pio_sm_init(pio, sm, offset, &c);
}
%}
```

### 1. Directives Syntax

Directives begin with a dot (`.`) and instruct pioasm how to compile the assembly block.

+ `.program <name>`: Marks the start of a PIO program and assigns a namespace for generated C constants.
+ `.define <name> <value>`: Sets a global key-value constant (similar to #define in C).
+ `.side_set <count> [opt] [pindirs]`: Reserves bits for simultaneous execution of side-set pins alongside regular instructions.
+ `.wrap_target` and `.wrap`: Creates an execution loop without costing a `jmp` instruction.

### 2. Instruction Modifiers (Delay & Side-set)

Every PIO instruction can be post-fixed with delay cycles and side-set operations using this structural pattern:

`<instruction> [<delay_count>] [side <side_set_value>]`

+ `Delay [cycles]`: Appending a number inside brackets delays the next instruction execution by 1 to 31 cycles.
+ `Side-set side <value>`: Drives designated side-set pins to high/low states concurrently with the base command execution.

### 3. The 9 Core Assembly Instructions

The Raspberry Pi Pico PIO assembly language utilizes exactly 9 native instructions:

+ `jmp [<condition>] <label>`: Jumps to a target label based on register status or pin conditions.
+ `wait <polarity> <source> <index>`: Delays code execution until a pin or IRQ matches the target high/low polarity.
+ `in <source> <bit_count>`: Shifts data bits from a source (pins, status, counter) into the Input Shift Register (ISR).
+ `out <destination> <bit_count>`: Shifts data bits out of the Output Shift Register (OSR) to a destination.
+ `push [block / noblock]`: Transfers data from the ISR directly into the RX FIFO.
+ `pull [block / noblock]`: Loads data from the TX FIFO into the OSR.
+ `mov <destination>, <source>`: Copies data between internal hardware registers (X, Y, OSR, ISR, Pins).
+ `irq [<modifiers>] <irq_num>`: Sets, clears, or waits for internal or CPU system interrupt flags.
+ `set <destination>, <value>`: Writes an immediate 5-bit raw integer directly into Pins or registers X/Y.

### 4. Code Generation Block (% c-sdk)

Text enclosed between `% c-sdk {` and `%}` is parsed by pioasm and copied directly into the compiled **.pio.h** output header file.  
This block is typically written in C/C++ to create initialization templates using functions from the Pico C/C++ SDK,  
bridging the low-level hardware configuration directly into your main runtime code.

#### How pioasm Uses the % Symbol

The `%` character is used in the **.pio** file syntax as a special marker (or tag)  
to tell the pioasm compiler that it is leaving the PIO assembly language syntax  
and entering a different language block (like C/C++).  

The pioasm compiler parses the file line by line.  
It relies on specific delimiters to identify where code blocks begin and end:  

+ `% c-sdk {` tells the compiler: "Stop treating the following lines as PIO assembly. Start capturing this raw text as C/C++ code."
+ `%}` tells the compiler: "The C/C++ code block is finished. Switch back to parsing PIO file syntax."

#### Why a Regular Curly Bracket {} Is Not Enough

In many programming languages, curly brackets `{}` are enough to scope a block of code.  
However, the PIO syntax needs the `%` symbol for 2 reasons:

+ Syntax Protection: The C/C++ code block inside the .pio file will contain its own regular curly brackets `{}` for functions,  
  if statements, and loops. If pioasm only looked for a closing `}`,  
  it would get confused by the very first closing bracket inside your C function and end the block too early.  
  The combination of `%}` ensures the compiler only triggers on the absolute end of the block.
+ Compiler Directives Heritage: Using `%` to embed external code blocks is a classic design pattern  
  borrowed from older parser-generator tools like Lex/Yacc and Flex/Bison, which use `%{` and `%}` sections to inject raw C code into generated files.  
  The creators of the Raspberry Pi Pico adopted this standard because it is highly efficient for writing custom compiler scripts.
