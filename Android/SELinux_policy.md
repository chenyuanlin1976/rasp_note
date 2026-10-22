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
+ Deny-by-Default:  
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

+ **source_type** (Subject): The SELinux type (domain) of the process trying to perform the action (e.g., my_daemon_t).
+ **target_type** (Object): The SELinux type of the resource being accessed (e.g., my_daemon_data_t).
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
