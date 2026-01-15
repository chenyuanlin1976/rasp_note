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
