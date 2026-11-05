# Raspberry Pi Pico PIO (Programmable I/O)

PIO is a set of small, programmable state machines inside the RP2040 (Pico, Pico W) and RP2350 (Pico 2) that drive GPIO pins
with cycle-exact timing, independently of the CPU cores. You use it to build interfaces in "software-defined hardware":
WS2812 LEDs, extra UART/SPI/I2C ports, quadrature encoders, DPI/VGA video, logic analyzers, and custom protocols.

The CPU (or DMA) only exchanges data with the state machines through FIFOs; the timing is handled by the PIO program.

## 1. Hardware overview

| | RP2040 | RP2350 |
| --- | --- | --- |
| PIO blocks | 2 (`pio0`, `pio1`) | 3 (`pio0`–`pio2`) |
| State machines (SMs) per block | 4 | 4 |
| Instruction memory per block | 32 instructions, shared by its 4 SMs | 32 instructions, shared by its 4 SMs |
| PIO version | v0 | v1 (adds a few features, e.g. more `wait`/`mov` options, FIFO random access) |

Each state machine has:

+ **OSR** (output shift register) and **ISR** (input shift register), 32 bits each.
+ Two **scratch registers**, `X` and `Y`, 32 bits each (used as counters and temporary storage).
+ A **TX FIFO** (CPU → SM) and an **RX FIFO** (SM → CPU), 4 words each. They can be joined into one 8-word FIFO in one direction.
+ A **clock divider** (16-bit integer + 8-bit fraction): the SM runs at `clk_sys / div`. Default `clk_sys` is 125 MHz on RP2040 and 150 MHz on RP2350.
+ Pin mappings: separate base/count settings for `out`, `set`, `in`, side-set, and the `jmp pin`.

Every instruction takes **one cycle** (plus optional delay), so timing is fully deterministic. A `wait` instruction, or `push`/`pull` with
a full or empty FIFO, stalls until its condition is met.

Each PIO block also has 8 IRQ flags, used to synchronize state machines with each other and (some of them) to interrupt the CPU.

## 2. The nine instructions

PIO assembly has nine instructions. `nop` is a pseudo-instruction (assembled as `mov y, y`).

| Instruction | Syntax | What it does |
| --- | --- | --- |
| `jmp` | `jmp [cond] target` | Jump if the condition is true. Conditions: (always), `!x`, `x--`, `!y`, `y--`, `x!=y`, `pin`, `!osre` |
| `wait` | `wait <0\|1> <gpio\|pin\|irq> <index>` | Stall until a GPIO, a mapped input pin, or an IRQ flag has the given level |
| `in` | `in <src>, <bits>` | Shift bits into the ISR. Sources: `pins`, `x`, `y`, `null`, `isr`, `osr` |
| `out` | `out <dest>, <bits>` | Shift bits out of the OSR. Destinations: `pins`, `x`, `y`, `null`, `pindirs`, `pc`, `isr`, `exec` |
| `push` | `push [iffull] [block\|noblock]` | Move the ISR to the RX FIFO and clear the ISR. Blocks by default if the FIFO is full |
| `pull` | `pull [ifempty] [block\|noblock]` | Load the OSR from the TX FIFO. Blocks by default if the FIFO is empty |
| `mov` | `mov <dest>, [op] <src>` | Copy. Destinations: `pins`, `x`, `y`, `exec`, `pc`, `isr`, `osr`. Sources: `pins`, `x`, `y`, `null`, `status`, `isr`, `osr`. Ops: `!` (invert), `::` (bit-reverse) |
| `irq` | `irq [set\|nowait\|wait\|clear] <n> [rel]` | Set or clear an IRQ flag; `irq wait` sets it and waits until something clears it |
| `set` | `set <dest>, <value>` | Write a 5-bit immediate (0–31) to `pins`, `pindirs`, `x`, or `y` |

+ `pull noblock` with an empty FIFO copies `X` into the OSR, which is a common way to "keep the last value".
+ **Autopush / autopull**: the SM can push the ISR or refill the OSR automatically when a threshold number of bits is shifted,
  which saves the explicit `push`/`pull` instructions in tight loops.
+ The FIFOs are not main memory. The CPU accesses them with `pio_sm_put*()` / `pio_sm_get*()`, or DMA moves data to and from them.

## 3. Delay and side-set

Every instruction has 5 spare bits, shared between a **delay** and **side-set**:

```text
<instruction> [side <value>] [<delay>]
set pins, 1   side 0 [7]
```

+ **Delay** `[n]`: after the instruction, the SM idles for `n` extra cycles. No extra instruction memory is used.
+ **Side-set** `side <v>`: drives up to 5 side-set pins at the same time as the instruction executes (e.g. a clock line while `out` drives data).
+ Side-set bits come out of the 5 bits, so the maximum delay is `2^(5 - side-set bits) - 1`:

| `.side_set` directive | Bits used | Max delay |
| --- | --- | --- |
| none | 0 | 31 |
| `.side_set 1` | 1 | 15 |
| `.side_set 1 opt` | 2 (1 + "enable" bit) | 7 |
| `.side_set 2` | 2 | 7 |

+ Without `opt`, **every** instruction must have a `side` value. With `opt`, it is optional, at the cost of one more bit.
+ `.side_set <n> pindirs` drives pin directions instead of pin values.

## 4. The `.pio` file

A `.pio` file contains one or more PIO programs plus optional code blocks for the target language.
The **pioasm** assembler (part of the Pico SDK) turns it into a header, `<name>.pio.h`, with the encoded program and helper functions.

### 4.1 Directives

