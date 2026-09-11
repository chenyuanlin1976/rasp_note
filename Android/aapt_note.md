# aapt/aapt2 - Android Asset Packaging Tool

## aapt - List contents of Zip-compatible archive

+ `aapt list -a xxx.apk | grep minSdkVersion`  
+ `aapt dump badging xxx.apk`  
  + badging: Prints information extracted from the APK's manifest.
+ `aapt dump permissions xxx.apk`  
  + permissions: Prints the permissions extracted from the APK's manifest.  
+ `aapt dump xmltree xxx.apk AndroidManifest.xml`  

## aapt2 - newer aapt

`aapt2 [subcommand] [options] files`  

+ `aapt2 dump badging xxx.apk`  
+ `aapt2 dump packagename xxx.apk`  
+ `aapt2 dump permissions xxx.apk`  
+ `aapt2 dump strings xxx.apk`  
+ `aapt2 dump xmltree xxx.apk --file AndroidManifest.xml`  
  + packagename: Prints the APK's package name.  
  + strings: Prints the contents of the APK's resource table string pool.

[reference](https://developer.android.com/tools/aapt2)  
