# using adb command

## Devices

`adb usb`  
`adb connect ip_address_of_device`  
`adb devices`     // show devices attached  
`adb devices -l`  // devices (product/model)

## shell terminal

`adb shell`    // Open or run commands in a terminal on the host Android device.  
`exit`

## memory usage

`adb shell free -h`  
`adb shell procrank`  
`adb shell dumpsys meminfo`  
`adb shell cat /proc/meminfo`  
`adb shell dmesg | grep -i "out of memory"`

## adb exec-out

`adb exec-out screencap -p /sdcard/Pictures/01.png`

## adb common commands

`adb help`          // List all comands  
`adb shell ls`      // list directory contents  
`adb shell ls -s`   // print size of each file  
`adb shell ls -R`   // list subdirectories recursively  
`adb shell ps`      // print process status  
`adb shell netstat` // list TCP connectivity  
`adb shell pwd`     // print current working directory

### server

`adb kill-server`  
`adb start-server`

### reboot

`adb reboot`  
`adb reboot bootloader`  
`adb reboot fastboot`  
`adb reboot recovery`     // reboot device into recovery mode  
`$adb start-server`       // start up adb daemon

`adb root`                //restarts adb with root permissions

`fastboot devices`  
// Check connection and get basic information about devices connected to the computer.  
// This is essentially the same command as adb devices from earlier.  
// However, it works in the bootloader, which ADB does not. Handy for ensuring that you have properly established a connection.

### take a screenshot

`adb shell screencap -p /sdcard/001.png`  
`adb pull /sdcard/001.png .`

`adb shell screenrecord /sdcard/001.mp4`

### push, pull

`adb push src dest`               // Copy files from your computer to your phone.  
`adb pull remoteFile savedFlie`   // Copy files from your phone to your computer.

### logcat

`adb logcat [options] [filter] [filter]`      // view device log  
`adb logcat`  
`adb shell logcat`  
`adb shell logcat -c`             // The parameter -c will clear the current logs on the device.  
`adb shell logcat -d > fileName`  // Save the logcat output to a file on the local system.  
`adb shell bugreport > fileName`  // Will dump the whole device information like dumpstate, dumpsys and logcat output.  
`adb bugreport`                   // print bug reports

`adb shell pidof packageName`  
`adb sehll ps | grep pidNumber`

`adb shell logcat -d --pid=xxxPid`

#### priority (lowest to highest)

V: Verbose  
D: Debug  
I: Info  
W: Warning  
E: Error  
F: Fatal  
S: Silent (highest priority, where nothing is ever printed)

`adb logcat ActivityManager:I MyApp:D *:S`