| Directive | Meaning |
| --- | --- |
| `.program <name>` | Start a program; generates `<name>_program` and `<name>_program_get_default_config()` |
| `.define [PUBLIC] <symbol> <value>` | Constant; `PUBLIC` exports it to the header as `<program>_<symbol>` |
| `.side_set <n> [opt] [pindirs]` | Configure side-set (section 3) |
| `.wrap_target` / `.wrap` | Loop: after the instruction before `.wrap`, execution continues at `.wrap_target` with no `jmp` and no extra cycle |
| `.origin <addr>` | Require the program to be loaded at a fixed address (e.g. when it relies on absolute addresses via `out pc` / `mov pc`) |
| `.word <value>` | Insert a raw 16-bit instruction |
| `public <label>:` | Export a label address to the header |
| `.pio_version <0\|1>` | Target PIO version (RP2350 features need `1`; newer SDKs) |

Comments start with `;` or `//`.

### 4.2 Language blocks

Text between `% c-sdk {` and `%}` is copied unchanged into the generated `.pio.h`. It normally holds an `..._init()` function
that configures the state machine with SDK calls. The `%` markers are needed because the C code contains its own `{}`;
only `%}` on its own ends the block. pioasm also has other output formats (for example `python` for MicroPython) with their own `% <lang> {` blocks.

## 5. Example: two out-of-phase square waves

`blink.pio`: one pin driven with `set`, a second pin with side-set, toggling in opposite phase.

```text
.program blink
.side_set 1 opt               ; 1 side-set pin, optional -> max delay 7

.wrap_target
    set pins, 1   side 0 [7]  ; set pin high, side-set pin low, then wait 7 cycles
    set pins, 0   side 1 [7]  ; set pin low,  side-set pin high, then wait 7 cycles
.wrap                         ; jump back to .wrap_target for free

% c-sdk {
static inline void blink_program_init(PIO pio, uint sm, uint offset,
                                      uint set_pin, uint side_pin, float div)
{
    pio_sm_config c = blink_program_get_default_config(offset);  /* includes wrap and side-set settings */

    sm_config_set_set_pins(&c, set_pin, 1);
    sm_config_set_sideset_pins(&c, side_pin);
    sm_config_set_clkdiv(&c, div);

    pio_gpio_init(pio, set_pin);                                  /* give the pins to this PIO block */
    pio_gpio_init(pio, side_pin);
    pio_sm_set_consecutive_pindirs(pio, sm, set_pin, 1, true);    /* outputs */
    pio_sm_set_consecutive_pindirs(pio, sm, side_pin, 1, true);

    pio_sm_init(pio, sm, offset, &c);
    pio_sm_set_enabled(pio, sm, true);
}
%}
```

`main.c`:

```c
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "blink.pio.h"

int main(void)
{
    PIO pio = pio0;
    uint offset = pio_add_program(pio, &blink_program);   /* load into instruction memory */
    uint sm = pio_claim_unused_sm(pio, true);             /* true = panic if none is free */

    blink_program_init(pio, sm, offset, 15, 16, 65535.0f);

    while (true)
        tight_loop_contents();                            /* the CPU is free; PIO does the work */
}
```

Timing: one period is 2 instructions × (1 + 7) cycles = 16 SM cycles. With `div = 65535` and a 125 MHz `clk_sys`,
the SM runs at about 1.9 kHz, so each pin toggles at about 119 Hz (too fast to see blink; measure it with a scope or logic analyzer).
The slowest PIO clock is limited by the divider, so a visible blink needs a counting loop (`X`/`Y` with `jmp x--`) or delays fed from the CPU.

`CMakeLists.txt` additions:

```cmake
pico_generate_pio_header(blink ${CMAKE_CURRENT_LIST_DIR}/blink.pio)
target_link_libraries(blink pico_stdlib hardware_pio)
```

## 6. Useful SDK functions

| Function | Purpose |
| --- | --- |
| `pio_add_program()` / `pio_can_add_program()` | Load a program, or check that it fits |
| `pio_claim_unused_sm()` | Get a free state machine |
| `pio_sm_put_blocking()` / `pio_sm_get_blocking()` | Write to the TX FIFO / read from the RX FIFO, waiting if needed |
| `pio_sm_set_enabled()` | Start or stop an SM |
| `pio_sm_exec()` | Execute one instruction immediately (e.g. to preload `X`) |
| `sm_config_set_out_pins()`, `sm_config_set_in_pins()`, `sm_config_set_jmp_pin()` | Pin mappings |
| `sm_config_set_out_shift()`, `sm_config_set_in_shift()` | Shift direction, autopull/autopush and threshold |
| `sm_config_set_fifo_join()` | Join both FIFOs into one 8-entry FIFO |

Start from the programs in `pico-examples/pio` (WS2812, UART TX/RX, SPI, I2C, quadrature encoder) instead of writing protocols from scratch.

## Related notes

+ [RPi_pico_Cxx_SDK.md](RPi_pico_Cxx_SDK.md): Pico C/C++ SDK, CMake, and `.uf2` flashing

## Reference

+ RP2040 datasheet, chapter 3 (PIO): <https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf>
+ RP2350 datasheet (PIO chapter): <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>
+ Raspberry Pi Pico C/C++ SDK book (PIO and pioasm): <https://datasheets.raspberrypi.com/pico/raspberry-pi-pico-c-sdk.pdf>
+ Pico SDK API documentation: <https://www.raspberrypi.com/documentation/pico-sdk/>
+ PIO examples: <https://github.com/raspberrypi/pico-examples/tree/master/pio>
