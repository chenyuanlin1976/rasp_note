# Basic electronic components

Every circuit, from a power rail on an RK3566 carrier board to a sensor interface, is built from a small set of passive and active components.
This note covers what each part does, where it shows up on a typical board, and how to recognize it on the silkscreen.

Terminology: the parts are a **resistor**, **capacitor**, and **inductor**; their electrical properties are **resistance**, **capacitance**, and **inductance**.

## 1. Basics

+ **Voltage (V)**: electrical potential difference, like water pressure. Unit: volt (V).
+ **Current (I)**: flow rate of electric charge, like water flow. Unit: ampere (A).
+ **Power (P)**: P = V × I. Unit: watt (W).
+ **Passive components**: cannot amplify or add net energy to a circuit. They dissipate energy as heat or store it temporarily in an electric or magnetic field (resistors, capacitors, inductors).
+ **Active components**: semiconductors that need an external supply and let a small control signal switch or amplify a larger current (transistors, ICs).
  Diodes are semiconductors too and are usually listed with them, although a diode alone cannot amplify.

## 2. Passive components

### 2.1 Resistor

Opposes current and turns electrical energy into heat.
Ohm's law: V = I × R. Unit: ohm (Ω).

+ **Current limiting**: protects LEDs, GPIO pins, or optocoupler inputs from excess current.
+ **Voltage divider**: two resistors in series scale a voltage down, e.g. a battery rail into an ADC input.
+ **Pull-up / pull-down**: holds a line that would otherwise float (I2C, reset, boot-strap pins) at a known high or low level.
+ **Termination / series damping**: reduces reflections on fast signal lines.

### 2.2 Capacitor

Stores energy in an **electric field** between two plates separated by a dielectric.
I = C × dV/dt. Unit: farad (F).
A capacitor **resists sudden changes in voltage**: it blocks DC and passes AC and high-frequency ripple.

+ **Decoupling / bypass**: small ceramic caps (typically 100 nF) right next to IC power pins (SoC, DRAM) supply fast current spikes and shunt high-frequency noise to ground.
+ **Bulk smoothing**: larger caps (µF range) reduce ripple after a rectifier or at the input and output of a buck/boost converter.
+ **Filtering and timing**: with a resistor it forms an RC low-pass or high-pass filter, or an RC delay (e.g. a power-on reset).

### 2.3 Inductor and ferrite bead

An inductor is a coil that stores energy in a **magnetic field** while current flows.
V = L × dI/dt. Unit: henry (H).
An inductor **resists sudden changes in current**: it passes DC easily and opposes high-frequency AC.

