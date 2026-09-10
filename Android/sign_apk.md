# sign APK note

## The pairs of private and public keys

1. public key : **platform.x509.pem**  
2. private key: **platform.pk8**

## To sign an apk with Android studio

you need to wrap the key pair into a keystore file. Type the followings commands to wrap them into keystore.  
`openssl pkcs8 -in platform.pk8 -inform DER -outform PEM -out platform.priv.pem -nocrypt`  
`openssl pkcs12 -export -in platform.x509.pem -inkey platform.priv.pem -out platform.pk12 -name [alias name]`  
`keytool -importkeystore -destkeystore platform.jks -srckeystore platform.pk12 -srcstoretype PKCS12 -alias [specify alias name]`  
`keytool -importkeystore -srckeystore platform.jks -destkeystore platform.jks -deststoretype pkcs12`  

## To sign the apk directly with apksigner command

`apksigner sign --key platform.pk8 --cert platform.x509.pem yourApp.apk` OR  
`apksigner sign --ks xxx.jks app.apk`

## To sign the apk in command line mode with apksigner

1. You can directly sign your apk with .pk8 and .pem files  
`apksigner sign --key platform.pk8 --cert platform.x509.pem app-name.apk`

2. OR you can sign you apk with wrapped keystore file.  
`apksigner sign --ks [keystore name] --ks-key-alias [alias_name] app-name.apk`

3. You also can sign your apk with jarsigner command.  
`java -jar signapk.jar platform.x509.pem platform.pk8 unsignedApp_name.apk signedApp_name.apk`

## To verify signed apk, the following commands both can verify the signed apk

`keytool -printcert -jarfile signedApk.apk`  
`apksigner verify -v --print-certs signedApk.apk`

## To verify a private or public key pair with openssl

1. Calculate private key modulus hash value:  
`openssl rsa -modulus -noout -in <private key file> | openssl md5`  
2. Calculate certificate modulus hash value:  
`openssl x509 -modulus -noout -in <certificate file> | openssl md5`

If the two hash strings are the same, it means the key pair matches. Otherwise, it is not a valid key pair.
