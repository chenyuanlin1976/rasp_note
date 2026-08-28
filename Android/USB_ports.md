# USB 2.0 or 3.0

To check if an Android device's hardware port supports USB 3.0 (xHCI) or is limited to USB 2.0 (EHCI),  
the host controller interface types provide the definitive answer:  

+ **EHCI** (Enhanced Host Controller Interface) signifies USB 2.0 (AHCI is for SATA storage drives, not USB).
+ **xHCI** (eXtensible Host Controller Interface) always indicates USB 3.0+ capability,

## command: ~~`adb shell lsusb -t`~~

Android may NOT support the option `-t`.

```bash
/:  Bus 001.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/16p, 480M
    |__ Port 002: Dev 002, If 0, Class=Vendor Specific Class, Driver=[none], 12M
    |__ Port 002: Dev 002, If 2, Class=Human Interface Device, Driver=usbhid, 12M
    |__ Port 011: Dev 003, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 003: Dev 005, If 0, Class=Human Interface Device, Driver=usbhid, 1.5M
        |__ Port 003: Dev 005, If 1, Class=Human Interface Device, Driver=usbhid, 1.5M
        |__ Port 004: Dev 007, If 0, Class=Human Interface Device, Driver=usbhid, 1.5M
    |__ Port 013: Dev 004, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 002: Dev 008, If 0, Class=Vendor Specific Class, Driver=ftdi_sio, 12M
    |__ Port 014: Dev 006, If 0, Class=Wireless, Driver=btusb, 12M
    |__ Port 014: Dev 006, If 1, Class=Wireless, Driver=btusb, 12M
/:  Bus 002.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/9p, 20000M/x2
```

## command: `adb shell cat /sys/kernel/debug/usb/devices`

```bash
T:  Bus=01 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh= 1
B:  Alloc=  0/800 us ( 0%), #Int=  0, #Iso=  0
D:  Ver= 2.00 Cls=09(hub  ) Sub=00 Prot=01 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0002 Rev= 6.01
S:  Manufacturer=Linux 6.1.99-ab13 xhci-hcd
S:  Product=xHCI Host Controller
S:  SerialNumber=xhci-hcd.0.auto
C:* #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=  0mA
I:* If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms

T:  Bus=02 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=5000 MxCh= 1
B:  Alloc=  0/800 us ( 0%), #Int=  0, #Iso=  0
D:  Ver= 3.00 Cls=09(hub  ) Sub=00 Prot=03 MxPS= 9 #Cfgs=  1
P:  Vendor=1d6b ProdID=0003 Rev= 6.01
S:  Manufacturer=Linux 6.1.99-ab13 xhci-hcd
S:  Product=xHCI Host Controller
S:  SerialNumber=xhci-hcd.0.auto
C:* #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=  0mA
I:* If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms

T:  Bus=03 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh= 1
B:  Alloc=  0/800 us ( 0%), #Int=  0, #Iso=  0
D:  Ver= 2.00 Cls=09(hub  ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0002 Rev= 6.01
S:  Manufacturer=Linux 6.1.99-ab13 ehci_hcd
S:  Product=EHCI Host Controller
S:  SerialNumber=fd880000.usb
C:* #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=  0mA
I:* If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms

T:  Bus=04 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=12   MxCh= 1
B:  Alloc=  0/900 us ( 0%), #Int=  0, #Iso=  0
D:  Ver= 1.10 Cls=09(hub  ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0001 Rev= 6.01
S:  Manufacturer=Linux 6.1.99-ab13 ohci_hcd
S:  Product=Generic Platform OHCI controller
S:  SerialNumber=fd8c0000.usb
C:* #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=  0mA
I:* If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=255ms

T:  Bus=05 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh= 1
B:  Alloc=  0/800 us ( 0%), #Int=  0, #Iso=  0
D:  Ver= 2.00 Cls=09(hub  ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0002 Rev= 6.01
S:  Manufacturer=Linux 6.1.99-ab13 ehci_hcd
S:  Product=EHCI Host Controller
S:  SerialNumber=fd800000.usb
C:* #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=  0mA
I:* If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms

T:  Bus=06 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=12   MxCh= 1
B:  Alloc=  0/900 us ( 0%), #Int=  0, #Iso=  0
D:  Ver= 1.10 Cls=09(hub  ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0001 Rev= 6.01
S:  Manufacturer=Linux 6.1.99-ab13 ohci_hcd
S:  Product=Generic Platform OHCI controller
S:  SerialNumber=fd840000.usb
C:* #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=  0mA
I:* If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=255ms
```

## `adb shell ls -l /sys/bus/platform/drivers/ | grep hci`

```bash
drwxr-xr-x 2 root root 0 2025-11-19 04:41 ahci-dwc
drwxr-xr-x 2 root root 0 2025-11-19 04:41 ehci-platform
drwxr-xr-x 2 root root 0 2025-11-19 04:41 ohci-platform
drwxr-xr-x 2 root root 0 2025-11-19 04:41 sdhci-arasan
drwxr-xr-x 2 root root 0 2025-11-19 04:41 sdhci-dwcmshc
drwxr-xr-x 2 root root 0 2025-11-19 04:41 xhci-hcd
```
