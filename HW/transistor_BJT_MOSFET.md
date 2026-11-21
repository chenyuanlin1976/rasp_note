# Transistors: BJT vs. MOSFET, and switching a load from a GPIO

BJTs (bipolar junction transistors) and FETs (field-effect transistors, in practice mostly MOSFETs) do 2 jobs in a circuit:
**switching** (on/off, PWM) and **amplification** (gain, buffering).
For the component basics, see [electronic_components.md](electronic_components.md#3-semiconductors).

The main difference is how they are controlled:

+ **BJT, current-controlled**: a base current I_B controls a larger collector–emitter current, I_C ≈ β × I_B in the active region.
  It needs base current the whole time it is on. Fully on (saturated), it drops a roughly constant V_CE(sat) ≈ 0.1–0.3 V.
+ **MOSFET, voltage-controlled**: the gate–source voltage V_GS controls the drain–source channel.
  The insulated gate draws almost no steady current; it only needs current to charge and discharge the gate capacitance when switching.
  Fully on, it behaves like a small resistor, R_DS(on), so the drop is I_D × R_DS(on).

## 1. Applications

### 1.1 Switching and PWM

+ **Low-side switch**: an NPN BJT or N-channel MOSFET between the load and GND.
  The control voltage is referenced to GND, so a GPIO pin can drive it directly. This is the usual choice (section 3).
+ **High-side switch**: a PNP BJT or P-channel MOSFET between the supply and the load, used when the load must stay connected to GND
  (e.g. a load that shares ground with other circuits, or switching a whole power rail).
  If the supply is higher than the GPIO voltage, the GPIO can't turn a P-channel off directly; drive its gate through a small NPN/N-channel stage.
  An N-channel on the high side needs a gate voltage above the supply (gate driver with bootstrap or charge pump).
+ **PWM**: switching fast varies the average power to LEDs, fans, or brushed DC motors (frequencies: [../Comm/pwm_remote_ctrl.md](../Comm/pwm_remote_ctrl.md)).
  MOSFETs are preferred for higher currents and higher PWM frequencies because of low R_DS(on) and no stored-charge turn-off delay.

### 1.2 Amplification

The transistor is biased in its linear region: the **active** region for a BJT, the **saturation** region for a MOSFET
(the names are confusing: BJT "saturation" means fully on, MOSFET "saturation" is the amplifying region).

+ **Common emitter (BJT) / common source (MOSFET)**: voltage gain with phase inversion. Audio preamps, sensor front-ends.
+ **Differential pair**: 2 matched transistors amplify the difference between 2 inputs and reject common-mode noise. The input stage of op-amps.
+ **Emitter follower (BJT) / source follower (MOSFET)**: voltage gain ≈ 1, high input impedance, low output impedance.
  A buffer that lets a high-impedance source drive a heavier load or a long cable.

### 1.3 Power conversion and drivers

+ **DC-DC converters and H-bridges**: power MOSFETs switch at tens of kHz up to a few MHz
  (buck converter: [electronic_components.md](electronic_components.md#6-buck-converter)).
+ **Pre-drivers / level shifters**: small BJTs or MOSFETs drive larger switches, relay coils, or translate logic levels
  ([voltage_mismatch.md](voltage_mismatch.md)).

## 2. BJT vs. MOSFET

| Aspect | BJT (NPN / PNP) | MOSFET (N-channel / P-channel) |
| --- | --- | --- |
| Control | Base current I_B | Gate–source voltage V_GS |
| Input | Needs continuous base current (series resistor) | Capacitive gate, ~0 DC current, charge needed when switching |
| On-state drop | V_CE(sat) ≈ 0.1–0.3 V, roughly constant | I_D × R_DS(on), very low in power MOSFETs |
| Switching | Slower turn-off (stored charge); drive power grows with load current | Fast if the gate charge is driven well; preferred for PWM and power |
| Small-signal | High transconductance (g_m = I_C / V_T) for a given current | High input impedance; RF and integrated circuits (CMOS) |
| Typical GPIO use | Small loads (LEDs, relay coils, < ~0.5 A) | Anything from small loads to many amperes |

## 3. Low-side switch for a GPIO (12 V load, 3.3 V / 5 V PWM)

For medium or high currents and PWM, a **logic-level N-channel MOSFET** is the usual choice: low conduction loss (I² × R_DS(on))
and no steady gate current. An NPN BJT is fine for small loads.

```text
            V_load (+12 V)
               |
        +------+------+
        |             |
      load        D1 (cathode to +12 V)    D1 only for inductive loads
        |             |                    (motor, fan, relay, solenoid)
        +------+------+
               |
               D (drain)  / C (collector)
GPIO --R_G----G  Q1        / B (base), with R_B instead of R_G
          |    S (source) / E (emitter)
         R_PD  |
          |    |
GND ------+----+---- GND of the load supply (common ground)
```

| Part | MOSFET | BJT |
| --- | --- | --- |
| Q1 | Logic-level N-channel: AO3400A, IRLML6344 (SOT-23, rated at V_GS = 2.5 V, a few A); IRLZ44N (TO-220, rated from V_GS = 4 V, so use it with 5 V drive) | NPN: BC337, 2N2222 / PN2222A, for loads up to a few hundred mA |
| Series resistor | R_G = 100–330 Ω: limits the gate charging peak and damps ringing at the edges | R_B from the base current, see below |
| Pull-down R_PD | 10–100 kΩ gate to GND | 10–100 kΩ base to GND |
| D1 | Schottky (1N5819, 40 V / 1 A) or ultrafast (UF4007) for PWM; 1N4007 is fine for a relay switched only occasionally | same |

+ **Pull-down**: keeps the switch off while the MCU boots, its pin is an input, or the cable is disconnected.
+ **Flyback diode**: across the inductive load, cathode (striped end) to V_load, anode to the drain/collector.
  Its reverse voltage rating must exceed V_load and its current rating must cover the load current.
+ LEDs still need their own current-limiting resistor in series.

**Base resistor for a BJT.** Drive it into saturation with a forced β of about 10–20 (I_B ≈ I_C / 10 … I_C / 20),
and keep I_B within the GPIO's current limit. Example: 3.3 V GPIO, V_BE ≈ 0.7 V, 100 mA load, I_B ≈ 5 mA:
R_B ≈ (3.3 − 0.7) / 0.005 ≈ 520 Ω, so use 470 Ω.
Many MCU pins are specified for only a few mA, so for loads much above 100 mA use a MOSFET (or a Darlington / driver IC such as ULN2003).

**Logic-level check for a MOSFET.** V_GS(th) is where the MOSFET *starts* to conduct, not where it is fully on.
A part with V_GS(th) = 2–4 V may barely conduct at 3.3 V. Check that the datasheet specifies R_DS(on) at a V_GS at or below your GPIO voltage.

## 4. Build and test

1. **Check ratings and ground.** V_DS (MOSFET) or V_CEO (BJT) must exceed the load supply with margin (≥ 20–30 V for a 12 V rail).
   The current rating and power dissipation (P ≈ I² × R_DS(on), or I_C × V_CE(sat)) must fit the load.
   Connect the MCU GND to the load supply GND.
   *Check:* continuity between both grounds, and no short between V_load and GND.
2. **Fit the series resistor and pull-down.**
   *Check:* with the MCU unpowered or the pin set as input, the gate/base measures ~0 V to GND.
3. **Connect the load and the flyback diode.**
   *Check:* diode stripe toward V_load; no bare leads touching neighbouring pins.
4. **Test static, then PWM.** Command 0 % and 100 % first, then 25 / 50 / 75 % duty cycle.
   *Check:* the load follows the duty cycle, and the transistor stays cool or only warm.

## 5. Troubleshooting

| Symptom | Likely causes |
| --- | --- |
| Transistor gets hot | MOSFET not fully on at the GPIO voltage (R_DS(on) specified only at 4.5 V / 10 V); BJT not saturated (R_B too large); PWM frequency too high for the gate drive (R_G too large, large gate charge); undersized part or no heatsink |
| Load turns on by itself or stays slightly on | Missing pull-down; wrong wiring (high side vs. low side); damaged, leaking transistor |
| MCU resets when a motor or relay switches | Inductive spikes or supply droop: diode missing or far from the load, missing decoupling/bulk capacitors, load current returning through the MCU's ground wire (route the load return directly to the supply) |
| P-channel high-side switch never turns off | Gate driven by a 3.3 V GPIO while the source is at 12 V; add an NPN/N-channel stage to pull the gate (section 1.1) |

## Related notes

+ [electronic_components.md](electronic_components.md): diodes, BJT, MOSFET, relay basics
+ [voltage_mismatch.md](voltage_mismatch.md): 3.3 V vs. 5 V logic and MOSFET level shifters
+ [power_tree.md](power_tree.md): power rails and sequencing
+ [../Comm/pwm_remote_ctrl.md](../Comm/pwm_remote_ctrl.md): PWM frequencies for LEDs, motors, fans

## Reference

+ [All About Circuits: Bipolar Junction Transistors](https://www.allaboutcircuits.com/textbook/semiconductors/chpt-4/bipolar-junction-transistors/)
+ [All About Circuits: Insulated-Gate Field-Effect Transistors](https://www.allaboutcircuits.com/textbook/semiconductors/chpt-7/insulated-gate-field-effect-transistors-mosfet/)
+ [TI: Fundamentals of MOSFET and IGBT Gate Driver Circuits (SLUA618)](https://www.ti.com/lit/ml/slua618a/slua618a.pdf)
