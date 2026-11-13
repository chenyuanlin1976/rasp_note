# Linux regulator framework and PMICs

A System-on-Chip needs many supply voltages: CPU and GPU cores, DRAM, I/O banks, and peripherals such as SD cards, cameras, and Wi-Fi.
On most boards a **PMIC** generates these rails, and the Linux **regulator framework** (`drivers/regulator/`) gives drivers one interface to them.
A device driver asks for "my `vmmc` supply" and doesn't need to know which chip provides it.

## 1. PMIC: the board's power chip

A **PMIC** (Power Management IC) is a chip with many power outputs.
Linux usually talks to it over I2C or SPI (Qualcomm PMICs use SPMI).
RK3566 boards typically use the Rockchip **RK809** on I2C.

| Output type | What it is | Typical use |
| --- | --- | --- |
| **Buck (DC-DC) converter** | switching step-down regulator, high efficiency | high-current rails: CPU, GPU, NPU cores, DRAM |
| **LDO** (low-dropout regulator) | linear regulator, low noise, less efficient | low-current or noise-sensitive rails: analog, audio, sensors, I/O banks |
| **Switch** | load switch, no regulation | turns a rail fully on or off |

A PMIC often does more than regulate: RTC, power key, charger, watchdog, and the final power-off at shutdown.
Its Linux driver is usually an **MFD** (multi-function device) driver, with sub-drivers for each function.
For the RK809, `rk8xx` is the MFD core and `rk808-regulator` is the regulator part.

## 2. Framework structure

```text
 consumer drivers           regulator core                  provider drivers
 (MMC, camera, cpufreq) --> drivers/regulator/core.c -----> (PMIC, regulator-fixed)
   regulator_get()          + consumer <-> regulator map      ops: enable, set_voltage, ...
   regulator_enable()       + constraints from DT              -> I2C/SPI register writes
   regulator_set_voltage()  + use counts, supply tree          -> or a GPIO
                            + sysfs and debugfs
```

+ **Regulator core**: registers all regulators, maps consumers to regulators, enforces constraints, counts users, and handles parent supplies (a regulator can be fed by another regulator).
+ **Providers**: drivers that register rails with the core and translate requests into hardware actions.
  A PMIC driver writes PMIC registers; `regulator-fixed` toggles a GPIO (see [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md)).
+ **Consumers**: drivers of devices that need power. They use only the consumer API (`<linux/regulator/consumer.h>`).

Before this framework, a device driver had to call a specific PMIC driver directly, which tied every driver to one board's power design.

## 3. Describing rails in the device tree

The PMIC node lists its regulators with their **constraints**.
A consumer references a rail with a property named **`<name>-supply`**; the device's binding defines `<name>`.
The example below is shaped like a typical RK3566 board `.dts`. Check your own board's `.dts` and schematic for the real names and voltages.

```dts
&i2c0 {
    rk809: pmic@20 {
        compatible = "rockchip,rk809";
        reg = <0x20>;
        /* interrupts, clocks, input supplies, ... omitted */

        regulators {
            vccio_sd: LDO_REG5 {
                regulator-name = "vccio_sd";            /* name in sysfs, debugfs, logs */
                regulator-min-microvolt = <1800000>;    /* constraints: allowed range */
                regulator-max-microvolt = <3300000>;
                regulator-state-mem {                   /* state during system suspend */
                    regulator-off-in-suspend;
                };
            };
        };
    };
};

&sdmmc0 {
    vmmc-supply = <&vcc3v3_sd>;     /* card power: a GPIO-switched fixed regulator */
    vqmmc-supply = <&vccio_sd>;     /* I/O signal level: 3.3 V, then 1.8 V for UHS cards */
};
```

Common constraint properties (binding `regulator.yaml`):

