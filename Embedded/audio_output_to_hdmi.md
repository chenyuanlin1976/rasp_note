# set audio output to HDMI

## HDMI port close to Type-C

1. command: `tvservice -l`  
1 attached device(s), display ID's are :  
Display Number 2, type HDMI 0
2. if video output is HDMI port closed to Type-C  
`vi /boot/config.txt`
3. uncomment  
`#hdmi_driver=2`

## HDMI port close to audio

+ `tvservice -l`  
1 attached device(s), display ID's are :  
Display Number 7, type HDMI 1

## dump edid

tvservice --dumpedid eizo_hdmi_edid  
xxd -g 1 eizo_hdmi_edid

---
`sudo raspi-config`
