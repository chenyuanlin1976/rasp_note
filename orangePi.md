[Orange Pi Ultra](http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_5_Ultra#How_to_install_Ubuntu_20.04_system)
[Reference](https://mikebian.co/setting-up-emmc-on-an-orange-pi/)

# Find the device
`$lsblk`
# Wipe the disk
`$sudo dd bs=1M if=/dev/zero of=/dev/mmcblk0 count=1000 status=progress && sudo sync`
# Copy image to orangepi
`$scp ~/Downloads/Orangepi_ubuntu_.img orangepi@IP_ADDR:~/ubuntu.img`
# Copy it to the emmc drive
`$sudo dd bs=1M if=./ubuntu.img of=/dev/mmcblk0 status=progress`

# Check installation:
I checked `fdisk -l` and it only showed a ~3G partition size. I went ahead and removed the SD card and rebooted the machine. It booted! And the disk resized.

# display temperature sensors
`$watch -n1 sensors`

# display CPU usage
`$htop`

# display GPU usage
`$watch -n1 cat /sys/devices/platform/fb000000.gpu/utilisation`

# decoders support
`ffmpeg -decoders`
`glxinfo | grep "direct rendering"`

# chromium/ chrome
1. chrome://gpu
2. chrome://flags