| Property | Meaning |
| --- | --- |
| `regulator-min-microvolt` / `regulator-max-microvolt` | allowed voltage range. If min == max, the voltage is fixed and consumers can't change it |
| `regulator-min-microamp` / `regulator-max-microamp` | allowed current-limit range, for regulators with a programmable limit |
| `regulator-allow-set-load` | consumers may report their load, so the core can switch the regulator's operating mode |
| `regulator-always-on` | never switched off by the kernel |
| `regulator-boot-on` | left on by the bootloader. Switched off after boot if no consumer enables it |
| `regulator-ramp-delay` | voltage slew rate in µV/µs |
| `regulator-state-mem` | on/off and voltage during suspend-to-RAM (see [suspend_resume_flow.md](suspend_resume_flow.md#3-s2idle-vs-deep-the-last-step)) |

The constraints describe what is safe **for this board**, which can be narrower than what the PMIC can do.
See [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md#boot-time-behavior) for `regulator-boot-on` vs `regulator-always-on` in detail.

## 4. Consumer API

A driver gets its supply in `probe()` and enables it before using the device:

```c
#include <linux/regulator/consumer.h>

static int foo_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct regulator *vdd;
    int ret;

    vdd = devm_regulator_get(dev, "vdd");          /* DT property: vdd-supply */
    if (IS_ERR(vdd))
        return dev_err_probe(dev, PTR_ERR(vdd), "failed to get vdd\n");

    ret = regulator_set_voltage(vdd, 1800000, 1800000);   /* min_uV, max_uV */
    if (ret)
        return ret;

    ret = regulator_enable(vdd);
    if (ret)
        return ret;
    /* ... device is powered; call regulator_disable(vdd) on remove/suspend */
    return 0;
}
```

| Function | Purpose |
| --- | --- |
| `devm_regulator_get(dev, "vdd")` | look up the `vdd-supply` rail; released automatically when the driver detaches |
| `regulator_get_optional()` | like `regulator_get()`, but returns `-ENODEV` if the supply isn't described |
| `regulator_enable()` / `regulator_disable()` | turn on or off; calls must be balanced |
| `regulator_set_voltage(reg, min_uV, max_uV)` | request a voltage range |
| `regulator_get_voltage()` | read the current voltage |
| `regulator_set_load(reg, uA)` | report the expected load (needs `regulator-allow-set-load`) |
| `devm_regulator_bulk_get()` + `regulator_bulk_enable()` | handle several supplies at once (e.g. a camera's `avdd`, `dvdd`, `dovdd`) |

Points worth knowing:

+ **Missing supply**: if the DT has no `vdd-supply`, `regulator_get()` returns a **dummy regulator** and logs `supply vdd not found, using dummy regulator`.
  This is fine for rails that are always on in hardware. Use `regulator_get_optional()` when the driver must know that the supply is absent.
+ **Probe deferral**: if the PMIC driver hasn't probed yet, `regulator_get()` returns `-EPROBE_DEFER`, and the consumer is probed again later.
  `dev_err_probe()` keeps this case out of the error log.
+ **DVFS**: CPU and GPU frequency scaling (cpufreq/devfreq with OPP tables) calls `regulator_set_voltage()` on the core rail, so those drivers rarely call it directly.

## 5. What the core enforces

+ **Constraints**: a request outside the DT range fails. If min == max, voltage changes aren't allowed at all.
+ **Use counts**: each consumer's enables are counted. A shared rail switches off only after **every** consumer has called `regulator_disable()`.
+ **Voltage aggregation**: when several consumers share a rail, the core picks a voltage that satisfies all of their requested ranges.
+ **Supply tree**: enabling a regulator first enables its parent supply (for example, a fixed regulator's `vin-supply`).
+ **Unused rails**: about 30 s after boot, `regulator_late_cleanup()` switches off rails that no consumer enabled, unless they are `regulator-always-on`.

## 6. Inspecting regulators at runtime

The per-regulator sysfs files are read-only:

```shell
grep . /sys/class/regulator/regulator.*/name        # find the regulator.N you want
cat /sys/class/regulator/regulator.N/state           # enabled / disabled
cat /sys/class/regulator/regulator.N/microvolts
cat /sys/class/regulator/regulator.N/num_users
```

debugfs (needs root and `CONFIG_DEBUG_FS`) shows the whole tree:

```shell
mount -t debugfs none /sys/kernel/debug     # if not mounted already
cat /sys/kernel/debug/regulator/regulator_summary
```

`regulator_summary` prints each regulator indented under its parent supply, with its consumers below it:

| Column | Meaning |
| --- | --- |
| `use` | enable count (how many consumers have it enabled) |
| `open` | how many consumers hold a handle from `regulator_get()` |
| `bypass` | bypass count |
| `opmode` | operating mode (normal, idle, ...) |
| `voltage` | current output voltage |
| `current` | current **limit**, not the measured current. Most PMICs can't measure current per rail |
| `min` / `max` | the constraint range; on consumer lines, the range that consumer requested |

To turn a rail on or off from user space or Android, see [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md#4-switching-it-from-user-space-or-android).

## 7. Kernel configuration

| Option | Purpose |
| --- | --- |
| `CONFIG_REGULATOR` | the regulator framework |
| `CONFIG_REGULATOR_FIXED_VOLTAGE` | `regulator-fixed` (GPIO-switched or always-on fixed rails) |
| `CONFIG_MFD_RK8XX_I2C` + `CONFIG_REGULATOR_RK808` | RK8xx PMIC on I2C (RK809 on RK3566 boards) |
| `CONFIG_REGULATOR_DEBUG` | extra debug messages from the core |

Option names change between kernel versions (`CONFIG_MFD_RK8XX_I2C` replaced the older `CONFIG_MFD_RK808`). Check the `Kconfig` of your kernel.

## Related notes

+ [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md) (GPIO-switched rails, boot-time behavior, user-space control)
+ [dts_provider_consumer.md](dts_provider_consumer.md) (`<name>-supply` and other provider/consumer properties)
+ [dts_node_mmc_pwrseq.md](dts_node_mmc_pwrseq.md) (power sequence for SDIO Wi-Fi chips)
+ [../Android/AOSP_cfg/power_saving.md](../Android/AOSP_cfg/power_saving.md) (suspend states; the PMIC's role in suspend-to-RAM)
+ [suspend_resume_flow.md](suspend_resume_flow.md) (how `regulator-state-mem` is applied during suspend)
+ [../Android/AOSP_cfg/shutdown_flow.md](../Android/AOSP_cfg/shutdown_flow.md) (PMIC power-off and `system-power-controller`)
+ [../HW/voltage_mismatch.md](../HW/voltage_mismatch.md) (I/O voltage levels)

## Reference

+ [Regulator framework overview (kernel docs)](https://docs.kernel.org/power/regulator/overview.html)
+ [Regulator consumer driver interface (kernel docs)](https://docs.kernel.org/power/regulator/consumer.html)
+ [Regulator machine driver interface: constraints (kernel docs)](https://docs.kernel.org/power/regulator/machine.html)
+ [Regulator driver interface (kernel docs)](https://docs.kernel.org/power/regulator/regulator.html)
+ [regulator.yaml binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/regulator/regulator.yaml)
