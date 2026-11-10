# Device tree: powering an SDIO Wi-Fi chip (`mmc-pwrseq-simple`)

An SDIO Wi-Fi (or Wi-Fi/Bluetooth combo) chip is soldered on the board and wired to an SD/MMC host controller.
Unlike an SD card, it doesn't announce itself: it answers on the bus only after its enable pin is released and its reference clock runs.
The Linux **MMC power sequence** framework (`mmc-pwrseq`) describes these steps in the device tree,
and the MMC core runs them every time it powers the card up or down.

The node is usually labelled `sdio_pwrseq` and named `sdio-pwrseq`, but that's only a naming convention.
The driver is selected by `compatible`. This is a kernel feature, not an Android one: Android BSPs use it the same way as any other Linux board.

## 1. Why a power sequence is needed

+ **Enable/reset pin**: the chip stays off until a GPIO (`WL_REG_ON`, `WL_EN`, `PDN`, ...) is driven to its active level.
+ **External clock**: many chips need a 32.768 kHz sleep clock (often from the PMIC) before they respond.
+ **Timing**: the host scans the bus right after power-up.
  If the chip isn't out of reset and stable by then, no SDIO card is found, so the Wi-Fi driver never binds and `wlan0` never appears.
+ **Non-removable card**: with `non-removable`, the host scans only at probe and on power-up, so the sequence must be right the first time.

## 2. Available drivers

| `compatible` | Driver (`drivers/mmc/core/`) | Use |
| --- | --- | --- |
| `mmc-pwrseq-simple` | `pwrseq_simple.c` | Generic: reset/enable GPIOs + one optional clock. Used by most SDIO Wi-Fi boards |
| `mmc-pwrseq-emmc` | `pwrseq_emmc.c` | Pulses the eMMC hardware reset line on reboot |
| `mmc-pwrseq-sd8787` | `pwrseq_sd8787.c` | Marvell SD8787: separate power-down and reset GPIOs |

## 3. `mmc-pwrseq-simple` properties

| Property | Meaning |
| --- | --- |
| `reset-gpios` | One or more GPIOs held **asserted** while the card is off and **deasserted** after power-up |
| `clocks`, `clock-names = "ext_clock"` | Optional clock enabled before power-up and disabled after power-off |
| `post-power-on-delay-ms` | Delay after the GPIOs are released, before the host starts talking to the card |
| `power-off-delay-us` | Delay after the GPIOs are asserted at power-off |

The GPIO flag defines what "asserted" means.
`WL_REG_ON` is an active-high enable, so it is described with `GPIO_ACTIVE_LOW`:
"reset asserted" drives the pin **low** (chip off), and "reset released" drives it **high** (chip on).
If you get the flag wrong, the chip is held off while the host scans.

## 4. Sequence run by the MMC core

```text
host probe / card power-up (mmc_power_up)
  pre_power_on   ext_clock on, reset-gpios asserted   (chip off, clock running)
  host enables vmmc-supply / vqmmc-supply, sets bus I/O voltage
  post_power_on  reset-gpios released                  (WL_REG_ON high)
                 wait post-power-on-delay-ms
  card scan      CMD5 ... "new ... SDIO card at address 0001"
  function driver (bcmdhd, brcmfmac, rtl88xx, ...) binds to the SDIO function

card power-off (mmc_power_off)
  power_off      reset-gpios asserted, wait power-off-delay-us, ext_clock off
```

The pwrseq node handles **only GPIOs and the clock**.
The supply rails belong to the host node (`vmmc-supply` for the card power, `vqmmc-supply` for the I/O voltage), and the MMC core switches them.
See [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md) for GPIO-switched rails.

## 5. Example (RK3566-style board)

```dts
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/interrupt-controller/irq.h>
#include <dt-bindings/pinctrl/rockchip.h>

/ {
    sdio_pwrseq: sdio-pwrseq {
        compatible = "mmc-pwrseq-simple";
        clocks = <&rk809 1>;                         /* PMIC 32.768 kHz output; check the PMIC binding for the index */
        clock-names = "ext_clock";
        pinctrl-names = "default";
        pinctrl-0 = <&wifi_enable_h>;
        reset-gpios = <&gpio2 RK_PB1 GPIO_ACTIVE_LOW>; /* WL_REG_ON (example pin, take it from the schematic) */
        post-power-on-delay-ms = <100>;
    };
};

&sdmmc1 {                                            /* the SDIO host the chip is wired to */
    status = "okay";
    bus-width = <4>;
    cap-sd-highspeed;
    cap-sdio-irq;                                    /* in-band SDIO interrupt */
    keep-power-in-suspend;
    non-removable;
    mmc-pwrseq = <&sdio_pwrseq>;                     /* run the sequence on power-up / power-off */
    vmmc-supply = <&vcc3v3_sys>;
    vqmmc-supply = <&vcc_1v8>;                       /* SDIO I/O voltage, must match the chip's VDDIO */
    #address-cells = <1>;
    #size-cells = <0>;

    wifi@1 {                                         /* optional: describes SDIO function 1 (mainline brcmfmac binding) */
        compatible = "brcm,bcm4329-fmac";
        reg = <1>;
        interrupt-parent = <&gpio2>;
        interrupts = <RK_PB2 IRQ_TYPE_LEVEL_HIGH>;   /* WL_HOST_WAKE, out-of-band wake */
        interrupt-names = "host-wake";
    };
};
```

