# PWM consumer driver (kernel module example)

When a PWM drives hardware the OS should own (LED, fan, backlight, buzzer, motor), a kernel driver is cleaner than writing `/sys/class/pwm` from user space.
First check whether a standard driver fits: `pwm-leds`, `pwm-fan`, `pwm-backlight`, `pwm-beeper`.
This note shows a small custom **consumer** driver for the cases they don't cover. It:

+ binds to a device tree node through `compatible`,
+ gets the PWM with `devm_pwm_get()` and the period/polarity from the device tree,
+ exposes a `duty_percent` attribute (0–100) in sysfs,
+ disables the PWM on remove.

The example uses `pwm14` on an RK3566. Enabling and muxing the PWM controller, and using it from Android, is in [../../Android/HW/pwm_control.md](../../Android/HW/pwm_control.md).

## 1. Device tree

```dts
&pwm14 {
	status = "okay";
	pinctrl-names = "active";          /* Rockchip BSP; mainline uses "default" */
	pinctrl-0 = <&pwm14m0_pins>;
};

/ {
	pwm_demo: pwm-demo {
		compatible = "vendor,pwm-demo";
		pwms = <&pwm14 0 1000000 0>;   /* provider, channel, period (ns) = 1 kHz, flags (0 = normal polarity) */
		pwm-names = "ctrl";
		status = "okay";
	};
};
```

+ Rockchip PWM nodes have `#pwm-cells = <3>`: channel, period, flags. Use `PWM_POLARITY_INVERTED` (from `<dt-bindings/pwm/pwm.h>`) as the flag for inverted output.
+ Replace `vendor` with your company's prefix. Don't use `rockchip,` for your own drivers.
+ Check on the device: `ls /proc/device-tree/pwm-demo/` shows `compatible`, `pwms`, `pwm-names`.

## 2. Driver source (`pwm_demo.c`)

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/mod_devicetable.h>
#include <linux/platform_device.h>
#include <linux/pwm.h>
#include <linux/mutex.h>
#include <linux/sysfs.h>

struct pwm_demo {
	struct pwm_device *pwm;
	struct mutex lock;		/* serializes state changes */
	struct pwm_state state;		/* last applied state */
	unsigned int duty_percent;
};

/* Caller holds data->lock. */
static int pwm_demo_apply(struct pwm_demo *data, unsigned int percent)
{
	struct pwm_state state = data->state;	/* keeps period and polarity from DT */
	int ret;

	ret = pwm_set_relative_duty_cycle(&state, percent, 100);
	if (ret)
		return ret;
	state.enabled = percent > 0;

	ret = pwm_apply_state(data->pwm, &state);
	if (ret)
		return ret;

	data->state = state;
	data->duty_percent = percent;
	return 0;
}

static ssize_t duty_percent_show(struct device *dev,
				 struct device_attribute *attr, char *buf)
{
	struct pwm_demo *data = dev_get_drvdata(dev);
	unsigned int val;

	mutex_lock(&data->lock);
	val = data->duty_percent;
	mutex_unlock(&data->lock);

	return sysfs_emit(buf, "%u\n", val);
}

static ssize_t duty_percent_store(struct device *dev,
				  struct device_attribute *attr,
				  const char *buf, size_t count)
{
	struct pwm_demo *data = dev_get_drvdata(dev);
	unsigned int percent;
	int ret;

	ret = kstrtouint(buf, 0, &percent);
	if (ret)
		return ret;
	if (percent > 100)
		return -EINVAL;

	mutex_lock(&data->lock);
	ret = pwm_demo_apply(data, percent);
	mutex_unlock(&data->lock);

	return ret ? ret : count;
}
static DEVICE_ATTR_RW(duty_percent);

static struct attribute *pwm_demo_attrs[] = {
	&dev_attr_duty_percent.attr,
	NULL
};
ATTRIBUTE_GROUPS(pwm_demo);

static int pwm_demo_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct pwm_demo *data;
	int ret;

	data = devm_kzalloc(dev, sizeof(*data), GFP_KERNEL);
	if (!data)
		return -ENOMEM;

	mutex_init(&data->lock);
	platform_set_drvdata(pdev, data);

	data->pwm = devm_pwm_get(dev, "ctrl");
	if (IS_ERR(data->pwm))
		return dev_err_probe(dev, PTR_ERR(data->pwm), "failed to get PWM\n");

	/* period and polarity from the "pwms" property, duty_cycle = 0 */
	pwm_init_state(data->pwm, &data->state);
	if (!data->state.period)
		data->state.period = 1000000;	/* fallback: 1 kHz */

	mutex_lock(&data->lock);
	ret = pwm_demo_apply(data, 25);		/* start at 25 % */
	mutex_unlock(&data->lock);
	if (ret)
		return dev_err_probe(dev, ret, "failed to apply initial state\n");

	dev_info(dev, "period=%llu ns, duty=%u%%\n",
		 (unsigned long long)data->state.period, data->duty_percent);
	return 0;
}

