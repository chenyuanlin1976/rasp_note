# verify platform keys

To verify that your custom-generated AOSP platform keys  
(and other keys like media, shared, releasekey) have been correctly applied to your build,  
you need to inspect the cryptographic signatures of the compiled APKs and system images inside your out/ directory.

By default, AOSP uses generic test keys located in `build/target/product/security/`.  
If you replaced them or specified a custom path via **PRODUCT_DEFAULT_DEV_CERTIFICATE**,  
you can verify success using the following methods:

## Method 1: Use apksigner on a Built System APK

Every APK compiled into the system image is signed during the build process.  
You can extract and check one of them (e.g., Settings.apk or Launcher3.apk) using the Android SDK's apksigner tool.

1. Locate a built system app in your output directory. For example:  
   `cd out/target/product/<your_device>/system/priv-app/Settings/`
2. Run the apksigner tool to print the certificate details:  
   `apksigner verify --print-certs Settings.apk`
3. Look at the Signer #1 certificate(s) output. It will display the SHA-1 and SHA-256 digests.
4. Compare this digest with the digest of your newly generated platform certificate (platform.x509.pem):  
   `keytool -printcert -file /path/to/your/custom-keys/platform.x509.pem`  
   If the SHA-256 fingerprints match, the build system successfully applied your custom platform key to the APKs.

## Method 2: Check All System Packages Using AOSP's Build Scripts

AOSP includes built-in python tools to inspect or re-sign target files.  
You can check the signatures of all packages packed into the target_files.zip.  

1. Locate the target files zip after a build:  
   `out/target/product/<your_device>/obj/PACKAGING/target_files_intermediates/<device>-target_files-*.zip`
2. You can use AOSP's sign_target_files_apks.py script in a dry-run or verification mode to check if packages are already signed with the expected keys, or check the script documentation.
3. Alternatively, unpack the target_files.zip and inspect META/apkcerts.txt.  
   This file maps every APK in your build to the specific certificate key used to sign it.  
   Look inside META/apkcerts.txt and ensure that packages designated as platform point to your custom key name rather than build/target/product/security/platform.

## Method 3: Functional Verification (Flash and Test)

The ultimate test of whether the platform key was applied correctly is behavior at runtime,  
specifically regarding shared user IDs and privileged permissions:

1. Flash the Build: Flash the newly built boot.img, system.img, and vendor.img (or super.img) to your target hardware or emulator.
2. Test a Custom Platform-Signed App: Write or use an app that declares `android:sharedUserId="android.uid.system"` or uses system-level privileged permissions.
3. Observe Installation / Execution:
   + If the app installs and runs successfully without throwing INSTALL_FAILED_SHARED_USER_INCOMPATIBLE or security exceptions,  
     your custom platform key was successfully applied to both the OS framework (framework.jar / PackageManager Service) and the APK.
   + If the build was signed with a mismatching key (e.g., framework signed with testkey but your app signed with your new custom key, or vice-versa),  
     the package manager will immediately reject the app upon boot or installation.
