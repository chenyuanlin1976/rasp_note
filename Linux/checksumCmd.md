# Linux checksum commands

GNU coreutils has one command per algorithm. They all print `<hash>  <file>` and can verify a list of hashes with `-c`.
For what the algorithms are and which ones are still secure, see [../unclassified/hashingAlgorithm.md](../unclassified/hashingAlgorithm.md).

## 1. Commands

| Command | Algorithm | Output | Use |
| --- | --- | --- | --- |
| `cksum` | CRC-32 (POSIX variant) + byte count | 32-bit number | Detect accidental corruption; POSIX standard, not secure |
| `sum` | BSD/System V 16-bit checksum | 16-bit number | Legacy only |
| `md5sum` | MD5 | 128 bits | Quick integrity check of trusted data; **broken** for security |
| `sha1sum` | SHA-1 | 160 bits | Legacy; **broken** for security |
| `sha224sum`, `sha256sum` | SHA-2 | 224 / 256 bits | Default choice for verifying downloads |
| `sha384sum`, `sha512sum` | SHA-2 | 384 / 512 bits | Same family, longer output (often faster on 64-bit CPUs) |
| `b2sum` | BLAKE2b | 512 bits (`-l` for shorter) | Fast and secure |

Since coreutils 9.0, `cksum -a <algo>` covers all of them (`cksum -a sha256 file`), and `cksum -a crc32b` gives the zlib/Ethernet CRC-32.
Older systems (e.g. coreutils 8.32 on Ubuntu 22.04) don't have `-a`.

## 2. Examples

```shell
printf 'helloWorld\n' > hello.txt

cksum hello.txt
# 459671370 11 hello.txt                  CRC and size in bytes

md5sum hello.txt
# 60cd8d2a103a58f173e8e5d6d7ac490c  hello.txt

sha256sum hello.txt
# 23bd1d9aca0d25eff2d1b46f9337c595e49915ba465dcd7d932a13911ac25df0  hello.txt
```

+ The hash covers the exact bytes, including the trailing newline. `echo -n helloWorld` or a file with Windows line endings (`\r\n`) gives a different hash.
+ Use `-` or no file name to hash standard input: `printf 'abc' | sha256sum`.
+ On Windows (Git Bash) the output shows `*file` instead of `  file`; the `*` marks binary mode and doesn't change the hash.

## 3. Verify files

```shell
sha256sum *.img > SHA256SUMS          # create a checksum list
sha256sum -c SHA256SUMS               # verify: prints "file: OK" or "file: FAILED"
sha256sum -c --ignore-missing SHA256SUMS   # skip files listed but not downloaded
echo "<expected-hash>  ubuntu.iso" | sha256sum -c -   # check one file against a published hash
```

The list format is `<hash><two spaces><file>`. `-c` exits with a non-zero status if any file fails, so it works in scripts.

A matching hash proves the file is the one the hash was made from. It protects against tampering only if the hash list itself is trusted,
for example downloaded over HTTPS or signed (`gpg --verify SHA256SUMS.gpg SHA256SUMS`).

## 4. Other tools

```shell
openssl dgst -sha256 hello.txt        # also -sha3-256, -blake2b512; see openssl_note.md
openssl dgst -sha256 -hmac "secret" hello.txt   # HMAC with a key
xxhsum hello.txt                      # xxHash (package xxhash), fast non-cryptographic
crc32 hello.txt                       # zlib CRC-32 (from libarchive-zip-perl on Debian/Ubuntu)
```

## Related notes

+ [../unclassified/hashingAlgorithm.md](../unclassified/hashingAlgorithm.md): how hash functions work, which are secure
+ [openssl_note.md](openssl_note.md): `openssl dgst` and other OpenSSL commands
+ [../shellScript/linux_cmds.md](../shellScript/linux_cmds.md): Linux command cheat sheet

## Reference

+ GNU coreutils, digest commands: <https://www.gnu.org/software/coreutils/manual/html_node/Summarizing-files.html>
+ POSIX `cksum`: <https://pubs.opengroup.org/onlinepubs/9799919799/utilities/cksum.html>