static int pwm_demo_remove(struct platform_device *pdev)
{
	struct pwm_demo *data = platform_get_drvdata(pdev);

	mutex_lock(&data->lock);
	pwm_demo_apply(data, 0);		/* duty 0, disabled */
	mutex_unlock(&data->lock);
	return 0;
}

static const struct of_device_id pwm_demo_of_match[] = {
	{ .compatible = "vendor,pwm-demo" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, pwm_demo_of_match);

static struct platform_driver pwm_demo_driver = {
	.probe = pwm_demo_probe,
	.remove = pwm_demo_remove,
	.driver = {
		.name = "pwm-demo",
		.of_match_table = pwm_demo_of_match,
		.dev_groups = pwm_demo_groups,	/* created before the uevent, removed automatically */
	},
};
module_platform_driver(pwm_demo_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("PWM consumer driver example");
```

+ `pwm_init_state()` takes period and polarity from the device tree. `pwm_get_state()` only returns the last applied state, which is empty right after boot.
+ `pwm_set_relative_duty_cycle()` computes `period * percent / 100` without 64-bit division problems.
+ `.dev_groups` creates the attribute together with the device, so user space (udev/ueventd) sees it when the device appears. A manual `device_create_file()` in `probe()` races with that and needs its own cleanup.
+ The PWM is released automatically (`devm_`) after `remove()`.

### 2.1 Kernel version differences

The code targets kernels 5.10–6.1 (Rockchip's Android BSPs; check `uname -r`). Newer kernels changed two APIs:

| Kernel | Change |
| --- | --- |
| 6.8 | `pwm_apply_state()` renamed to `pwm_apply_might_sleep()` |
| 6.3–6.10 | `.remove_new` returns `void`; from 6.11 `.remove` itself returns `void` |

## 3. Build as an out-of-tree module

Build against the **same, already built** kernel tree that runs on the board (its `.config` and `Module.symvers`):

```make
# Makefile (the recipe lines start with a TAB)
obj-m += pwm_demo.o

KDIR ?= /path/to/rk356x/kernel

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=arm64 LLVM=1 modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=arm64 LLVM=1 clean
```

+ Android kernels are built with Clang, so build modules with `LLVM=1` too. For a GCC-built kernel use `CROSS_COMPILE=aarch64-linux-gnu-` instead.
+ `make` produces `pwm_demo.ko`. Check `modinfo -F vermagic pwm_demo.ko` against `uname -r` on the device.
+ Why a module only loads into its own kernel, GKI and vendor modules: [kernel_module.md](kernel_module.md).

## 4. Load and test

```shell
adb root                                  # userdebug/eng build
adb push pwm_demo.ko /data/local/tmp/
adb shell insmod /data/local/tmp/pwm_demo.ko
adb shell 'dmesg | grep pwm-demo'         # pwm-demo pwm-demo: period=1000000 ns, duty=25%
adb shell cat /sys/kernel/debug/pwm       # channel requested by pwm-demo, enabled
```

Change the duty cycle at runtime:

```shell
adb shell 'echo 75 > /sys/devices/platform/pwm-demo/duty_percent'
adb shell cat /sys/devices/platform/pwm-demo/duty_percent      # 75
adb shell cat /sys/kernel/debug/pwm       # duty 750000 ns of period 1000000 ns
adb shell 'echo 0 > /sys/devices/platform/pwm-demo/duty_percent'   # off
adb shell rmmod pwm_demo                  # channel no longer requested
```

+ If `insmod` fails, check `dmesg`: version magic or symbol mismatch, module signature (`CONFIG_MODULE_SIG_FORCE`), or an SELinux denial.
+ In a product, install the module in `vendor_dlkm` (or `vendor_boot`) so it loads at boot. A vendor HAL then writes `duty_percent`, with permissions and labels as in [../../Android/HW/pwm_control.md](../../Android/HW/pwm_control.md) §5.

## Related notes

+ [../../Android/HW/pwm_control.md](../../Android/HW/pwm_control.md): PWM on RK3566/Android 14, sysfs test, permissions
+ [kernel_module.md](kernel_module.md), [kernel_build.md](kernel_build.md), [kernel_coding_style.md](kernel_coding_style.md)
+ [../DeviceTree/dts_driver_probe.md](../DeviceTree/dts_driver_probe.md), [../DeviceTree/dts_provider_consumer.md](../DeviceTree/dts_provider_consumer.md)
+ [../HW/sysfs_platform_devices.md](../HW/sysfs_platform_devices.md), [../HW/sysfs_led_class.md](../HW/sysfs_led_class.md)

## Reference

+ [Pulse Width Modulation (PWM) interface (kernel docs)](https://docs.kernel.org/driver-api/pwm.html)
+ [Platform devices and drivers (kernel docs)](https://docs.kernel.org/driver-api/driver-model/platform.html)
+ [Building external modules (kernel docs)](https://docs.kernel.org/kbuild/modules.html)
+ [PWM device tree binding (kernel docs)](https://docs.kernel.org/devicetree/bindings/pwm/pwm.html)
