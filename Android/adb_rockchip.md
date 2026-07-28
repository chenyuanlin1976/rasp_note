# debug RK chip

[websit](https://wiki.t-firefly.com/en/ROC-RK3566-PC/index.html)

## ADC

`adb shell cat /sys/bus/iio/devices/iio\:device0/in_voltage*_raw`

## pwm channel

`adb shell cat /sys/kernel/debug/pwm`
