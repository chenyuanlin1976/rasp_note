# create bootable USB drive

## create a bootable ubuntu USB drive

1. Download the Ubuntu ISO
2. Identify your USB drive: `lsblk`
3. Unmount the USB drive (if mounted): `sudo umount /dev/sdXY`
4. Write the ISO to the USB drive: `sudo dd if=/path/to/ubuntu.iso of=/dev/sdX bs=4M status=progress`
5. Synchronize and eject: `sync`

## create a bootable Debian USB drive

1. Download the Debian ISO
2. Insert and then identify the USB device: `lsblk -l`
3. Unmount the USB drive (if mounted): `sudo umount /dev/sdX*`
4. Write the Debian ISO image to the USB drive: `sudo dd bs=4M if=/path/to/debian.iso of=/dev/sdX status=progress oflag=sync`
5. Synchronize and eject: `sync`, `sudo eject /dev/sdX`
