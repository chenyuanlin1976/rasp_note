# NOTICE
  the default input/output file format of openssl is PEM
  Android Studio requires using PKCS12 format.

`openssl pkcs8 -in platform.pk8 -inform DER -outform PEM -out platform.priv.pem -nocrypt`
`openssl pkcs12 -export -in platform.x509.pem -inkey platform.priv.pem -out platform.pk12 -name [key_alias]`
`keytool -importkeystore -destkeystore platform.jks -srckeystore platform.pk12 -srcstoretype PKCS12 -alias [key_alias]`
`keytool -importkeystore -srckeystore platform.jks -destkeystore platform.jks -deststoretype pkcs12`

# How to import x509.pem and pk8 files into jks keystore
1. Generate a file platform.priv.pem from you pk8 file.
  `openssl pkcs8 -in platform.pk8 -inform DER -outform PEM -out platform.priv.pem -nocrypt`

2. Generate platform.pk12 file using both your platform.x509.pem file and the previously generated platform.priv.pem.
   The KEY_ALIAS is a string value and it can be anything.
   After entering below command, you'll be prompted for a key password: KEY_PASSWORD
  `openssl pkcs12 -export -in platform.x509.pem -inkey platform.priv.pem -out platform.pk12 -name KEY_ALIAS`

3. Create a brand new jks file, and import your key with the given key alias and password before.
   Once the command below is entered, you'll be prompted for the store password: STORE_PASSWORD.
  `keytool -importkeystore -destkeystore STORE_FILE_NAME.jks -srckeystore platform.pk12 -srcstoretype PKCS12 -srcstorepass KEY_PASSWORD -alias KEY_ALIAS`

4. Convert the keystore file to common used PKCS12 format.
  `keytool -importkeystore -srckeystore STORE_FILE_NAME.jks -destkeystore STORE_FILE_NAME.jks -deststoretype pkcs12`

5. Finally, you have STORE_FILE_NAME.jks, STORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD

[Ref](https://learn.microsoft.com/zh-tw/xamarin/android/deploy-test/signing/manually-signing-the-apk)

`keytool -genkeypair -v -keystore fileName.keystore -alias keyName -keyalg RSA -keysize 2048 -validity 10000`
`keytool -list -keystore xample.keystore`

# sign and verify
`apksigner sign --ks keystore.jks --ks-key-alias keyAlias_name | --key key.pk8 --cert cert.x509.pem [signer_options] app-name.apk`
or
`apksigner sign --ks keystore_name --ks-key-alias keyAlias_name app_name.apk`

`apksigner verify [options] app-name.apk`

# jarsigner / apksigner
V1(Jar Signature) V2(Full APK Signature)
after Android 7.0, Google declare new signing method: V2 Scheme (APK Signature);
under Android 7.0 version, only V1 scheme (JAR signing) works.

V1 scheme > zipalign: OK
V2 scheme > zipalign: NG
zipalign > V2 scheme: OK

# the default debug.keystore
In Eclipse or Android Studio: the default debug.keystore
keystore name: debug.keystore
key alias: androiddebugkey
pw for key: android

# step to sign
1. generate keystore
  `keytool -genkeypair -v -keystore <filename>.keystore -alias <key-name> -keyalg RSA -keysize 2048 -validity 10000`
2. view the content of keystore
  `keytool -list -v -keystore ks_name`
3. Signing
  a. method 1: Jarsigner (only support V1 scheme)
    `jarsigner -keystore ks_name xxx.apk key_alias`

  b. method 2: apksigner (default using V1 and V2 scheme at the same time)
    `apksigner -sign -ks ks_name -ks-key-alias key_name xxx.apk`
4. verify signing
  `keytool -printcert -jarfile myApp.apk`
  `apksigner verfy -v --print-cert xxx.apk`

# what is a keystore, and what is it used for?
Android Market requires you to sign all apps you submit with a certificates, the usage of a public/non-public key.

This affords a layer of protection that prevents, amongst different things, remote attackers from pushing malicious updates on your application to market.
(All keystore file is to authenticate yourself to anyone who is asking.)

It isn't restricted to merely signing .apk files, you'll be able to use it to store personal certificates, sign data to be transmitted and an entire kind of authentication.

In terms of what you are doning with it for android and possibly what you're searching for since you memtion signing apk, it's your certificate.
You're stigmatisation your application along with your credentials.

You'll be able to complete multiple applications with an equivalent key, in fact, it is counselled that you simply use one certificate to brand multiple applications that you write.
It's easier to stay track of what applications belong to you.

How can I get it? In android we can generate keystore for debug and release build.key
1. We will configure debug keystore.
  Run this command in your main android project directory,
  keytool -gnekey -v
          -keystore debug.keystore
          -storepass android
          -alias androiddebugkey
          -keypass android
          -keyalg RSA
          -keysize 2048
          -validity 10000

After that you need to add some detail which will ask by terminal, fill it.
Now you can use this keystore for creating a debug android build.

2. Generate release keystore.
  keytool -genkey -v
          -keystore my_key.keystore
          -alias alias_name
          -keyalg RSA
          -keysize 2048
          -validity 10000

After that you need to add some detail which will ask by terminal, fill it.
Now you can use this keystore for creating a release android build.


