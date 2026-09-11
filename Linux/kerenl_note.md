# Linux kerenl

## Kernel build

Building a Linux kernel involves using the **Kconfig system** to select features,  
**which generates a configuration file** `.config`, followed by the Kbuild system to compile the source code based on that file.  
The process typically starts in the root of the kernel source tree.  

### Configure the Kernel (Kconfig)

The Kconfig system uses files named `Kconfig` located throughout the source tree to define available options and their dependencies.  
You interact with this system using one of the `make *config` commands to create or update your `.config` file.  

+ `make menuconfig`: The most popular configuration methods.  
  It will read the Kconfig file to show the menu.  
+ `makefile`: it defines which file be compiled.  
  + `obj-y += xxx.o`: directly compile this file to the kernel  
  + `obj-m +=xxx.o`: compile the file as a moudle.  
  + `obj-$(CONFIG_FOO) += foo.o`: conditionaly compile. If `CONFIG_FOO=y`, this file will be compiled.  

### Kconfig syntax

### check module

+ `lsmod | grep module_name`
+ The `/sys/module` directory in Linux is a sysfs virtual filesystem interface that displays information about **currently loaded** kernel modules.
+ The `/lib/modules` folder (sometimes a symbolic link to `/usr/lib/modules`) is a critical directory that stores all the Linux Kernel modules.

## Linux socket

Linux socket is an endpoint for network or inter-process communication, treated as **a file descriptor**.  
Users generally agree that sockets function as handles allowing programs to perform read and write operations on connections.  
Key system calls include `socket()`, `bind()`, and `listen()`.

### Core Concepts

+ File Descriptor: Linux treats sockets like regular files, using standard `read`/`write` calls.
+ Address Families: `AF_INET` for IPv4, `AF_INET6` for IPv6, and `AF_UNIX`, `AF_LOCAL` for local communication.
+ Communication Types: `SOCK_STREAM` for TCP (reliable stream) and `SOCK_DGRAM` for UDP (datagram packet).

## Network Ports (TCP/UDP Ports)

In the context of networking and socket programming (which we explored with Modbus TCP),  
a network port is a logical endpoint identified by a 16-bit integer (ranging from 0 to 65535)  
used by the operating system to direct incoming and outgoing network traffic to the correct application or service.

+ How it works: An IP address points to a specific machine on a network,  
  but a port number points to a specific program running on that machine.  
  For example, if your Linux server runs a web server and a Modbus server simultaneously,  
  incoming packets for the web server go to Port 80, while Modbus traffic goes to Port 502.

+ Port Ranges:
  + Well-Known Ports (0 – 1023): Reserved for system-level or critical services  
    (e.g., Port 80 for HTTP, Port 443 for HTTPS, Port 502 for Modbus TCP).  
    On Linux, binding to these ports requires elevated root/superuser privileges.
  + Registered Ports (1024 – 49151): Assigned to specific applications by user request or software vendors.
  + Dynamic / Ephemeral Ports (49152 – 65535): Used temporarily by client applications when establishing outbound connections.
