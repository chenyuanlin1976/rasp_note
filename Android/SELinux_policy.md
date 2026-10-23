# SELinux policy

**An SELinux policy is a set of rules** that governs Mandatory Access Control (MAC) on a Linux system.  
Unlike standard Linux permissions (Discretionary Access Control, or DAC, which rely on file ownership like `user/group/others`),  
an SELinux policy dictates precisely:  
**what actions a specific program or process can perform on system resources**, regardless of who is running it.

## Core Concepts of an SELinux Policy

+ Security Contexts (Labels):  
  Every process, file, network port, and device on the system is tagged with an **SELinux label** (e.g., `user:role:type:level`).  
  **The most important part of this label is the type**  
  (e.g., httpd_t for the Apache web server or bin_t for system binaries).
+ Access Vectors (Rules):  
  The policy consists of thousands of rules defining how types can interact.  
  For example: “Process type A (httpd_t) is allowed to read file type B (httpd_sys_content_t).”
+ **Deny-by-Default**:  
  If an interaction is not explicitly allowed by the policy,  
  it is automatically blocked—which is what triggers an **avc denied** log message.

## Common Policy Types

Depending on your operating system (such as RHEL, Fedora, or Android),  
you will typically encounter one of 2 primary policy styles:

+ **Targeted Policy**: The default on most enterprise Linux distributions.  
  It protects specific, vulnerable network-facing services (like web servers, databases, and SSH)  
  while leaving standard user sessions unconfined.
+ **Strict/Enforcing Policies**: Used in high-security environments where every process and user is strictly confined.  
  Android uses a heavily customized targeted/enforcing SELinux policy to sandbox apps and system services from one another.

## Basic Syntax Structure

An SELinux type enforcement (.te) file uses a specific grammar to define rules  
governing how subjects (processes) interact with objects (files, sockets, etc.).

The fundamental building block of a policy rule is the allow statement:
`allow source_type target_type : class { permissions };`

### Breaking Down the Components

+ **source_type** (Subject): The SELinux type (domain) of the **process** trying to perform the action (e.g., my_daemon_t).
+ **target_type** (Object): The SELinux type of the **resource** being accessed (e.g., my_daemon_data_t).
+ **class**: The category of the resource (e.g., `file`, `dir`, `socket`, `process`).
+ **permissions**: The specific actions allowed on that resource (e.g., `read`, `write`, `open`, `getattr`).

### Practical Example

Suppose you have a custom daemon (my_daemon_t) that needs to open, read, and get attributes of log files (my_daemon_log_t):

```ini
# 1. Declare the types (usually done in a .te or .fc file)
type my_daemon_t;
type my_daemon_log_t;

# 2. Grant permissions
allow my_daemon_t my_daemon_log_t:file { open read getattr };
```

### Using Macros (Interfaces)

In real-world SELinux policies (like those in Android or Fedora),  
writing raw allow rules for standard system interactions is discouraged.  
Instead, policies use interface macros provided by policy developers:

```ini
# Instead of writing raw allow rules for reading config files, use a macro:
files_read_etc_files(my_daemon_t)
```

## what happen if the rule is not defined

If a process (executable) is **not** listed in any .te file and has no custom policy module defining a domain for it,  
it will still run, but it operates under a crucial SELinux rule: **No domain transition occurs**.

Instead of entering a unique, isolated sandbox, the process inherits or stays within the parent process's domain.
The exact behavior depends entirely on how and where you launch the process:

### Scenario 1: You run it from a User Shell (CLI)

If you compile a custom script or binary (e.g., ./my_script)  
and run it in your terminal on a standard Linux distribution (like RHEL, Fedora, or CentOS):

+ The Domain: The process runs in your shell's domain (e.g., unconfined_t if you are an unconfined user, or staff_t).
+ What happens: Because it runs under your user/shell domain, it has the exact same permissions that your shell has.
+ Will it trigger AVC denials? **Generally no**, because unconfined or standard user domains are heavily permitted to read/write user files,  
  temporary directories, and run standard commands.  
  It will act almost as if SELinux isn't restricting that specific program.

### Scenario 2: You run it as a System Service (Daemon via systemd)

If you write a background daemon, place it in /usr/bin/ or /usr/sbin/,  
and start it via systemctl start myapp **without** a .te file:

+ The Domain: The process will execute inside init_t (or systemd_t depending on the init system implementation),  
  because systemd is the parent process spawning it and no policy rule tells SELinux to transition it to a new domain.
+ What happens:  
  + The daemon is not isolated. It shares the broad permissions granted to the init system.
  + However, if the daemon tries to access files with restrictive contexts  
    (like writing to a custom log directory /var/log/myapp/ that has a custom type like myapp_log_t which init_t doesn't have access to),  
    it will be blocked, resulting in an **AVC Denial** in /var/log/audit/audit.log.

### Why does this happen? (The Mechanics)

SELinux domain transitions are opt-in. For a process to leave its parent's domain and enter its own custom .te domain, two things must be true simultaneously:

1. File Context (.fc): The binary file on disk must be labeled with an executable type (e.g., myapp_exec_t).
1. Type Transition (.te): The policy must explicitly define a transition rule (like domain_auto_trans(init_t, myapp_exec_t, myapp_t)). 

If the .te file is missing, SELinux sees the file's type, sees that no rule tells it to change domains,  
and simply lets the process run with the current credentials and domain of whichever process launched it.