+ `mmc-pwrseq` is a property of the **host** node (from `mmc-controller.yaml`). Without it, the pwrseq node is never used.
+ `non-removable`: no card-detect pin; the host assumes the card is always present.
+ Rockchip vendor (BSP) kernels for Android usually add their own `wireless-wlan` / `wireless-bluetooth` nodes
  (Rockchip rfkill/platdata drivers) for the host-wake IRQ, the chip type, and Bluetooth control.
  These nodes aren't in mainline; keep the `sdio_pwrseq` part as above.

## 6. Bluetooth on combo chips

`mmc-pwrseq` controls only the Wi-Fi side (`WL_REG_ON`). Bluetooth usually runs over UART and has its own `BT_REG_ON` pin.
That pin is driven by the Bluetooth driver: in mainline, a serdev child node of the UART (e.g. `brcm,bcm43438-bt` with `shutdown-gpios`),
or in Rockchip BSPs the vendor rfkill node.
If the board ties `WL_REG_ON` and `BT_REG_ON` together, powering off Wi-Fi also powers off Bluetooth.

## 7. Suspend and resume

+ `keep-power-in-suspend` only says the host **can** keep the card powered. The SDIO function driver asks for it at suspend time (`sdio_set_host_pm_flags(func, MMC_PM_KEEP_POWER)`).
+ If power is kept, the chip stays initialized, and with Wake-on-WLAN it can wake the system through the SDIO IRQ (`wakeup-source` on the host)
  or an out-of-band `WL_HOST_WAKE` GPIO.
+ If power isn't kept, the MMC core powers the card off (pwrseq `power_off`) and runs the full sequence and re-enumeration on resume.

## 8. Role on Android

+ The kernel runs the sequence at host probe, early in boot, independently of Android.
+ The Wi-Fi driver is often a vendor kernel module loaded later (by `init` or the vendor Wi-Fi HAL).
  It binds to the SDIO function that was already enumerated.
  If the card wasn't detected at probe, loading the module doesn't help.
+ Toggling Wi-Fi in Settings goes through the Wi-Fi service and HAL (interface up/down, sometimes module unload).
  It doesn't normally run the pwrseq again.

## 9. Checking and troubleshooting

```shell
dmesg | grep -i mmc                      # expect "mmcN: new ... SDIO card at address 0001"
ls /sys/bus/sdio/devices/                # e.g. mmc1:0001:1
cat /sys/bus/sdio/devices/*/vendor       # 0x02d0 = Broadcom/Cypress, 0x024c = Realtek
cat /sys/kernel/debug/mmc1/ios           # clock, bus width, power mode, signal voltage (debugfs)
cat /sys/kernel/debug/gpio               # WL_REG_ON line: consumer "reset", out hi = chip on
grep -i rk809 /sys/kernel/debug/clk/clk_summary   # is ext_clock enabled?
```

On Android, run these through `adb shell` (debugfs needs root and a kernel with debugfs mounted).

| Symptom | Things to check |
| --- | --- |
| No "SDIO card" line, scan timeouts | `reset-gpios` polarity, pinctrl mux of the pin, `ext_clock` running, `mmc-pwrseq` on the right host node |
| Card found sometimes | Increase `post-power-on-delay-ms`; check the chip's power-up timing in its datasheet |
| Card found, driver fails at high speed | `vqmmc-supply` voltage vs. chip VDDIO, `max-frequency`, signal integrity |
| Wi-Fi dead after resume | `keep-power-in-suspend`, wake IRQ wiring, driver suspend support |

## Related notes

+ [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md) (GPIO-switched rails), [dts_provider_consumer.md](dts_provider_consumer.md) (`-gpios`, `clocks`, pinctrl)
+ [dts_driver_probe.md](dts_driver_probe.md), [dts_intro.md](dts_intro.md)
+ [../Android/Debug/check_peripherals.md](../Android/Debug/check_peripherals.md), [../Android/AOSP_cfg/wifi_default.md](../Android/AOSP_cfg/wifi_default.md)

## Reference

+ [mmc-pwrseq-simple binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/mmc/mmc-pwrseq-simple.yaml)
+ [MMC controller binding (`mmc-pwrseq`, `non-removable`, `keep-power-in-suspend`)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/mmc/mmc-controller.yaml)
+ [`pwrseq_simple.c` driver source](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/mmc/core/pwrseq_simple.c)
+ [brcmfmac SDIO binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/net/wireless/brcm,bcm4329-fmac.yaml)
