# AOSP build system: helper commands

the AOSP build system provides several other handy helper commands (shell functions) initialized by `envsetup.sh`.  
These make navigating the massive codebase and building specific parts much faster.

**Pro-Tip**: Before you can use the AOSP build helpers in your terminal,  
you must first initialize your environment variables by running source `build/envsetup.sh` followed by `lunch <your-target>`.

## common helper commands

### command: `m`

+ Working Directory Requirement: Can be run from anywhere in the source tree
+ Scope of Build: The whole tree (or a named target)
+ Common Use Case: Building the final boot/system images or running a full build.

### Command: `mm`

+ What it does: Builds the modules in the current directory (and its dependencies) without having to specify the path.
+ Example: `cd packages/apps/Settings`

### command: `mmm`

+ Working Directory Requirement: Pass directory paths as arguments
+ Scope of Build: Only the modules in the specified directories
+ Common Use Case: Rapidly testing a code change in a specific app or service.

### mma/ mmma

+ What it does: Like `mm` and `mmm`,  
  but forces a build with asynchronous dependency building enabled (ensures all dependencies are built correctly).
+ Example: `mma`

### command: croot

+ What it does: Instantly changes your terminal's working directory back to the root of the AOSP source tree from anywhere.
+ Example: `croot`

### command: `cproj`

+ What it does: Changes directory to the project root corresponding to your current working directory (based on git).
+ Example: `cproj`

### command: jrange / jpid

+ What it does: Helps manage background Java processes or background build tasks.
+ Example: `jpid <process_name>`

## Navigation & Search Helpers

+ `rosc`: Jumps straight to the root of the current project based on the nearest Android.mk or Android.bp.
+ `jgrep`: A wrapper around find and grep that searches for patterns specifically inside Java files (.java).
+ `cgrep`: Searches for patterns inside C/C++ source files (.c, .cpp, .h).
+ `ggrep`: Searches for patterns inside Gradle files (.gradle, Android.mk, Android.bp).
+ `resgrep`: Searches for string resources inside Android XML resource files (res/values/...).

## Quick Lookups

+ `printconfig`: Prints your current lunch target configuration, build variant, and environment variables (like TARGET_PRODUCT and PLATFORM_VERSION).
+ `gprefs`: Opens your git preferences or configures remote repos if working with repo.
