# OpenSSL command line

`openssl` is the command-line front end of the OpenSSL library. It creates keys and certificates, converts between formats,
inspects TLS servers, computes hashes and HMACs, and encrypts files. The commands below were tested with OpenSSL 3.x;
most also work with 1.1.1, with the differences noted.

```shell
openssl version -a          # version, build options, OPENSSLDIR (default config and CA paths)
openssl help                # list of commands
openssl <command> -help     # options of one command, e.g. openssl x509 -help
```

Java/Android keystores (`.jks`, `keytool`) are covered in [../Android/Signing/keytool_cmds.md](../Android/Signing/keytool_cmds.md).

## 1. File formats

| Format | Extensions | Content |
| --- | --- | --- |
| PEM | `.pem`, `.crt`, `.cer`, `.key` | Base64 text between `-----BEGIN ...-----` / `-----END ...-----` lines; can hold several certificates |
| DER | `.der`, `.cer` | Binary form of one certificate or key |
| PKCS#7 | `.p7b`, `.p7c` | Certificates (chain) only, no private key; PEM or DER |
| PKCS#12 | `.p12`, `.pfx` | Certificate chain **and** private key in one password-protected file |
| PKCS#8 | `.pk8`, `.key` | Private key (any algorithm), optionally encrypted; Android's `platform.pk8` is DER PKCS#8 |

The extension doesn't reliably tell PEM from DER: a PEM file starts with `-----BEGIN`, a DER file is binary.

## 2. Keys, CSRs, and certificates

```shell
# private keys (genpkey works for every algorithm)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out rsa.key
openssl genpkey -algorithm EC  -pkeyopt ec_paramgen_curve:P-256 -out ec.key
openssl genpkey -algorithm ED25519 -out ed25519.key
openssl pkey -in ec.key -pubout -out ec.pub              # extract the public key

# certificate signing request (CSR) to send to a CA
openssl req -new -key ec.key -out server.csr \
    -subj "/CN=example.com" -addext "subjectAltName=DNS:example.com,DNS:www.example.com"
openssl req -in server.csr -noout -text                  # check it

# self-signed certificate + new key in one step (test servers, internal use)
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
    -keyout server.key -out server.crt -days 365 \
    -subj "/CN=test.local" -addext "subjectAltName=DNS:test.local"
```

+ `-noenc` stores the private key unencrypted (OpenSSL 3.0+; older versions use `-nodes`). Without it you are asked for a pass phrase.
+ Browsers and modern clients check the **subjectAltName**, not the CN. Always set the SAN.
+ Keep private keys readable only by their owner: `chmod 600 server.key`.

## 3. Inspect certificates

```shell
openssl x509 -in cert.pem -noout -text                         # everything
openssl x509 -in cert.pem -noout -subject -issuer -dates       # short summary
openssl x509 -in cert.pem -noout -ext subjectAltName           # one extension (OpenSSL 3.0+)
openssl x509 -in cert.pem -noout -checkend 2592000             # exit 1 if it expires within 30 days
openssl x509 -in cert.der -inform DER -noout -text             # DER input
```

**Fingerprints** (hash of the DER-encoded certificate):

```shell
openssl x509 -in cert.pem -noout -fingerprint            # default: SHA-1  -> "SHA1 Fingerprint=D6:E4:..."
openssl x509 -in cert.pem -noout -fingerprint -sha256    # SHA-256
```

When comparing with a fingerprint from another tool (browser, `keytool`, `apksigner`), use the same hash algorithm. `keytool` shows SHA-256.

## 4. Convert between formats

```shell
# PEM <-> DER
openssl x509 -in cert.pem -outform DER -out cert.der
openssl x509 -in cert.der -inform DER -out cert.pem

# PKCS#7 -> PEM certificates (add -inform DER if the .p7b is binary)
openssl pkcs7 -in chain.p7b -print_certs -out chain.pem

# PKCS#12 -> PEM
openssl pkcs12 -in bundle.p12 -nokeys -out certs.pem             # certificates only
openssl pkcs12 -in bundle.p12 -nocerts -noenc -out key.pem       # private key only, unencrypted

# PEM -> PKCS#12 (key + certificate + optional chain)
openssl pkcs12 -export -in cert.pem -inkey key.pem -certfile chain.pem \
    -name myalias -out bundle.p12

# DER PKCS#8 private key (e.g. Android .pk8) -> PEM
openssl pkcs8 -inform DER -in platform.pk8 -nocrypt -out platform.key.pem
```

+ The PEM output of `pkcs12` starts with `Bag Attributes` lines. They are harmless; most tools skip them.
+ `-name` sets the alias when **creating** a PKCS#12 file (`keytool` shows it as the alias). It doesn't select an entry when extracting.
+ OpenSSL 3 encrypts new `.p12` files with AES/PBKDF2. Some older Java versions and Windows releases can't read them; add `-legacy` to `-export` for those.

## 5. Check that a key matches a certificate

Compare the hash of the public key from both sides. This works for RSA, EC, and Ed25519 keys:

```shell
openssl pkey -in key.pem -pubout | openssl sha256
openssl x509 -in cert.pem -noout -pubkey | openssl sha256
openssl req  -in server.csr -noout -pubkey | openssl sha256     # a CSR, too
```

If the hashes are equal, the key belongs to the certificate. The older method compares `openssl rsa -modulus` and `openssl x509 -modulus`, which only works for RSA keys.

## 6. Verify chains and test TLS servers

