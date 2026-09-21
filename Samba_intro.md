# Samba intro

Samba is a free, open-source software suite that re-implements the Server Message Block (SMB) networking protocol  
for Linux and Unix-like operating systems.  
It allows seamless file and printer sharing between Linux computers and Microsoft Windows clients over a local network.

## Key Functions of Samba

+ File and Print Sharing: Acts as a bridge, allowing Windows users to access files stored on a Linux server and vice versa.
+ Domain Controller Capabilities: Can act as an Active Directory (AD) Domain Controller or an NT4-style Primary Domain Controller (PDC)  
  to manage users, groups, and network security.
+ Name Resolution: Includes support for Windows Internet Name Service (WINS) server functionality and NetBIOS-over-TCP/IP name resolution.
+ Authentication Integration: Can integrate seamlessly with Linux PAM (Pluggable Authentication Modules), LDAP,  
  and Kerberos for centralized user authentication.

## How Samba Works

Samba operates primarily through 2 background daemons:

+ smbd: Handles file and printer sharing services, authenticating users and managing file access permissions.
+ nmbd: Handles NetBIOS name resolution, allowing computers on the network to discover each other and browse shared resources.

The entire configuration is managed through a single primary configuration file, typically located at `/etc/samba/smb.conf`.

## Basic Configuration Example

A typical share definition inside `/etc/samba/smb.conf` looks like this:

```Ini, TOML
[SharedFolder]
   path = /home/username/shared
   browseable = yes
   read only = no
   valid users = username
```

+ [SharedFolder]: The name of the share as seen by network clients.
+ path: The absolute file path on the Linux system being shared.
+ browseable: Determines whether the share appears in the network neighborhood list.
+ read only: Controls whether users can write to the directory.
+ valid users: Restricts access to specific authorized usernames.

## Common Use Cases

+ Network Attached Storage (NAS): Powering home or enterprise NAS devices running Linux to serve files to Windows, macOS, and Linux workstations.
+ Cross-Platform Collaboration: Enabling mixed-OS office environments where designers on macOS/Windows and developers on Linux  
  need to collaborate on the same file repositories.
+ Centralized Active Directory: Managing corporate user credentials and group policies on a Linux-backed server infrastructure.

## Step-by-step guide

1. Install Samba: `sudo apt update;sudo apt install samba`
2. Verify that the Samba service is running and enabled to start at boot: `sudo systemctl status smbd`
3. Create a Directory to Share: `mkdir -p ~/samba_share`
4. Configure Samba: `sudo nano /etc/samba/smb.conf`; Scroll to the very bottom of the file and add your new share definition:

```Ini, TOML
[PublicShare]
   path = /home/your_username/samba_share
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0755
```

+ [PublicShare]: The name of the share visible to network clients.
+ path: The full path to the folder you created in Step 2 (replace your_username with your actual username).
+ guest ok = yes: Allows anyone on the local network to access the share without needing a password. (Set this to no if you want it secured).

5. Adjust File Permissions: `chmod -R 0755 ~/samba_share;sudo chown -R nobody:nogroup ~/samba_share`
6. Restart the Samba Service: `sudo systemctl restart smbd;sudo systemctl restart nmbd`
7. Access the Share from a Client:
   + From Linux: `smb://<Linux_IP_Address>/PublicShare`
   + From Windows: `\\<Linux_IP_Address>\PublicShare`
