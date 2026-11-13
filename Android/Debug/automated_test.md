# Automated Android testing from a Linux host

This note covers ways to drive an Android device from a Linux console and get pass/fail results back: plain adb scripts, Appium, and instrumentation tests (Espresso, UiAutomator).
All of them talk to the device over adb.
Installing adb, connecting a device and USB debugging are in [adb_intro.md](adb_intro.md); `am`, `input` and `monkey` are in [adb_shell_cmds.md](adb_shell_cmds.md); log filtering is in [logcat_intro.md](logcat_intro.md).

## 1. Choose an approach

| Approach | Runs where | Needs app source? | Good for |
| --- | --- | --- | --- |
| adb + shell/Python script | Host | No | Quick automation: launch, tap coordinates, screenshots, collect logs |
| Appium (UiAutomator2 driver) | Host script → Appium server → device | No | Black-box UI tests in Python, JavaScript, Java, ... |
| Espresso (instrumentation) | Test APK in the app's process | Yes | Fast, reliable UI tests of your own app; synchronizes with the UI thread |
| UiAutomator (instrumentation) | Test APK on the device | No (only a test APK) | UI tests that cross apps: system UI, settings, notifications |
| `monkey` | Device | No | Random-event stress test; see [adb_shell_cmds.md](adb_shell_cmds.md) |

+ Appium is slower than Espresso, because every command goes host → server → device and back.
+ Espresso only sees the app under test. Use UiAutomator (or Appium, which uses it underneath) for anything outside the app.
+ Coordinate taps (`input tap x y`) break when the screen size, density or layout changes. Find elements by resource ID or text when you can.

## 2. adb scripting with Python

A small script that restarts an app, taps, saves a screenshot, and fails if the app crashed:

```python
#!/usr/bin/env python3
import subprocess
import sys
import time

PKG = "com.example.app"
SERIAL = None              # e.g. "1234abcd" when several devices are connected


def adb(*args, text=True):
    cmd = ["adb"] + (["-s", SERIAL] if SERIAL else []) + list(args)
    return subprocess.run(cmd, check=True, capture_output=True, text=text).stdout


adb("wait-for-device")
adb("logcat", "-b", "all", "-c")                       # start with empty log buffers
adb("shell", "am", "force-stop", PKG)
adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
time.sleep(3)                                          # crude; poll the UI for real tests

adb("shell", "input", "tap", "500", "1200")
time.sleep(1)

with open("screen.png", "wb") as f:
    f.write(adb("exec-out", "screencap", "-p", text=False))

crashes = adb("logcat", "-d", "-b", "crash")
if "FATAL EXCEPTION" in crashes:
    print(crashes)
    sys.exit(1)
print("PASS")
```

+ `monkey -p <pkg> -c android.intent.category.LAUNCHER 1` starts the launcher activity without knowing its name.
  With the name, use `am start -W -n <pkg>/.MainActivity`, which also waits until the launch has finished.
+ To find elements instead of coordinates, dump the current UI hierarchy and read the `resource-id`, `text` and `bounds` attributes:

  ```shell
  adb shell uiautomator dump            # writes /sdcard/window_dump.xml
  adb pull /sdcard/window_dump.xml
  ```

  The dump fails with "could not get idle state" while the screen is animating.

## 3. Appium (Python)

```text
test_android.py  --HTTP-->  Appium server (port 4723)  --adb-->  UiAutomator2 server on the device  -->  app
```

### 3.1 Install

```shell
# Node.js and npm: Appium 2+ needs a current Node.js LTS; distribution packages may be too old (check node --version)
sudo apt install nodejs npm

npm install -g appium                       # may need sudo, or a user-level npm prefix
appium driver install uiautomator2

# The UiAutomator2 driver finds adb through ANDROID_HOME (an SDK directory with platform-tools/)
export ANDROID_HOME=$HOME/Android/Sdk

# Python client, in a virtual environment (newer Debian/Ubuntu block system-wide pip install)
python3 -m venv ~/venvs/appium
. ~/venvs/appium/bin/activate
pip install Appium-Python-Client
```

### 3.2 Test script

