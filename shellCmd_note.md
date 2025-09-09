# linux command note

## man - an interface to the system reference manuals

`man df`

## disk

### du - estimate file space usage

`du -h`

### df - report file system space usage

`df -h`

### fdisk - manipulate disk partition table

### mke2fs - create an ext2/ext3/ext4 file system

## ps and top

`ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head`  
`ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head`  
`top -b -o +%MEM | head -n 15`  
`top` and then press Shift + M to sort by memory

## memory usage

`top -h`  
`free -h`

## text file handle

`head filename`  
`tail filename`  
`cat filename | grep -i pattern`  
`cat filenmae | grep -i "pattern1\|pattern2"`  
`cat filename | sort | uniq`  
`cat filename | tr str1 str2`  
`cut -c20-80 filename`  
`column -t -s ',' filename`

### grep - print lines that match patterns

`grep [OPTION...] PATTERNS [FILE...]`

+ **OPTION**  
  + -e PATTERNS, --regexp=PATTERNS  
  + -f, Obtain patterns from FILE, one per line  
  + -i, Ignore case distinctions in patterns and input data  
  + -v, Invert the sense of matching, to select non-matching lines.

`cat filename | grep -A3 pattern`  
`cat filename | grep -B3 pattern`  
`cat filename | grep -C3 pattern`  

### cmp

`cmp file1 file2`

### diff

`diff -y file1 file2`

## Search command or file

### which - locate a command

It Locates executable commands within the directories specified in the user's PATH environment variable.

`which ls`

### whereis - locate the binary, source, and manual page files for a command

whereis: This command is specifically designed to locate the binary (executable), source files, and manual pages for a given command.  
It searches in standard locations where programs are typically installed and their associated files are stored.  
whereis is very fast because it only searches a limited set of predefined directories.

`whereis ls`

### locate

locate: This command searches a pre-built database of filenames, typically located at /var/lib/mlocate/mlocate.db (or similar).  
This database is updated periodically by the updatedb command.  
locate is extremely fast because it does not search the file system in real-time but rather queries an index.  
However, it may not find newly created or recently modified files until the database is updated.  

`locate filename`

### find - search for files in a directory hierarchy

find: This command performs a real-time, comprehensive search of the file system based on specified criteria.  
It can search by name, type, size, modification time, ownership, and more.  
find is powerful and flexible but can be slow, especially when searching large directories or entire file systems, as it directly traverses the directory structure.  

`find /path/to/search -name "filename.txt"`

### chmod - change file mode bits

`find . -type d -exec chmod 755 {} \;`  
`find . -type f -exec chmod 644 {} \;`

### date - print or set the system date and time

VARIABLE_NAME=$(date +FORMAT_STRING)

+ %Y: Year with century (e.g., 2025)
+ %m: Month as a decimal number (01-12)
+ %d: Day of the month (01-31)
+ %H: Hour (00-23)
+ %M: Minute (00-59)
+ %S: Second (00-59)
+ %F: Full date; equivalent to %Y-%m-%d
+ %T: Time; equivalent to %H:%M:%S

```bash
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
echo "Timestamp: $TIMESTAMP"

VAR1=$(date +"%F")
echo "$VAR1"

VAR2=$(date +"%T")
echo "$VAR2"
```

### lsmod - Show the status of modules in the Linux Kernel

### insmod - Simple program to insert a module into the Linux Kernel

### lsusb - list USB devices

## Network

### ifconfig - Display or configure network interface

### iwconfig - configure a wireless network interface

### ping - send ICMP ECHO_REQUEST to network hosts

### arp - Linux ARP kernel module

This  kernel protocol module implements the Address Resolution Protocol defined in RFC 826.  
`arp -n`

### netstat - Display networking information

`netstat -nltp`

+ r: Routing table  
+ a: All sockets (not just connected)  
+ l: Listening server sockets  
+ t: TCP sockets  
+ u: UDP sockets  
+ w: Raw sockets  
+ x: Unix sockets  
+ e: Extended info  
+ n: Don't resolve names  
+ W: Wide display  
+ p: Show PID/program name of sockets  

### ss - another utility to investigate sockets

ss is used to dump socket statistics. It allows showing information similar to netstat.  
It can display more TCP and state information than other tools.
