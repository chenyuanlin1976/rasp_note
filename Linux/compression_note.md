# compression

Here is a breakdown of the most common compression and archiving commands in Linux (`tar, gzip, zip`, etc.),  
explained clearly with examples.

## tar (Tape Archive) - Archiving, not compressing by default

The tar command combines multiple files and directories into a single archive file (often called a "**tarball**"),  
preserving file permissions and directory structures.  
By itself, tar does **NOT** compress data, but it can call compression tools like `gzip` on the fly.

+ Create a .tar archive: `tar -cvf archive.tar folder_or_file/`
  + -c: Create an archive
  + -v: Verbose (show files being processed)
  + -f: Specify the filename of the archive

+ Extract a .tar archive: `tar -xvf archive.tar`
  + -x: Extract the archive

## gzip and gunzip - Fast compression

gzip is one of the most common compression tools in Linux.  
**It compresses a single file at a time** and replaces the original file with a `.gz` extension.

+ Compress a file: `gzip filename.txt` (creates filename.txt.gz)
+ Decompress a file: `gunzip filename.txt.gz` (or `gzip -d filename.txt.gz`)
+ Combining tar and gzip (.tar.gz or .tgz):  
  Because tar archives and gzip compresses, Linux users traditionally combine them using the -z flag:
  + Compress: `tar -czvf archive.tar.gz folder/`
  + Decompress: `tar -xzvf archive.tar.gz`

## zip and unzip - For Windows compatibility

Unlike gzip, the zip utility compresses multiple files/folders into a .zip archive,  
which is widely compatible with Windows systems.

+ Compress files/folders: `zip -r archive.zip folder/`
  + -r: Recursive (includes files inside subdirectories)
+ Decompress a .zip file: `unzip archive.zip`

## Modern Alternatives (bzip2, xz)

For higher compression ratios (making files smaller at the cost of processing speed), Linux offers other tools:

+ bzip2 / bunzip2 (creates .bz2):
  + Compress with tar: `tar -cjvf archive.tar.bz2 folder/`
  + Decompress with tar: `tar -xjvf archive.tar.bz2`
+ xz / unxz (creates .xz - extremely high compression):
  + Compress with tar: `tar -cJvf archive.tar.xz folder/`
  + Decompress with tar: `tar -xJvf archive.tar.xz`

## Quick Reference Cheat Sheet

| Format        | Extension      | Compress (Create: `c`)           | Decompress (Extract: `x`) |
| ------------- | -------------- | -------------------------------- | ------------------------- |
| Gzip Tarball  | .tar.gz/ .tgz  | `tar -czvf file.tar.gz folder/`  | `tar -xzvf file.tar.gz`   |
| Bzip2 Tarball | .tar.bz2       | `tar -cjvf file.tar.bz2 folder/` | `tar -xjvf file.tar.bz2`  |
| XZ Tarball    | .tar.xz        | `tar -cJvf file.tar.xz folder/`  | `tar -xJvf file.tar.xz`   |
| Zip           | .zip           | `zip -r file.zip folder/`        | `unzip file.zip`          |