+ **Switching regulators**: the energy-storage element in buck and boost converters (see [section 6](#6-buck-converter)).
+ **EMI filtering**: LC filters on power and signal lines.
+ **Ferrite bead**: a lossy inductor that turns high-frequency noise into heat instead of storing it. Common on power rails and noisy lines; marked `FB` or `L` on the silkscreen.

## 3. Semiconductors

### 3.1 Diode

A two-terminal device (PN junction or Schottky barrier) that conducts in **one direction**.
In forward bias it conducts once the forward voltage is exceeded: about 0.2–0.4 V for Schottky, about 0.6–0.7 V for silicon, and roughly 1.8–3.3 V for LEDs depending on color.
In reverse bias it blocks, up to its breakdown voltage.

+ **Rectification**: converts AC into pulsating DC.
+ **Reverse-polarity protection**: blocks current if the supply leads are swapped.
+ **Flyback (freewheeling) diode**: gives an inductive load (relay coil, motor) a current path when it is switched off, so the voltage spike doesn't destroy the driver transistor.
+ **Clamping and references**: Zener diodes hold a reference voltage; TVS diodes and ESD arrays clamp spikes (see [section 7.3](#73-protection)).

### 3.2 BJT (bipolar junction transistor)

A **current-controlled** device with Base, Collector, and Emitter, available as **NPN** or **PNP**.
A small base current controls a larger collector current: I_C ≈ β × I_B.

+ **Switching**: drives LEDs, small loads, relay coils, or enable lines from a GPIO pin.
+ **Analog amplification**: audio stages and sensor front-ends.
+ It draws base current the whole time it is on, so for efficient high-current switching a MOSFET is usually the better choice.
  BJT vs. MOSFET in detail, and sizing a GPIO-driven switch: [transistor_BJT_MOSFET.md](transistor_BJT_MOSFET.md).

### 3.3 MOSFET (field-effect transistor)

A **voltage-controlled** device with Gate, Source, and Drain, available as **N-channel** or **P-channel** (enhancement mode is by far the most common).
The gate voltage V_GS controls how well the channel conducts between drain and source. The gate is insulated, so it draws almost no steady-state current; it only needs current to charge and discharge the gate capacitance when switching.

+ **Power switching**: the switches inside DC-DC converters, motor drivers, and load switches, thanks to low on-resistance (R_DS(on)).
+ **Load switches**: a P-channel MOSFET on the high side turns a whole rail on and off.
+ **Level shifting**: a single N-channel MOSFET with two pull-ups (e.g. BSS138) is a common bidirectional I2C level shifter (see [voltage_mismatch.md](voltage_mismatch.md)).
+ **GPIO-driven load switch**: a logic-level N-channel MOSFET on the low side, see [transistor_BJT_MOSFET.md](transistor_BJT_MOSFET.md#3-low-side-switch-for-a-gpio-12-v-load-33-v--5-v-pwm).

## 4. Comparison

| Component | Behavior | Energy | Typical role |
| --- | --- | --- | --- |
| **Resistor** | linear, V = IR | dissipates as heat | current limit, divider, pull-up/down |
| **Capacitor** | blocks DC, resists ΔV | electric field | decoupling, smoothing, RC filter/timing |
| **Inductor** | passes DC, resists ΔI | magnetic field | buck/boost converters, LC/EMI filters |
| **Diode** | one-way conduction | none (valve) | rectification, flyback, reverse protection, clamping |
| **BJT** | current-controlled (I_B → I_C) | none (gain/switch) | analog amplification, small-signal switching |
| **MOSFET** | voltage-controlled (V_GS → I_D) | none (gain/switch) | power switching, load switches, drivers |

## 5. Relay

A relay is an electrically operated switch, usually electromechanical: a low-power control signal switches a separate, higher-power or isolated circuit.

```text
 control side                       load side (isolated)

 GPIO -> transistor -> coil  ~~>  armature moves
                                   COM --+
                                         +-- NO   connected while coil is energized
                                         +-- NC   connected while coil is off
```

+ **Coil (control side)**: energizing it creates a magnetic field that pulls the armature.
+ **Contacts (load side)**: **COM** (common), **NO** (normally open), **NC** (normally closed).

Common uses:

+ **Switching mains or heavy loads from a GPIO**: a 3.3 V pin cannot switch 110/230 V AC, motors, or heaters directly.
+ **Galvanic isolation**: coil and contacts share no electrical path, so transients on the load side are less likely to reach the control logic.
+ **Multi-pole switching and fail-safe defaults**: one relay can switch several lines; NC contacts stay closed by spring force when power is lost.

Design notes:

+ **Driver and flyback diode**: a coil needs more current than a GPIO pin can supply and is inductive, so drive it through a BJT or MOSFET and put a flyback diode across the coil (reverse-biased in normal operation).
+ **Wear and speed**: contacts bounce, click, and wear out, so relays are unsuitable for fast switching such as PWM. Use a solid-state relay (SSR) or MOSFET instead.

## 6. Buck converter

A buck converter is a **switching step-down DC-DC converter**: it turns a higher DC input into a lower, regulated DC output with high efficiency.
In the ideal case (continuous conduction):

```text
V_out ≈ D × V_in        D = duty cycle (0..1) = fraction of each period the high-side switch is on
```

How it works:

+ A controller switches a high-side MOSFET on and off at hundreds of kHz to a few MHz.
+ An **inductor** and output **capacitor** smooth the chopped waveform into a steady DC rail.
+ **Asynchronous** bucks use a diode for the low-side path; **synchronous** bucks replace it with a second MOSFET to cut conduction losses (most modern designs and PMIC bucks).

Buck vs. LDO: a linear regulator (LDO) burns the excess voltage as heat, P_loss = (V_in − V_out) × I_load.
Stepping 12 V down to 3.3 V at 2 A, an LDO wastes about 17.4 W, while a buck typically reaches 85–95 % efficiency.

| | Buck | LDO |
| --- | --- | --- |
| **Efficiency** | high, even for large V_in − V_out | ≈ V_out / V_in |
| **Noise** | switching ripple and EMI | very low |
| **Parts** | IC + inductor + caps | IC + caps |
| **Typical rails** | CPU/GPU cores, DRAM, main system rails | analog, audio, sensors, I/O banks |

Common uses:

+ **SoC and system rails**: stepping a 12 V or 5 V input down to core, DDR, and I/O rails (on RK3566 boards mostly inside the PMIC, see [regulators.md](../Linux/Power/regulators.md)).
+ **Battery-powered devices**: longer runtime and less heat when drawing significant current.

Design notes:

+ **Layout**: the switching node has fast di/dt current loops. Keep the loop of input capacitor, switch, and inductor tight, and route the feedback trace away from the switching node, or the output becomes noisy or unstable.
+ **Ripple**: some output ripple at the switching frequency is unavoidable; add an LC stage or a following LDO for noise-sensitive rails.

## 7. Other parts on a typical PCB

### 7.1 Integrated circuits

+ **SoC / MCU**: the main compute or control chip.
+ **PMIC and regulators**: multi-rail power chips, buck and LDO regulators that generate the core, memory, and I/O rails.
+ **Interface chips**: transceivers and bridges for USB, Ethernet (PHY), RS-485, CAN, UART, I2C, SPI, plus **level shifters** between logic voltages (e.g. 1.8 V and 3.3 V).
+ **Memory**: non-volatile (eMMC, SPI flash, EEPROM) and volatile (DDR/LPDDR).

### 7.2 Clock parts

+ **Crystals and oscillators**: a stable reference frequency, e.g. 24 MHz for the SoC and USB clocks, 32.768 kHz for a real-time clock.
  A crystal is passive and needs the chip's oscillator circuit; an oscillator module outputs a clock on its own.
+ **Load capacitors**: two small ceramic caps that make the crystal oscillate at its rated frequency.

### 7.3 Protection

+ **TVS diodes and ESD arrays**: fast clamps near external ports (USB, Ethernet, HDMI, buttons, debug headers) that absorb ESD and voltage spikes before they reach an IC.
+ **Fuses and PTC resettable fuses**: overcurrent protection. A fuse blows once; a polymer PTC heats up, its resistance rises sharply, and it recovers after cooling.
+ **Ferrite beads**: see [section 2.3](#23-inductor-and-ferrite-bead).

### 7.4 Connectors, test points, user hardware

+ **Connectors**: pin headers, FPC/FFC sockets, USB/HDMI/RJ45 jacks, battery and power terminals.
+ **Test pads and debug headers**: exposed pads or headers (UART, JTAG/SWD, boot-strap pins) used for bring-up, flashing, and factory test.
+ **LEDs, buttons, switches**: status LEDs, reset/power buttons, DIP and slide switches for configuration.

## 8. Reference designators

The silkscreen prints a short code next to each part so it can be matched to the schematic and BOM (e.g. `R12`, `C7`, `U3`).
Exact prefixes vary between vendors.

| Prefix | Component | Prefix | Component |
| --- | --- | --- | --- |
| `R` | resistor | `U` / `IC` | integrated circuit (SoC, PMIC, op-amp, transceiver) |
| `C` | capacitor | `Y` / `X` | crystal or oscillator |
| `L` / `FB` | inductor or ferrite bead | `J` / `CN` / `P` | connector, jack, header |
| `D` / `ZD` / `TVS` | diode, Zener, TVS/ESD diode | `SW` / `BTN` | switch or push button |
| `Q` | transistor (BJT or MOSFET) | `F` / `PTC` | fuse or resettable fuse |
| `K` / `RLY` | relay | `TP` | test point |

## Related notes

+ [voltage_mismatch.md](voltage_mismatch.md): 3.3 V vs. 5 V logic and level shifting
+ [transistor_BJT_MOSFET.md](transistor_BJT_MOSFET.md): BJT vs. MOSFET, switching a load from a GPIO
+ [rework_nouns.md](rework_nouns.md): rework vocabulary (populate, short, jumper)
+ [power_tree.md](power_tree.md): power tree and power-on/off sequencing
+ [../Linux/Power/regulators.md](../Linux/Power/regulators.md): PMICs, buck/LDO rails, Linux regulator framework

## Reference

+ [All About Circuits textbook](https://www.allaboutcircuits.com/textbook/)
+ [TI: Basic Calculation of a Buck Converter's Power Stage (SLVA477)](https://www.ti.com/lit/an/slva477b/slva477b.pdf)
+ [Wikipedia: Reference designator](https://en.wikipedia.org/wiki/Reference_designator)
