# openssl - OpenSSL command line program

[RefWebsite](https://www.digicert.com/kb/ssl-support/openssl-quick-reference-guide.htm)

OpenSSL is an open-source command line tool that is commonly used to generate private keys, create CSRs, install your SSL/TLS certificate, and identify certificate information.  
`openssl version -a`

## How to show the contents of a certificate

1. Command to show certificate content in OpenSSL:  
   `openssl x509 -in <cert_file_name> -noout -text`

2. Command to show certificates or key pairs that are stored in a keystore using keytool.  
   PrivateKeyEntry means that it stores both private key and certificate chain entries.  
   TrustedCertEntry means that it only stores trusted certificate and certificate chain entries:  
   `keytool -list -v -in <keystore_file_name>`

## How to show certificate finger print or thumb print

1. Command to show a certificate fingerprint in OpenSSL by default is sha1 fingerprint in OpenSSL. Ensure you are using the same hash algorism when comparing to another certificate  
   `openssl x509 -in <certificate file> -noout -fingerprint [-sha1 or -sha256 or -sha512]`

2. Command to show certificate fingerprint in keytool by default is sha256  
   `keytool -list -keystore <keystore file>`

## How to convert certificate and private key between different formats

1. Convert certificate format from DER to PEM  
   `openssl x509 -in <certificate file in DER format> -inform DER -out <certificate file in PEM format>`

2. Convert certificate format from PKCS7to PEM  
   `openssl pkcs7 -print_certs -in <certificate file in PKCS7 format> -inform DER -out <certificate file in PEM format>`

3. Convert certificate and private key format from PKCS12 to PEM.  
   The first command is to extract certificate file in a PEM format,  
   the second command is to extract private key file in a PEM format.  
   `openssl pkcs12 -in <certificate file in PKCS12 format> -name <alias name> -nokeys -out <certificate file in PEM format>`  
   `openssl pkcs12 -in <certificate file in PKCS12 format> -name <alias name> -nodes -nocerts -out <private key file in PEM format>`

4. Convert certificate or private key pair files from PEM to PKCS12 keystore  
   `openssl pkcs12 -export -in <certificate file in PEM format> -inkey <private key file in PEM format> -name <alias name> -out <keystore file in PKCS12 format>`

## How to validate a private or public key pair using OpenSSL

1. Calculate private key modulus hash value:  
   `openssl rsa -modulus -noout -in <private key file> | openssl md5`
2. Calculate certificate modulus hash value:  
   `openssl x509 -modulus -noout -in <certificate file> | openssl md5`

If the two hash strings are the same, it means the key pair matches. Otherwise, it is not a valid key pair.

## openssl: AES encryption and decryption

`openssl version`  
`openssl help`  
`openssl enc -help`  
`openssl enc -ciphers`

[options](https://docs.openssl.org/3.0/man1/openssl-enc/#options)  

+ enc    : Encryption, decryption, and encoding.  
+ -pbkdf2: Use PBKDF2 algorithm with a default iteration count of 10000  
+ -in    : input file  
+ -out   : output file  
+ -e     : Encrypt the input data. this is the default  
+ -d     : Decrypt the input data  
+ -a     : Base64 process the data.
+ -base64: Same as -a

### How to encrypt, decrypt a file

**encrypt then decrypt**  

+ `openssl enc -aes-256-cbc -pbkdf2 -in plain.txt -out encrypted.txt`  
+ `openssl enc -aes-256-cbc -pbkdf2 -d -in encrypted.txt -out plain.txt`

OR  

+ `openssl aes-256-cbc -pbkdf2 -in plain.txt -out encrypted.txt`
+ `openssl aes-256-cbc -pbkdf2 -d -in encrypted.txt -out plain.txt`  

### How to encrypt, decrypt a string

+ encrypt: `echo "PLAINTEXT_STRING" | openssl enc -aes256 -pbkdf2 -base64`  
+ decrypt: `echo "ENCRYPTED_STRING" | openssl enc -aes256 -pbkdf2 -base64 -d`

Example:

+ encrypt: `echo "Hello World" | openssl aes-256-cbc -pbkdf2 -a`
+ decrypt: `echo "U2FsdGVkX1+VIYNS16za1jP8/V4arrgsxCbk3C19tuU=" | openssl aes-256-cbc -pbkdf2 -a -d`

option -a: Base64 process the data. This means that  
  if **encryption** is taking place the data is base64 encoded after encryption.  
  If **decryption** is set then the input data is base64 decoded before being decrypted.

### openssl dgst - perform digest operations

[openssl-dgst](https://docs.openssl.org/3.0/man1/openssl-dgst/#options)

**MAC**: keyed Message Authentication Code

`echo -n 'hello world' | openssl dgst -sha1 -hmac "key"`  
`echo -n 'hello world' | openssl dgst -sha1 -hmac "key" -binary > hash-file.bin`  

+ -hmac key: Create a hashed MAC using "key".
+ -binary: Output the digest or signature in binary form.
