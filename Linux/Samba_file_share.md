# Samba: sharing files with Windows, macOS, and Linux

Samba is a free implementation of the **SMB/CIFS** protocol for Linux and Unix.
A Linux machine (for example a Raspberry Pi) can serve folders and printers to Windows, macOS, and Linux clients,
and Linux can access Windows shares.

## 1. What Samba does

+ **File and print server**: shares folders and printers over SMB (TCP port **445**).
+ **Domain controller**: Samba 4 can be an **Active Directory** domain controller (users, groups, Kerberos, group policy).
  The old NT4-style PDC mode still exists but is legacy.
+ **Domain member**: a Linux machine can join an AD domain, with `winbindd` mapping domain users to Linux users.
+ **NetBIOS name service**: NetBIOS name resolution and WINS (UDP 137/138, TCP 139), for older clients.

| Daemon / service | Purpose |
| --- | --- |
| `smbd` | File and printer sharing, authentication, locking |
| `nmbd` | NetBIOS names and browsing. Optional: modern clients connect by IP or DNS/mDNS name |
| `winbindd` | Domain user and group lookups (domain members only) |
| `samba` (`samba-ad-dc`) | Active Directory domain controller (replaces the 3 above on a DC) |

All settings are in **`/etc/samba/smb.conf`**: a `[global]` section, then one `[sharename]` section per share.

**Network discovery**: Windows 10/11 no longer find hosts through NetBIOS browsing (SMB1 is disabled).
To make the Linux host appear under "Network" in Windows Explorer, install `wsdd` (or `wsdd2`). It isn't needed to connect by address.

## 2. Install and check

```shell
sudo apt update
sudo apt install samba
systemctl status smbd                   # running and enabled at boot?
testparm                                # check smb.conf syntax and show the effective settings
sudo ufw allow samba                    # if ufw is enabled (opens 137,138/udp and 139,445/tcp)
```

## 3. A password-protected share (recommended)

Samba has **its own password database**. A Linux user must also be added to Samba before it can log in:

```shell
sudo smbpasswd -a pi                    # set the Samba password for the existing Linux user "pi"
sudo pdbedit -L                         # list Samba users
```

```ini
# /etc/samba/smb.conf: append at the end
[StudyData]
   path = /home/pi/StudyData
   browseable = yes
   read only = no
   valid users = pi
   create mask = 0644
   directory mask = 0755
```

| Parameter | Meaning |
| --- | --- |
| `[StudyData]` | Share name that clients see |
| `path` | Directory on the server. Linux permissions still apply on top of the Samba settings |
| `browseable` | Whether the share appears in the share list |
| `read only = no` | Allow writes (same as `writable = yes`) |
| `valid users` | Only these users (or `@group`) may connect |
| `create mask`, `directory mask` | Maximum permissions for new files and directories. Files normally don't need execute bits |

```shell
testparm
sudo systemctl restart smbd
```

## 4. A guest share (no password)

Use this only on a trusted home network. Put the folder **outside `/home`**: on recent Ubuntu, home directories are `0750`,
so the guest account (`nobody`) can't even enter them.

```shell
sudo mkdir -p /srv/samba/public
sudo chown nobody:nogroup /srv/samba/public
sudo chmod 2775 /srv/samba/public
```

```ini
[global]
   map to guest = bad user              # unknown users become guest (Debian/Ubuntu default)

[Public]
   path = /srv/samba/public
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody                  # every guest write is done as "nobody"
   create mask = 0664
   directory mask = 2775
```

Recent Windows versions block guest access by default (insecure guest logons). A password-protected share avoids that.

## 5. Connect from a client

| Client | Address |
| --- | --- |
| Windows Explorer | `\\192.168.1.10\StudyData` (or `\\hostname\StudyData`) |
| macOS Finder (Go > Connect to Server) | `smb://192.168.1.10/StudyData` |
| Linux file manager (GNOME Files, ...) | `smb://192.168.1.10/StudyData` |

From the Linux command line (`sudo apt install smbclient cifs-utils`):

```shell
smbclient -L //192.168.1.10 -U pi                       # list the shares on a server
smbclient //192.168.1.10/StudyData -U pi                # FTP-like shell: ls, get, put

sudo mkdir -p /mnt/study
sudo mount -t cifs //192.168.1.10/StudyData /mnt/study \
     -o username=pi,uid=$(id -u),gid=$(id -g)           # mount it as a local directory
sudo umount /mnt/study
```

For a permanent mount, add an `/etc/fstab` line with `credentials=/root/.smbcred` (a root-only file with `username=` and `password=`),
so the password isn't stored in `fstab` or in your shell history.

### 5.1 Download with `smbget`

`smbget` (package `smbclient`) is a `wget`-like downloader for SMB URLs:

```shell
smbget -U pi smb://192.168.1.10/StudyData/big.iso               # asks for the password
smbget -R -U pi smb://192.168.1.10/StudyData/docs               # a whole directory
smbget -r -U pi smb://192.168.1.10/StudyData/big.iso            # resume an interrupted download
```

| Option | Meaning |
| --- | --- |
| `-r`, `--resume` | Resume aborted or interrupted files |
| `-R`, `--recursive` | Download directories recursively |
| `-a`, `--guest` | Connect as guest |
| `-o`, `--outputfile FILE` | Local output file name |
| `-U user[%password]` | User name (a password after `%` is visible in `ps` and shell history) |

The options have changed between Samba versions; check `smbget --help` on your system.

## 6. Monitor connections

```shell
sudo smbstatus                          # connected users, client IPs, shares, locked files
sudo smbstatus -S                       # shares only
sudo smbstatus -L                       # locked/open files only
journalctl -u smbd                      # service log (also /var/log/samba/)
```

## Related notes

+ [ufw_cmds.md](ufw_cmds.md): opening the Samba ports
+ [rsync_cmds.md](rsync_cmds.md): syncing to a mounted share or a remote host

## Reference

+ [Samba documentation](https://www.samba.org/samba/docs/)
+ [smb.conf(5)](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html)
+ [Samba wiki: setting up Samba as a standalone server](https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Standalone_Server)
+ [Ubuntu Server: Samba file server](https://documentation.ubuntu.com/server/how-to/samba/file-server/)
