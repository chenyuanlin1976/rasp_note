# check functions

## check bluetooth

+ Check Bluetooth Service State: `adb shell service check bluetooth`
+ Check Bluetooth Power State via dumpsys: `adb shell dumpsys bluetooth_manager`
+ Toggle Bluetooth On/Off:  
  + `adb shell cmd bluetooth enable`
  + `adb shell cmd bluetooth disable`

## check wifi

+ Check Wi-Fi Service State: `adb shell service check wifi`
+ Check Wi-Fi State and Connection Info: `adb shell dumpsys wifi`
+ Toggle Wi-Fi On/Off:  
  + `adb shell svc wifi enable`
  + `adb shell svc wifi disable`
