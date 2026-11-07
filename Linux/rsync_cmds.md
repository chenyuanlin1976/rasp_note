# rsync: copy and sync directories

`rsync` copies files locally or over SSH. When a file already exists at the destination, it skips it if the size and modification time match,
and over a network it sends only the changed parts of changed files (the **delta-transfer algorithm**).
So repeated syncs of a large directory are fast. Examples were checked against rsync 3.2.7.

## 1. Syntax and the trailing slash

```shell
rsync [options] SOURCE... DEST
```

The trailing `/` on the **source** decides what is copied:

| Command | Result |
| --- | --- |
| `rsync -a dir/ backup/` | The **contents** of `dir` go into `backup/` (`backup/file1`, ...) |
| `rsync -a dir backup/` | The directory itself: `backup/dir/file1`, ... |

A trailing `/` on the destination makes no difference.

## 2. Common options

| Option | Meaning |
| --- | --- |
| `-a` | Archive mode = `-rlptgoD`: recursive, symlinks as symlinks, permissions, times, group, owner (owner only as root), devices/special files |
| `-v` | List the transferred files |
| `-h` | Human-readable sizes |
| `-n`, `--dry-run` | Show what would happen, change nothing |
| `-u` | Skip files that are **newer** at the destination |
| `--delete` | Delete files at the destination that no longer exist in the source (a mirror) |
| `-z` | Compress during transfer: only useful over a slow network, not for local copies |
| `-P` | `--partial --progress`: keep partly transferred files (resume) and show progress |
| `--info=progress2` | One overall progress line instead of one per file |
| `-c` | Compare files by checksum instead of size + time (slow: reads every file) |
| `-H`, `-A`, `-X` | Also preserve hard links, ACLs, extended attributes (not included in `-a`) |
| `--exclude=PATTERN` | Skip matching files, e.g. `--exclude='.git/' --exclude='*.o'` |
| `--bwlimit=RATE` | Limit bandwidth; a plain number is KiB/s (`1024` = 1 MiB/s), suffixes like `5m` also work |

## 3. Use cases

```shell
# Local backup to an external drive (no -z: compression only costs CPU locally)
rsync -avh /home/user/documents/ /media/user/backup/documents/

# Mirror: also delete what was removed from the source. ALWAYS dry-run first
rsync -avhn --delete /source/ /destination/
rsync -avh  --delete /source/ /destination/

# To a remote host over SSH (SSH is the default transport; -e only for extra options)
rsync -avzP /local/path/ user@remote_host:/remote/path/
rsync -avzP -e "ssh -p 2222" /local/path/ user@remote_host:/remote/path/

# From a remote host, with a bandwidth limit
rsync -avzP --bwlimit=1024 user@remote_host:/remote/path/ /local/path/
```

Both ends need `rsync` installed. Key-based login avoids typing the password (see [ssh_login.md](ssh_login.md)).

`--delete` with a wrong path deletes the wrong files. Common mistakes are swapping source and destination,
or dropping the trailing `/` on the source so that everything is compared one level off.

## 4. Backing up to a FAT/exFAT USB drive

USB sticks are often FAT32 or exFAT (mounted as `/media/<user>/<LABEL or UUID>`, such as `/media/pi/D0E8-6E99`).
These filesystems have no Unix owner or permissions and store times with 2-second resolution, so `-a` causes problems:

+ errors like `chown ... Operation not permitted` / `failed to set permissions`
+ every file looks changed on each run, so everything is copied again

Use `-rt` (recursive + times) instead of `-a`, and allow a time difference of 1 s:

```shell
rsync -rtvh --modify-window=1 --delete "/home/pi/StudyData/" "/media/pi/D0E8-6E99/StudyData/"
```

On ext4 or NTFS (`ntfs-3g`/`ntfs3`) drives, `-a` works. Check the filesystem with `df -T /media/pi/<drive>` or `lsblk -f`.

## 5. My backup commands

Sync between the Raspberry Pi and USB drives. `-u` keeps a file that is newer on the destination;
`--delete` removes files that were deleted in the source. Run with `-n` first when unsure.

```shell
# Drive -> Pi
rsync -avu --delete "/media/pi/TRANSCEND/StudyData/"        "/home/pi/StudyData/"
rsync -avu --delete "/media/pi/TRANSCEND/ProgramLearnning/" "/home/pi/ProgramLearnning/"
rsync -avu --delete "/media/pi/usb_64G/StudyData/"          "/home/pi/StudyData/"
rsync -avu --delete "/media/pi/usb_64G/ProgramLearnning/"   "/home/pi/ProgramLearnning/"

# Pi -> drive
rsync -avu --delete "/home/pi/rasp_note/" "/media/pi/TRANSCEND/rasp_note/"
rsync -avu --delete "/home/pi/rasp_note/" "/media/pi/usb_64G/rasp_note/"
rsync -avu --delete "/home/pi/StudyData/" "/media/pi/My Passport/StudyData/"
rsync -avu --delete "/home/pi/rasp_note/" "/media/pi/My Passport/rasp_note/"

# Pi -> FAT/exFAT drive (section 4)
rsync -rtvu --modify-window=1 --delete "/home/pi/StudyData/"        "/media/pi/D0E8-6E99/StudyData/"
rsync -rtvu --modify-window=1 --delete "/home/pi/ProgramLearnning/" "/media/pi/D0E8-6E99/ProgramLearnning/"
rsync -rtvu --modify-window=1 --delete "/home/pi/rasp_note/"        "/media/pi/D0E8-6E99/rasp_note/"
```

Quote paths that contain spaces (`"My Passport"`).

## 6. Verify a copy

```shell
diff -qr "/media/pi/TRANSCEND/StudyData/" "/home/pi/StudyData/"   # list files that differ or exist on one side only
rsync -avnc --delete SRC/ DEST/                                   # dry run by checksum: lists anything that would still change
```

## Related notes

+ [archive_compression.md](archive_compression.md): `tar`/`zip` archives, the other way to copy many files
+ [ssh_login.md](ssh_login.md): SSH keys for passwordless remote syncs

## Reference

+ [rsync(1) manual](https://download.samba.org/pub/rsync/rsync.1)
+ [rsync project](https://rsync.samba.org/)
