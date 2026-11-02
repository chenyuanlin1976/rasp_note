# Reading SAR-ADC values on RK3566 (Android)

The RK3566 SAR-ADC is exposed through the Linux **Industrial I/O (IIO)** subsystem,
so raw values can be read from sysfs with `adb shell`, with no custom app needed.

| Item | Typical value | Notes |
| --- | --- | --- |
| Resolution | 10-bit | 1024 codes, raw range 0-1023 |
| Channels | 6 single-ended | `in_voltage0_raw` ... `in_voltage5_raw` |
| Input range | 0-1.8 V | V_ref comes from `vref-supply` in the device tree, so it is board-dependent |
| Driver name | `ff3c0000.saradc` | Check `name`, not the device index |

> Reading sysfs from `adb shell` may need root (`adb root` or `su`),
> depending on the build and SELinux policy.

## 1. Quick start

```sh
adb shell
cd /sys/bus/iio/devices

# 1) find the SAR-ADC (index depends on probe order)
for d in iio:device*; do echo "$d: $(cat $d/name)"; done

# 2) read channel 0 and the driver-provided scale
cd iio:device0                      # use the one whose name is *saradc*
cat in_voltage0_raw
cat in_voltage_scale
```

## 2. Convert raw value to voltage

Preferred: use the scale exposed by the driver (mV per count), so V_ref is not hardcoded.

```
Voltage (mV) = raw x in_voltage_scale
```

Manual fallback, if no scale file exists:

```
Voltage (mV) = V_ref (mV) x raw / 1024
```

Example: V_ref = 1800 mV, raw = 512 gives 1800 x 512 / 1024 = 900 mV.

One-liner (the shell has no floating point, so use `awk`):

```sh
awk -v r="$(cat in_voltage0_raw)" -v s="$(cat in_voltage_scale)" 'BEGIN{printf "%.1f mV\n", r*s}'
```

## 3. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `Permission denied` | Need `adb root` / `su`, or SELinux blocks sysfs reads |
| No `/sys/bus/iio/devices/iio:device*` | SAR-ADC node disabled in the device tree, or the driver is not built |
| `in_voltage_scale` missing | Older kernel or driver; use the manual formula |
| Readings do not match a multimeter | Wrong V_ref assumption, input above 1.8 V, or source impedance too high |

## 4. Background: the IIO subsystem

`/sys/bus/iio/devices/iio:deviceN` is the sysfs directory of one device managed by IIO.
IIO covers ADCs, DACs and many sensors (accelerometers, gyroscopes, magnetometers,
light, pressure, humidity).

Which files appear depends on the driver. Common ones:

| Entry | Meaning |
| --- | --- |
| `name` | Driver or chip name (e.g. `mpu6050`, `bme280`, `ff3c0000.saradc`); tells you what the device is |
| `in_voltage0_raw`, `in_accel_x_raw`, `in_temp_raw` | Raw data per channel; reading one triggers a measurement |
| `in_*_scale`, `in_*_offset` | Convert raw to standard units: value = (raw + offset) x scale |
| `sampling_frequency` | Sample rate, only on drivers that support it (the Rockchip SAR-ADC may not) |
| `buffer/` | Continuous streaming (triggered buffer or FIFO), only on drivers that support it |
