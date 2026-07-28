# adb screencap

<https://developer.android.com/tools/adb>

```md
usage: screencap [-hp] [-d display-id] [FILENAME]  
  -h: this message  
  -p: save the file as a png.  
  -d: specify the display ID to capture (default: 4625716335649126416)  
      see "dumpsys SurfaceFlinger --display-id" for valid display IDs.  
**If FILENAME ends with .png it will be saved as a png.**  
**If FILENAME is not given, the results will be printed to stdout.**
```

`adb shell screencap /sdcard/screen.png`

| Commands                          |  Result    |  $file xxx       |
|-----------------------------------|------------|------------------|
| `adb shell screencap -p 01.jpg`   |  Pass      |  PNG image data  |
| `adb shell screencap -p 02.png`   |  Pass      |  PNG image data  |
| `adb shell screencap -p 03`       |  Pass      |  PNG image data  |
| `adb shell screencap 04.png`      |  Pass      |  PNG image data  |
| `adb shell screencap 05.jpg`      |  Fail      |  data            |
| `adb shell screencap 06`          |  Fail      |  data            |

## AOSP

<https://android.googlesource.com/platform/frameworks/base/+/master/cmds/screencap/screencap.cpp>
