# SELinux security domains

In SELinux, security domains (process types ending in _t) span far beyond web servers and databases.  
The SELinux Reference Policy defines hundreds of specialized domains to isolate nearly every critical component of a Linux operating system  
(such as RHEL, Fedora, CentOS, Rocky Linux, etc.).

Other common and specific security domains categorized by their system roles include:

## 1. System Management & Initialization

+ `init_t`: The domain for PID 1 (systemd or init). It handles system booting and spawns other services.
+ `initrc_t`: The domain traditionally used for legacy init scripts (/etc/init.d/)  
  and general service management tasks executed during startup.
+ `kernel_t`: The foundational domain assigned to core kernel threads and processes before policies are fully loaded.
+ `udev_t`: Manages device nodes and hardware hot-plugging events in /dev/.

## 2. User & Administrative Access

+ `unconfined_t`: A special, largely unconfined domain.  
  Regular or administrative users logged into a standard desktop/server often operate under variants like unconfined_t or staff_t,  
  meaning SELinux does not restrict their everyday actions as tightly.
+ `secadm_t`: A highly privileged security administrator domain used in strict environments  
  to manage SELinux policies, load modules, and alter security settings.
+ `sysadm_t`: A traditional system administrator domain designed for deep system maintenance tasks, isolated from regular user spaces.
+ `shell_t`: Assigned to standard command-line interfaces (bash, sh, zsh) when invoked in confined configurations.

## 3. Remote Management & Security Daemons

+ `sshd_t`: The OpenSSH server daemon. It accepts remote connections and spawns user shells, handling cryptographic authentication.
+ `fail2ban_t`: Monitors log files for malicious login attempts and dynamically updates firewall rules to block IPs.
+ `firewalld_t`: Manages runtime network packet filtering and firewall configurations (nftables / iptables).
+ `policykit_t`: Handles authorization decisions and privilege escalation requests for desktop and system actions (polkitd).

## 4. Logging & Monitoring

+ `rsyslogd_t`: Collects, processes, and writes system log messages to disk (/var/log/messages, etc.).
+ `auditd_t`: The core daemon managing the Linux Audit Subsystem, recording security-relevant events and SELinux **AVC denials**.
+ `logrotate_t`: Periodically compresses, archives, and cleans up old system log files.

## 5. Virtualization & Containers

+ `virtd_t`: The libvirt daemon responsible for managing virtual machines (KVM, QEMU).
+ `svirt_orphic_t`/ `svirt_t`: Dynamic isolation domains assigned to individual virtual machine instances  
  or container runtimes to prevent guests from breaking out into the host OS.
+ `container_t`: The generic domain often assigned to containerized workloads  
  (like Docker or Podman containers) to sandbox their behavior.