```shell
openssl verify -CAfile ca.pem -untrusted intermediate.pem server.crt    # "server.crt: OK"

openssl s_client -connect example.com:443 -servername example.com </dev/null   # handshake, chain, verify result
openssl s_client -connect example.com:443 -servername example.com -showcerts </dev/null
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates                             # server certificate summary
openssl s_client -connect mail.example.com:587 -starttls smtp </dev/null      # STARTTLS protocols
```

+ `-servername` sends SNI; without it, servers that host several sites may return the wrong certificate.
+ `</dev/null` makes `s_client` exit after the handshake instead of waiting for input.
+ Look for `Verify return code: 0 (ok)` in the output.

## 7. Hashes and HMAC (`dgst`)

```shell
openssl dgst -sha256 file.iso                          # SHA2-256(file.iso)= ...
openssl dgst -sha3-256 file.iso
openssl dgst -list                                     # supported digests

printf 'hello world' | openssl dgst -sha256 -hmac "key"            # HMAC-SHA256
printf 'hello world' | openssl dgst -sha256 -hmac "key" -binary > mac.bin

# sign and verify a file with a key pair
openssl dgst -sha256 -sign key.pem -out file.sig file.bin
openssl dgst -sha256 -verify pub.pem -signature file.sig file.bin   # "Verified OK"
```

+ `echo` adds a newline that becomes part of the input; use `printf` or `echo -n` when the exact bytes matter.
+ Use SHA-256 or better; MD5 and SHA-1 are broken for security (see [../unclassified/hashingAlgorithm.md](../unclassified/hashingAlgorithm.md)).
+ An HMAC proves that someone with the key produced the data. A plain hash only detects changes if the hash itself is trusted.
+ For Ed25519 keys, `dgst -sign` doesn't work; use `openssl pkeyutl -sign -rawin`.

## 8. Symmetric encryption (`enc`)

```shell
openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in plain.txt -out plain.txt.enc        # encrypt
openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -d -in plain.txt.enc -out plain.txt           # decrypt

printf 'Hello World\n' | openssl enc -aes-256-cbc -pbkdf2 -a          # -a: Base64 output, e.g. U2FsdGVkX1...
printf 'U2FsdGVkX18NCO0bPKhLf+6Ad9F1f3hUZ+fTb28c66A=\n' \
    | openssl enc -aes-256-cbc -pbkdf2 -a -d                             # asks for the pass phrase
```

| Option | Meaning |
| --- | --- |
| `-e` / `-d` | Encrypt (default) / decrypt |
| `-pbkdf2` | Derive the key from the pass phrase with PBKDF2 (default 10000 iterations). Without it, OpenSSL uses a weak legacy derivation and prints a warning |
| `-iter <n>` | PBKDF2 iteration count (implies `-pbkdf2`); higher is slower to brute-force. Use the same value to decrypt |
| `-salt` | Random salt, on by default. The output starts with `Salted__` (Base64: `U2FsdGVkX1`) |
| `-a` / `-base64` | Base64-encode after encrypting, or decode before decrypting |
| `-pass pass:<pw>` / `-pass env:VAR` / `-pass file:<path>` | Pass phrase source. `pass:` is visible in `ps` and shell history; prefer `env:` or `file:` |

+ `openssl aes-256-cbc ...` is shorthand for `openssl enc -aes-256-cbc ...`; `-aes256` is an alias for `-aes-256-cbc`.
+ `openssl enc` provides **no integrity protection**: CBC output can be modified without detection, and it doesn't support authenticated modes like AES-GCM.
  The format is also OpenSSL-specific. For real file encryption, prefer `age` or `gpg`.
+ Decryption must use the same cipher, `-pbkdf2`/`-iter`, and digest options as encryption. Files encrypted with OpenSSL 1.0 (MD5 key derivation) need `-md md5` to decrypt.

## 9. Other useful commands

```shell
openssl rand -hex 32                   # 32 random bytes as hex (keys, tokens)
openssl rand -base64 24                # random password-like string
openssl base64 -in file.bin            # Base64 encode (-d to decode)
openssl passwd -6 'secret'             # SHA-512 crypt hash for /etc/shadow
openssl list -cipher-algorithms        # available ciphers
```

## Related notes

+ [../unclassified/hashingAlgorithm.md](../unclassified/hashingAlgorithm.md): hash functions and which ones are secure
+ [checksumCmd.md](checksumCmd.md): `sha256sum`, `b2sum`, and checksum verification
+ [../Android/Signing/keytool_cmds.md](../Android/Signing/keytool_cmds.md): Java keystores and `keytool`
+ [../Android/Signing/sign_apk.md](../Android/Signing/sign_apk.md): converting AOSP `.pk8` keys and signing APKs
+ [../Android/Signing/verify_platformKeys.md](../Android/Signing/verify_platformKeys.md): comparing certificate hashes of an AOSP build
+ [ssh_login.md](ssh_login.md): SSH keys (a different key format and tool)

## Reference

+ OpenSSL manual pages: <https://docs.openssl.org/master/man1/>
+ `openssl-enc`: <https://docs.openssl.org/master/man1/openssl-enc/>
+ `openssl-dgst`: <https://docs.openssl.org/master/man1/openssl-dgst/>
+ `openssl-s_client`: <https://docs.openssl.org/master/man1/openssl-s_client/>
+ DigiCert OpenSSL quick reference: <https://www.digicert.com/kb/ssl-support/openssl-quick-reference-guide.htm>
