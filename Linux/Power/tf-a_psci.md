# TF-A (Trusted Firmware-A) and PSCI

**TF-A** (Trusted Firmware-A) is the reference implementation of secure firmware for Arm Cortex-A (and Neoverse) processors.
Its runtime part, **BL31**, stays resident at **Exception Level 3 (EL3)** after boot as the **secure monitor**: it switches between the secure and non-secure worlds (Arm TrustZone) and serves requests from the OS.
For power management it implements **PSCI** (Power State Coordination Interface), the standard Arm interface that Linux uses to turn CPUs on and off, suspend the system, power it off, and reset it.

On Arm Cortex-M microcontrollers, the equivalent project is **TF-M** (Trusted Firmware-M), which provides secure partitioning (Armv8-M TrustZone) and secure services.

## 1. Exception levels and where TF-A runs

```text
EL0   applications                 |  secure applications (TAs)
EL1   Linux kernel                 |  secure OS, e.g. OP-TEE (BL32)
EL2   hypervisor (optional)        |
------------------------------------------------------------------
EL3   secure monitor: TF-A BL31 (PSCI, SMC dispatch, world switch)
         non-secure world          |  secure world
```

The kernel can't touch the secure-only hardware that controls power (power controller, secure clock and reset registers, often the PMIC sleep signal).
It asks BL31 instead, with an **SMC** (Secure Monitor Call) instruction.

## 2. Boot stages

| Stage | Name | What it does |
| --- | --- | --- |
| BL1 | AP trusted ROM | first code, usually in mask ROM; loads BL2 |
| BL2 | trusted boot firmware | initializes DRAM (on some SoCs), loads and verifies the next images |
| BL31 | EL3 runtime firmware | stays resident; PSCI, SMC handling |
| BL32 | secure payload (optional) | secure OS such as OP-TEE |
| BL33 | non-secure firmware | the normal bootloader, e.g. U-Boot, which then starts Linux |

Vendors often replace BL1/BL2 with their own loaders.
On Rockchip RK3566/RK3568, the boot ROM loads Rockchip's DDR init and SPL/miniloader; BL31 in the Rockchip BSP is a **prebuilt binary** from the `rkbin` repository, packed with OP-TEE (BL32) and U-Boot (BL33).
Recent mainline TF-A releases also have an RK3568 platform port; check the TF-A platform docs before relying on it.

## 3. PSCI

Linux learns about PSCI from the device tree (or ACPI) and calls it through `drivers/firmware/psci/`:

```dts
psci {
    compatible = "arm,psci-1.0";
    method = "smc";            /* conduit: SMC to EL3 (or "hvc" to a hypervisor) */
};
```

```shell
dmesg | grep -i psci           # e.g. "psci: PSCIv1.1 detected in firmware."
```

| PSCI function | Used by Linux for |
| --- | --- |
| `CPU_ON` | bring a secondary CPU online at boot or after CPU hotplug |
| `CPU_OFF` | take a CPU offline (CPU hotplug); not a system sleep state |
| `CPU_SUSPEND` | `cpuidle` states, including the ones s2idle uses |
| `SYSTEM_SUSPEND` (PSCI 1.0+) | suspend-to-RAM (`deep`) |
| `SYSTEM_OFF` | power-off |
| `SYSTEM_RESET` | reboot |

If the firmware doesn't support `SYSTEM_SUSPEND`, the kernel doesn't offer `deep` in `/sys/power/mem_sleep`, and only `s2idle` is available.

## 4. TF-A's part in suspend-to-RAM (deep)

1. **Enter**: after the kernel has suspended devices and taken the non-boot CPUs offline, the boot CPU calls PSCI `SYSTEM_SUSPEND` with the kernel's resume entry point.
2. **Power down**: BL31's platform code saves the secure state it needs, puts DRAM into **self-refresh**, turns off PLLs and power domains, and signals the PMIC (on RK3566, with the sleep pin) to switch the rails to their sleep state.
   What exactly is powered down is platform code; on the Rockchip BSP it is configured with the `rockchip-suspend` device tree node (see [rk3566_suspend.md](rk3566_suspend.md#5-rockchip-bsp-sleep-configuration)).
3. **Wake up**: a wakeup interrupt (RTC alarm, power key, GPIO) makes the always-on logic restore power, and the CPU restarts in BL31 at EL3. This is a **warm boot**: BL1/BL2 and U-Boot don't run again.
4. **Resume**: BL31 takes DRAM out of self-refresh, restores the platform and secure state, and returns to the kernel's resume entry point at EL1 (or EL2). The kernel then resumes in reverse order.

The kernel side of these steps is in [suspend_resume_flow.md](suspend_resume_flow.md#3-s2idle-vs-deep-the-last-step).

## Related notes

+ [suspend_resume_flow.md](suspend_resume_flow.md): kernel suspend and resume, step by step
+ [rk3566_suspend.md](rk3566_suspend.md): s2idle vs. deep, `rockchip-suspend`, and the PMIC sleep pin on RK3566
+ [regulators.md](regulators.md): PMICs and `regulator-state-mem`
+ [../../Android/AOSP_cfg/power_saving.md](../../Android/AOSP_cfg/power_saving.md): sleep states in general
+ [../../Android/AOSP_cfg/shutdown_flow.md](../../Android/AOSP_cfg/shutdown_flow.md): power-off, including PSCI `SYSTEM_OFF`

## Reference

+ [Trusted Firmware-A documentation](https://trustedfirmware-a.readthedocs.io/)
+ [Arm Power State Coordination Interface (PSCI) specification](https://developer.arm.com/documentation/den0022/latest)
+ [PSCI device tree binding (arm,psci)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/arm/psci.yaml)
+ [Trusted Firmware-M documentation](https://trustedfirmware-m.readthedocs.io/)
+ [System sleep states (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
