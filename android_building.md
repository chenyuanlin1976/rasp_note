# Android build rules

## Steps to Add a JAR File as a Library

1. Place the JAR File in the Project:
   Create a libs folder at the top level of your module directory, if it doesn't already exist.
   Copy the JAR file (e.g., gson-2.2.4.jar) into the libs folder.
2. Add the JAR File as a Library:
   Right-click on the JAR file in the libs folder and select Add as Library.
3. Update the build.gradle File:
   a. Ensure that the following line is included in the dependencies section of your build.gradle file:  
      `implementation files('libs/gson-2.2.4.jar')`
   b. Alternatively, if you have multiple JAR files, you can use:
      `implementation fileTree(dir: 'libs', include: '*.jar')`
4. Perform a Clean Build:
   Navigate to the root directory of your project and run the following command in the terminal:  
   `./gradlew clean`  
   This step ensures that any previous build artifacts are removed and the project is rebuilt from scratch.

## build with Gradle wrapper

You can execute all the build tasks available to your Android project using the Gradle wrapper command line tool.

1. `./gradlew assembleDebug`  
apk folder: ProjectName/app/build/outputs/apk/debug

2. `./gradlew assembleRelease`  
apk folder: ProjectName/app/build/outputs/apk/release

## build with android studio

1. generate App bundles or APKs  
apk folder: ProjectName/app/build/outputs/apk/debug

2. generate signed App bundles or APKs  
apk folder: ProjectName/app/release

## R8 and Proguard

R8 is the default code shrinking and obfuscation tool integrated into the Android Gradle Plugin (AGP) since version 3.4.  
It has effectively replaced ProGuard for most Android development, though it still utilizes ProGuard-compatible rules.

## Key aspects of R8 and ProGuard

### Code Shrinking

Both R8 and ProGuard analyze your application's bytecode and remove unused classes, methods, and fields, significantly reducing he APK size.

### Optimization

They perform various optimizations, such as inlining methods and removing dead code, to improve runtime performance.

### Obfuscation

They rename classes, methods, and fields to shorter, less descriptive names, making it harder for reverse engineers to understand he application's logic. This provides a basic level of code protection.

### ProGuard Rules

Even though R8 is the primary tool, you still define rules in proguard-rules.pro files to specify what code should be kept, bfuscated, or optimized. This is crucial for preventing R8 from removing or renaming essential components that are accessed hrough reflection or other dynamic means.

### Mapping File

When obfuscation is enabled, R8 generates a mapping.txt file.  
This file maps the original class and member names to their bfuscated equivalents, which is vital for deobfuscating crash reports and stack traces from production builds.
