# Power tree and power sequencing

A **power tree** is a diagram of how power enters a board and branches out, through protection parts, converters, regulators, and load switches, into every **voltage rail** (e.g. `VCC12V_DCIN`, `VCC5V0_SYS`, `VCC_3V3`, `VCC_1V8`, `VDD_LOGIC`).
Think of a city water network: the main supply enters at the root, is stepped down at stations along the way, and branches out to neighborhoods that each need a specific pressure (voltage) and flow (current).

**Power sequencing** is the order and timing in which those rails turn on and off.
Many chips are damaged or fail to boot if it is wrong.

## 1. What a power tree shows

```text
DC jack 12 V -- fuse/TVS -- VCC12V_DCIN
                              |
                              +-- buck --> VCC5V0_SYS
                                             |
                                             +-- load switch --> VCC5V0_USB      (USB ports)
                                             +-- PMIC
                                                   +-- buck --> VDD_LOGIC, VDD_GPU, VDD_CPU (SoC cores)
                                                   +-- buck --> VCC_DDR          (DRAM)
                                                   +-- buck --> VCC_3V3          (I/O, peripherals)
                                                   +-- LDO  --> VCC_1V8          (I/O banks, codec)
                                                   +-- LDO  --> VDDA_0V9 ...     (PLL, analog)
```

This is a generic example in the style of an RK3566 board; the real rail names, converters, and order come from the board schematic.
Some boards supply the CPU core from a separate buck chip instead of the PMIC.

For every rail, a good power tree documents:

| Item | Example |
| --- | --- |
| **Source and type** | external adapter, battery, PMIC buck, discrete LDO; switching or linear |
| **Voltage and current budget** | 3.3 V, 120 mA typical, 500 mA peak |
| **Parent rail** | `VCC5V0_SYS` feeds the PMIC, which feeds `VCC_3V3` |
| **Enable and power-good** | `EN` pin, PMIC sequence slot, `PGOOD` output, reset line |

## 2. Why the sequence matters

SoCs (such as the RK3566), FPGAs, DRAM, and high-speed interfaces often cannot tolerate their rails appearing or disappearing in arbitrary order.
A wrong sequence can cause:

+ **Back-powering**: when a pin or I/O rail is at a higher voltage than an unpowered supply of the same chip, current flows through the internal ESD protection diodes into that supply.
  The unpowered block is partly powered, pins take undefined states, and the extra current can damage the chip.
+ **Latch-up**: an injected current can trigger the parasitic thyristor (SCR) in CMOS silicon, creating a low-resistance path from supply to ground.
  It persists until power is removed and can overheat or destroy the chip.
+ **Boot hangs or corrupted state**: reset is released before rails and clocks are stable, or core and memory rails settle in the wrong order. The chip fails to boot or locks up intermittently.
+ **Shutdown glitches**: logic rails drop before I/O rails or before reset is asserted, so outputs glitch, or a still-powered peripheral back-feeds the board.

There is no universal order. A common pattern is core rails first and I/O rails last, but some chips require the opposite or allow any order within limits.
The SoC datasheet or hardware design guide is the authority.

## 3. Power-on checks

1. **Follow the datasheet order**: check the required order of core, memory, analog/PLL, and I/O rails, or the PMIC power groups.
   On RK3566 boards the PMIC (RK809) runs a preset power-on sequence; check that the board's extra rails fit into it.
2. **Monotonic ramps and voltage limits**: rails should rise smoothly, without dips or double bumps, and stay within the allowed difference between related rails (e.g. I/O vs. core, supply vs. reference).
3. **`EN` / `PGOOD` chain**: a downstream converter must not enable before its upstream supply is in regulation.
   Chaining the `PGOOD` output of one converter to the `EN` input of the next enforces this.
4. **Reset timing**: reset stays asserted until all required rails and reference clocks are stable, then releases cleanly.
   A voltage supervisor (reset IC) does this in hardware.

## 4. Power-off checks

1. **Controlled order**: many designs expect shutdown in reverse power-on order, or at least loads and peripherals disabled before rails collapse.
2. **Slow decay**: large capacitors on lightly loaded rails can stay charged for tens to hundreds of milliseconds.
   If one rail collapses quickly while a connected rail bleeds down slowly, the voltage difference across a chip can exceed its limits.
   Bleed resistors or the active output discharge built into many PMICs and load switches pull rails down in a defined time.
3. **Sudden power loss**: users pull the plug or the battery. Check this case too; a supervisor that asserts reset when a rail falls below its threshold (brownout) keeps the SoC from running on a collapsing supply.
4. **Unpowered peripherals**: never drive a signal into an unpowered chip's pins, from the board or from an external cable (see [voltage_mismatch.md](voltage_mismatch.md)).

## 5. Bring-up checklist

+ **Use an oscilloscope**: capture key rails (`VIN`, `SYS`, core, I/O) and `RESET` together during power-on and power-off. A multimeter after boot shows only the steady state.
+ **Test edge cases**: cold boot, warm reboot, fast power cycle (off and straight back on, with rails not yet fully discharged), and unplugging under load.
+ **Check peripheral power domains**: external sensors, displays, or expansion boards must not back-power the main board while it is off, and the board must not back-power them.
+ **Check suspend**: rails switched off in suspend have the same back-powering risk (see [rk3566_suspend.md](../Linux/Power/rk3566_suspend.md)).

## Related notes

+ [electronic_components.md](electronic_components.md): buck, LDO, diodes, TVS, fuses
+ [voltage_mismatch.md](voltage_mismatch.md): logic levels and driving pins of other chips
+ [../Linux/Power/regulators.md](../Linux/Power/regulators.md): PMICs and the Linux regulator framework
+ [../Linux/Power/rk3566_suspend.md](../Linux/Power/rk3566_suspend.md): which rails stay on in suspend
+ [../Linux/DeviceTree/dts_node_mmc_pwrseq.md](../Linux/DeviceTree/dts_node_mmc_pwrseq.md): software-controlled power sequence for SDIO Wi-Fi chips

## Reference

+ [Linux voltage and current regulator API](https://docs.kernel.org/power/regulator/overview.html)
+ [Wikipedia: Latch-up](https://en.wikipedia.org/wiki/Latch-up)
+ The SoC datasheet and hardware design guide from the vendor (power sequence and rail limits)
