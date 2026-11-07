# Archiving and compression: tar, gzip, xz, zstd, zip

This note covers the common archive and compression tools on Linux and when to use each.
Two different jobs are involved:

+ **Archiving** packs many files and directories into one file, keeping paths, permissions and timestamps: `tar`.
+ **Compressing** makes **one** stream of data smaller: `gzip`, `bzip2`, `xz`, `zstd`.

`.tar.gz` is both: a tar archive compressed with gzip. `zip` (and `7z`) do both jobs in one tool.

## 1. tar

```shell
tar -cvf archive.tar dir/               # create
tar -tvf archive.tar                    # list contents (do this before extracting unknown archives)
tar -xvf archive.tar                    # extract into the current directory
tar -xvf archive.tar -C /tmp/out        # extract into another directory (must exist)
tar -xvf archive.tar dir/file.txt       # extract one file
tar -cvf archive.tar --exclude='*.o' --exclude='.git' dir/
tar -xvf archive.tar --strip-components=1    # drop the top-level directory from every path
```

| Option | Meaning |
| --- | --- |
| `-c` / `-x` / `-t` | Create / extract / list |
| `-f FILE` | Archive file name. Keep it **last** in a bundle: `-cvf a.tar`, not `-cfv a.tar` (that names the archive `v`) |
| `-v` | Verbose: print each file |
| `-C DIR` | Change to `DIR` first |
| `-p` | Keep permissions on extract (the default when running as root) |
| `-z` / `-j` / `-J` / `--zstd` | Compress with gzip / bzip2 / xz / zstd |
| `-a` | Choose the compressor from the archive's extension (GNU tar) |

GNU tar **detects the compression on extract**, so `tar -xf file.tar.gz`, `file.tar.xz` and `file.tar.zst` all work without `-z`/`-J`/`--zstd`.
When creating, `-a` does the same from the name:

```shell
tar -caf backup.tar.zst dir/            # zstd, chosen from the .zst extension
tar -xf backup.tar.zst                  # no compression flag needed
```

## 2. Compressors

All of these compress a **single** file and, by default, **replace** it with the compressed one (`file` → `file.gz`).

```shell
gzip file.txt              # -> file.txt.gz, file.txt is removed
gzip -k file.txt           # keep the original
gzip -d file.txt.gz        # decompress (= gunzip)
gzip -9 file.txt           # best compression (-1 fastest, default -6)
zcat file.txt.gz | less    # read without decompressing to disk (also: zless, zgrep)

xz -T0 file.img            # -> file.img.xz, using all CPU cores
xz -dc file.img.xz > file.img      # -c: write to stdout, keep the input

zstd file.img              # -> file.img.zst, keeps the original by default
zstd -T0 -19 file.img      # all cores, high compression
zstd -d file.img.zst       # decompress (= unzstd)
```

| Tool | Extension | Speed | Ratio | Typical use |
| --- | --- | --- | --- | --- |
| `gzip` | `.gz` | Fast | Fair | Everywhere: logs, web, `.tar.gz` sources |
| `bzip2` | `.bz2` | Slow | Good | Older source archives; mostly replaced by xz |
| `xz` | `.xz` | Slow to compress, medium to decompress | Best | Distribution packages and release tarballs, OS images (`.img.xz`) |
| `zstd` | `.zst` | Very fast, with many levels | Good to very good | Modern default: backups, package formats (e.g. Arch, Fedora RPMs), kernels |

For multi-core gzip, use `pigz` (same format and options). `xz` and `zstd` use several threads with `-T0`.

## 3. zip and unzip

```shell
zip -r archive.zip dir/              # -r: include subdirectories
zip -r archive.zip dir/ -x '*.o'     # exclude files
unzip -l archive.zip                 # list contents
unzip archive.zip -d out/            # extract into out/
unzip -o archive.zip                 # overwrite without asking
```

+ zip compresses **each file separately**, so one file can be extracted quickly without reading the whole archive.
  `.tar.gz` compresses the whole stream, which gives a better ratio but no random access.
+ zip doesn't keep Unix ownership and can lose other metadata. Use tar for Linux backups.
+ Windows and macOS open `.zip` natively, which makes it the best format for sharing with non-Linux users. (Windows 10+ also has `tar`.)
+ APK, AAR and JAR files are zip archives: `unzip -l app.apk` lists their contents.

## 4. Cheat sheet

| Format | Create | Extract | List |
| --- | --- | --- | --- |
| `.tar` | `tar -cvf a.tar dir/` | `tar -xvf a.tar` | `tar -tvf a.tar` |
| `.tar.gz` / `.tgz` | `tar -czvf a.tar.gz dir/` | `tar -xvf a.tar.gz` | `tar -tvf a.tar.gz` |
| `.tar.bz2` | `tar -cjvf a.tar.bz2 dir/` | `tar -xvf a.tar.bz2` | `tar -tvf a.tar.bz2` |
| `.tar.xz` | `tar -cJvf a.tar.xz dir/` | `tar -xvf a.tar.xz` | `tar -tvf a.tar.xz` |
| `.tar.zst` | `tar --zstd -cvf a.tar.zst dir/` | `tar -xvf a.tar.zst` | `tar -tvf a.tar.zst` |
| `.gz` (one file) | `gzip -k file` | `gzip -dk file.gz` | `gzip -l file.gz` |
| `.zip` | `zip -r a.zip dir/` | `unzip a.zip` | `unzip -l a.zip` |

## 5. Comments

+ **Pick by purpose.** `.tar.gz` when it must open anywhere, `.tar.zst` for your own backups (fast, good ratio), `.tar.xz` when size matters most and it's compressed once and downloaded many times, `.zip` for Windows users.
+ **List before you extract** an archive from someone else (`tar -tvf`, `unzip -l`). Some archives have no top-level directory and spill hundreds of files into the current directory. GNU tar removes a leading `/` and leading `../` from member names by default, so it can't write outside the target directory; other extractors may not be as careful.
+ **Board images: stream, don't unpack.** A Raspberry Pi or Orange Pi `.img.xz` can go straight to the card without a temporary file:
  `xz -dc image.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync`. Double-check `/dev/sdX` with `lsblk` first.
+ **Over the network, compress in a pipe:** `tar -czf - dir/ | ssh host 'tar -xzf - -C /dest'`.
  For repeated copies, `rsync` is better: it sends only the changes ([rsync_cmds.md](rsync_cmds.md)).
+ **Compression doesn't help already-compressed data** (JPEG, MP4, `.apk`, `.zip`). Just `tar` it, or use a fast level.

## Related notes

+ [rsync_cmds.md](rsync_cmds.md): copying and syncing directories
+ [bootableUsbDrive.md](bootableUsbDrive.md): writing images to USB drives and SD cards
+ [../shellScript/bash_recipes.md](../shellScript/bash_recipes.md): loops over files (e.g. gzip every log)
+ [../Android/jar_aar_intro.md](../Android/jar_aar_intro.md): JAR and AAR, which are zip files

## Reference

+ [GNU tar manual](https://www.gnu.org/software/tar/manual/)
+ [GNU gzip manual](https://www.gnu.org/software/gzip/manual/)
+ [XZ Utils](https://tukaani.org/xz/)
+ [Zstandard](https://facebook.github.io/zstd/)