`test_android.py` adds 2 + 3 in the AOSP Calculator and checks the result.
Package names, activity names and resource IDs differ between devices (Google's Calculator is `com.google.android.calculator`, with different IDs), so look them up with `uiautomator dump` (section 2) or Appium Inspector.

```python
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

options = UiAutomator2Options()            # sets platformName=Android, automationName=UiAutomator2
options.udid = "1234abcd"                  # serial from "adb devices"; deviceName doesn't pick a device
options.app_package = "com.android.calculator2"
options.app_activity = "com.android.calculator2.Calculator"
options.no_reset = True                    # don't clear the app data before the session

driver = webdriver.Remote("http://127.0.0.1:4723", options=options)
try:
    wait = WebDriverWait(driver, 10)       # explicit waits instead of time.sleep()
    rid = "com.android.calculator2:id/"
    for name in ("digit_2", "op_add", "digit_3", "eq"):
        wait.until(EC.element_to_be_clickable((AppiumBy.ID, rid + name))).click()

    result = driver.find_element(AppiumBy.ID, rid + "result").text
    assert result == "5", f"expected 5, got {result!r}"
    print("PASS")
finally:
    driver.quit()                          # end the session even if the test fails
```

For many tests, put them in `pytest` test functions with a fixture that creates and quits the driver; pytest then prints the summary and sets the exit code.

### 3.3 Run

```shell
appium                                      # terminal 1: start the server (Appium 2+: no /wd/hub base path)
python3 test_android.py                     # terminal 2
```

## 4. Instrumentation tests (Espresso, UiAutomator)

Instrumentation tests live in the app project under `app/src/androidTest/`.
Gradle builds them into a separate **test APK** (`<applicationId>.test` by default), which runs on the device with the app.

### 4.1 Example test

```kotlin
// app/build.gradle.kts
android {
    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
}
dependencies {
    androidTestImplementation("androidx.test.ext:junit:<version>")
    androidTestImplementation("androidx.test.espresso:espresso-core:<version>")
}
```

```kotlin
// app/src/androidTest/java/com/example/app/MainActivityTest.kt
@RunWith(AndroidJUnit4::class)
class MainActivityTest {
    @get:Rule
    val rule = ActivityScenarioRule(MainActivity::class.java)

    @Test
    fun tapButton_showsGreeting() {
        onView(withId(R.id.button)).perform(click())
        onView(withId(R.id.message)).check(matches(withText("Hello")))
    }
}
```

### 4.2 Run with Gradle

```shell
cd /path/to/project
./gradlew connectedAndroidTest              # build both APKs, install, run on every connected device

# One class
./gradlew connectedAndroidTest \
    -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.MainActivityTest
```

Gradle prints a pass/fail summary, exits non-zero on failure, and writes reports to `app/build/reports/androidTests/connected/` (HTML) and `app/build/outputs/androidTest-results/connected/` (XML).

Google's Android SDK build tools (and Android Studio) aren't available for Linux arm64.
On an arm64 host such as a Jetson or Raspberry Pi, build the APKs on an x86-64 machine and run them with `am instrument` (section 4.3).

### 4.3 Run with `am instrument`

When the app and test APKs are already built:

```shell
adb install -r app-debug.apk
adb install -r -t app-debug-androidTest.apk

adb shell pm list instrumentation           # test packages and their runners

adb shell am instrument -w com.example.app.test/androidx.test.runner.AndroidJUnitRunner
adb shell am instrument -w -e class com.example.app.MainActivityTest \
    com.example.app.test/androidx.test.runner.AndroidJUnitRunner
```

+ `-w` waits until the tests finish; without it, `am instrument` returns immediately.
+ The output ends with `OK (N tests)` or `FAILURES!!!` and the stack traces.
  Check for that text in scripts: the exit status of `am instrument` doesn't reliably report test failures.
+ `-r` prints raw, machine-readable status lines, for tools that parse the result.

## 5. Collect results

| What | How |
| --- | --- |
| Test summary | Gradle output and reports (section 4.2); `am instrument -w` output (section 4.3) |
| App logs | `adb logcat --pid=$(adb shell pidof -s <pkg>)`, `adb logcat -d > log.txt`; see [logcat_intro.md](logcat_intro.md) |
| Crashes | `adb logcat -d -b crash` |
| Screenshot | `adb exec-out screencap -p > screen.png` |
| Files in shared storage | `adb pull /sdcard/Download/export.csv .` |
| Files in the app's private directory | Debuggable app: `adb exec-out run-as <pkg> cat databases/app.db > app.db`. Otherwise root (`adb root`, userdebug builds) |

+ `run-as` runs as the app's UID, so it can read `/data/data/<pkg>/` but usually can't write to `/sdcard`.
  `adb exec-out` streams the file straight to the host instead.
+ A SQLite database in WAL mode keeps recent changes in `app.db-wal`. Copy that file too, or close the database first.

## Related notes

+ [adb_intro.md](adb_intro.md), [adb_shell_cmds.md](adb_shell_cmds.md), [logcat_intro.md](logcat_intro.md)
+ [../App/gradle_build.md](../App/gradle_build.md), [../App/app_project_structure.md](../App/app_project_structure.md), [../App/app_components.md](../App/app_components.md)

## Reference

+ [Test apps on Android](https://developer.android.com/training/testing)
+ [Espresso](https://developer.android.com/training/testing/espresso)
+ [UI Automator](https://developer.android.com/training/testing/other-components/ui-automator)
+ [Test from the command line](https://developer.android.com/studio/test/command-line)
+ [Appium documentation](https://appium.io/docs/en/latest/)
+ [Appium UiAutomator2 driver](https://github.com/appium/appium-uiautomator2-driver)
+ [Appium Python client](https://github.com/appium/python-client)