[RefWeb](https://developer.android.com/tools/logcat)

### install APK

`adb -e install yourApk`  
  -d                        - directs command to the only connected USB device...  
  -e                        - directs command to the only running emulator...  
  -s serial_number  
  -p product_name_or_path  
  The flag you decide to use has to come before the actual adb command

### Install the given app on all connected devices.

adb devices | tail -n +2 | cut -sf 1 | xargs -IX adb -s X install -r com.myAppPackage

### Uninstall APP

`adb uninstall packageName`  
`adb uninstall -k packageName`    // Uninstall .apk withour deleting data  
`adb shell pm uninstall packageName`  
`adb shell pm clear packageName`  // Deletes all data associated with a package.  
`adb devices | tail -n +2 | cut -sf 1 | xargs -IX adb -s X uninstall packageName` // Uninstall the given app from all connected devices

### Update APP

`adb install -r yourApk`          // -r means re-install the app and keep its data on the device.  
`adb install –k yourApk`

### am: Activity Manager

`adb shell am start|startservice|broadcast <INTENT> <COMPONENT>`  
  -a ACTION     // e.g. android.intent.action.VIEW  
  -c CATEGORY   // e.g. android.intent.category.LAUNCHER (start activity intent)

`adb shell am start -a android.intent.action.CALL -d tel:+972527300294`                 // Make a call  
`adb shell am start -W -c android.intent.category.HOME -a android.intent.action.MAIN`   // Home button  
`adb shell am start -a android.intent.action.SENDTO -d sms:+972527300294 --es sms_body "Test --ez exit_on_sent false`   // Open send sms screen with phone number and the message  
`adb shell am start -a android.intent.action.VIEW`  
`adb shell am start -a android.intent.action.VIEW -d URL`       // open URL  
`adb shell am start -t image/* -a android.intent.action.VIEW`   // opens gallery

`adb shell am stop-service packageName/.ServiceName`  
`adb shell am start-service packageName/.ServiceName`

`adb shell am broadcast -a 'my_action'`

### pm: Package Manager

`adb shell pm list packages`     // list package names  
`adb shell pm list packages -3`  // list third party package names  
`adb shell pm list packages -r`  // list package name + path to apks  
`adb shell pm list packages -s`  // list only system packages  
`adb shell pm list packages -u`  // list package names + uninstalled  

`adb shell pm dump packageName`  // list info on one package  
`adb shell pm dump packageName | grep codePath`  
`adb shell pm dump packageName | grep versionName`  

`adb shell pm path packageName`  // path to the apk file

`adb shell pm list features`                          // list phone features  
`adb shell pm reset-permissions -p your.app.package`  // Reset permissions  
`adb shell pm grant packageName  Permission`          // Grant a permission to an app.  
`adb shell pm revoke packageName Permission`          // Revoke a permission from an app.

`adb shell pm install xxx.apk`  
`adb shell pm uninstall xxx.apk`

### settings

`adb shell settings list global`  
`adb shell settings list secure`  
`adb shell settings list system`  
`adb shell settings get system screen_brightness`  
`adb shell settings put system screen_brightness 120`

`adb shell settings get global low_power`  
A value of 0 indicates that Battery Saver (low power mode) is disabled.  
A value of 1 indicates that Battery Saver (low power mode) is enabled.  

`adb shell settings put global low_power 1` # enter Power Saving Mode (PSM)  

### dumpsys

dumpsys is an android tool that runs on the device and dumps interesting information about the status of system services.  
`adb shell dumpsys -h`  
`adb shell dumpsys -l`                  // list services  
`adb shell dumpsys -l | grep activity`  // here, activity is a service  
`adb shell dumpsys activity -h`  

`adb shell dumpsys battery`  
`adb shell dumpsys battery unplug`          # a charging device cannot enter PSM  
`adb shell dumpsys battery reset`  

#### get info

`adb shell dumpsys package packages`              // list info on all apps  
`adb shell dumpsys activity activities | head`    // see which is the top activity  
`adb shell dumpsys activity <package>/<activity>` // activity info  
`adb shell dumpsys iphonesybinfo`                 // get the IMEI  
`adb shell dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp` // print current app's opened activity

#### set settings with dumpsys

`adb shell dumpsys battery`                       // battery status  
`adb shell dumpsys battery set level <n>` // change the level from 0 to 100  
`adb shell dumpsys battery set status<n>` // change the level to unknown, charging, discharging, not charging or full  
`adb shell dumpsys battery reset`         // reset the battery  
`adb shell dumpsys battery set usb <n>`   // change the status of USB connection. ON or OFF  
`adb shell dumpsys | grep ntp`

### getprop: get device android version

`adb shell getprop`  
`adb shell getprop ro.build.version.release`  
`adb shell getprop ro.build.version.sdk`  
`adb shell getprop | grep hardware`  
`adb shell getprop | grep ro.product.cpu`

### wm: window manager

`adb shell wm size`           // displays the current screen resolution  
`adb shell wm size 2048x1536`  
`adb shell wm size reset`     // And reset to default  

`adb shell wm density`        // get the current density  
`adb shell wm density 288`  
`adb shell wm density reset`

### input: emulate user input

`adb shell input text 'Wow, it so cool feature'`

`adb shell input keyevent 3`    // Home btn  
`adb shell input keyevent 4`    // Back btn  
`adb shell input keyevent 5`    // Call  
`adb shell input keyevent 6`    // End call  
`adb shell input keyevent 26`   // Turn Android device ON and OFF. It will toggle device to on/off status.  
`adb shell input keyevent 27`   // Camera  
`adb shell input keyevent 64`   // Open browser  
`adb shell input keyevent 66`   // Enter  
`adb shell input keyevent 67`   // Delete (backspace)  
`adb shell input keyevent 207`  // Contacts  
`adb shell input keyevent 220`  // 221 // Brightness down/up  
`adb shell input keyevent 277`  // 278, 279: Cut, Copy, Paste

## Shared Preferences

1. replace org.example.app with your application id  

2. Add a value to default shared preferences.  
`adb shell 'am broadcast -a org.example.app.sp.PUT --es key key_name --es value "hello world!"'`

3. Remove a value to default shared preferences.  
`adb shell 'am broadcast -a org.example.app.sp.REMOVE --es key key_name'`

4. Clear all default shared preferences.  
`adb shell 'am broadcast -a org.example.app.sp.CLEAR --es key key_name'`

5. It's also possible to specify shared preferences file.  
`adb shell 'am broadcast -a org.example.app.sp.PUT --es name Game --es key level --ei value 10'`

6. Data types  
`adb shell am broadcast -a org.example.app.sp.PUT --es key string --es value "hello world!"`  
`adb shell am broadcast -a org.example.app.sp.PUT --es key boolean --ez value true`  
`adb shell am broadcast -a org.example.app.sp.PUT --es key float --ef value 3.14159`  
`adb shell am broadcast -a org.example.app.sp.PUT --es key int --ei value 2015`  
`adb shell am broadcast -a org.example.app.sp.PUT --es key long --el value 9223372036854775807`

7. Restart application process after making changes  
`adb shell 'am broadcast -a org.example.app.sp.CLEAR --ez restart true'`

## Monkey

`adb shell monkey -p com.myAppPackage -v 10000 -s 100`  // monkey tool is generating 10.000 random events on the real device  

## Paths

/data/data/packageName/databases        // app databases  
/data/data/packageName/shared_prefs/    // shared preferences  
/data/app                             // apk installed by user  
/system/app                           // pre-installed APK files  
/mmt/asec                             // encrypted apps, App2SD  
/mmt/emmc                             // internal SD Card  
/mmt/adcard                           // external/Internal SD Card  
/mmt/adcard/external_sd               // external SD Card

## Device onformation

`adb get-state`                       // print device state  
`adb get-serialno`                    // get the serial number  
`adb shell service list`              // list all services

## Device Related Commands

`adb backup -apk -all -f backup.ab`             // backup settings and apps  
`adb backup -apk -shared -all -f backup.ab`     // backup settings, apps and shared storage  
`adb backup -apk -nosystem -all -f backup.ab`   // backup only non-system apps  
`adb restore backup.ab`                         // restore a previous backup

## Other

`adb backup`      // Create a full backup of your phone and save to the computer.  
`adb restore`     // Restore a backup to your phone.  
`adb sideload`    //  Push and flash custom ROMs and zips from your computer.

## Using tail -n

// Use tail to remove the first line. Actually two lines. The first one is just a newline. The second is "List of devices attached."  
`adb devices | tail -n +2`

## Using cut -sf

// Cut the last word and any white space off the end of each line.  
`adb devices | tail -n +2 | cut -sf -1`

## Using xargs -I

// Given the -I option, xargs will perform an action for each line of text that we feed into it.  
// We can give the line a variable name to use in commands that xargs can execute.  
`adb devices | tail -n +2 | cut -sf -1 | xargs -I X echo X aw yiss`

## Three options below together will print android version of all connected devices

`adb devices | tail -n +2 | cut -sf -1 | xargs -I X adb -s X shell getprop ro.build.version.release`

## Using alias

### Example 1

`alias tellMeMore=echo`  
`tellMeMore "hi there"`  
Output => hi there

### Example 2

`alias apkinstall="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X install -r $1"`   // Define alias  
`apkinstall ~/Downloads/MyAppRelease.apk`  // Install an apk on all devices

### Example 3

`alias rmapp="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X uninstall $1"`  
`rmapp com.example.myapp`                 // Uninstall a package from all devices

### Example 4

`alias clearapp="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X shell pm clear $1"`  
`clearapp com.example.myapp`              // Clear data on all devices (leave installed)

### Example 5

`alias startintent="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X shell am start $1"`  
`startintent https://twitter.com/JonFHancock`   // Launch a deep link on all devices

### Setting up your .bash_profile

Finally, to make this all reusable even after rebooting your computer (aliases only last through the current session), we have to add these to your .bash_profile.  
You might or might not already have a .bash_profile, so let's make sure we append to it rather than overwriting it. Just open a terminal, and run the following command

touch .bash_profile && open .bash_profile       // This will create it if it doesn't already exist, and open it in a text editor either way. Now just copy and paste all of the aliases into it, save, and close.

`alias startintent="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X shell am start $1"`  
`alias apkinstall="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X install -r $1"`  
`alias rmapp="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X uninstall $1"`  
`alias clearapp="adb devices | tail -n +2 | cut -sf 1 | xargs -I X adb -s X shell pm clear $1"`

#### Key event

[KeyEvent](https://developer.android.com/reference/android/view/KeyEvent.html)
