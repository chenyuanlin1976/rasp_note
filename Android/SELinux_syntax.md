# SELinux syntax

An SELinux .te (Type Enforcement) file is the core component of a policy module.  
It defines `domains` (types for processes), `types` (for files/objects), and the `access rules (permissions)`  
that dictate how processes interact with files, sockets, and other system resources.

Here is a comprehensive guide to the syntax, structure, and writing of a .te file.

## 1. Basic Structure of a .te File

A standard .te file follows a specific logical order:

1. **Module Header**: Declares the module name and version.
1. **Declarations**: Declares new types, attributes, and uses standard macros.
1. **Type Transitions**: Defines how files or processes get labeled when created or executed.
1. **Access Rules (allow)**: Grants specific permissions between types.
1. **Interface Calls**: Uses higher-level macros provided by the SELinux reference policy for standard behaviors.

## 2. Core Syntax Elements

### A. The Module Header

Every .te file must start with the policy_module macro:  
`policy_module(myapp, 1.0.0)`

### B. Type Declarations

You must declare every new **domain (process type)** or **file type** before you can use it in rules:

```ini
# Declare a process domain
type myapp_t;
domain_type(myapp_t)

# Declare an executable file type
type myapp_exec_t;
files_type(myapp_exec_t)

# Declare a log file type
type myapp_log_t;
logging_log_file(myapp_log_t)
```

### C. The allow Rule (Core Permission Syntax)

The fundamental syntax for granting permission is:  
`allow source_type target_type : class { permissions };`

+ **source_type (Subject)**: Usually the process domain (e.g., myapp_t).
+ **target_type (Object)**: The resource being accessed (e.g., myapp_log_t, etc_t).
+ **class**: The category of the resource (`file`, `dir`, `process`, `socket`, `fifo_file`, etc.).
+ **permissions**: Specific actions allowed within brackets {}.  
  like `read`, `write`, `open`, `getattr`, etc.

Example:

```ini
# Allow myapp_t to read and write its log files
allow myapp_t myapp_log_t:file { read write append open getattr };
```

## 3. Common Modifiers and Rules

### A. Type Transitions (Automatic Labeling)

When a process executes a binary,  
it usually transitions from one domain (e.g., unconfined_t or init_t) to its own service domain (myapp_t).

```ini
# Transition from init script to myapp domain upon executing myapp_exec_t
domain_auto_trans(init_t, myapp_exec_t, myapp_t)

# Ensure files created in the log directory automatically get the log type
file_type_auto_trans(myapp_t, myapp_log_t, myapp_log_t, file)
```

### B. Using Interface Macros

Instead of writing raw allow rules for system-wide paths  
(like reading system configuration or writing to /var/log),  
it is best practice to use SELinux Reference Policy interfaces (macros):

```ini
# Allows myapp_t to read standard system libraries and configuration
libs_use_ld_so(myapp_t)
libs_read_lib_files(myapp_t)
sysnet_dns_resolver_reader(myapp_t) # Allows reading /etc/resolv.conf
```

## 4. Complete Example: myapp.te

Here is a complete, working example of a .te file for a hypothetical daemon called myapp:  

**Tip**: SELinux provides shorthand permission macros (like `r_file_perms`, `rw_file_perms`, `manage_file_perms`)  
to save you from typing out individual permissions like `read`, `write`, `open`, `getattr`, etc., every time.

```ini
policy_module(myapp, 1.0.0)

########################################
# Declarations
#

# Process Domain
type myapp_t;
domain_type(myapp_t)
init_daemon_domain(myapp_t)

# Executable Type
type myapp_exec_t;
files_type(myapp_exec_t)

# Configuration File Type
type myapp_conf_t;
files_config_file(myapp_conf_t)

# Log File Type
type myapp_log_t;
logging_log_file(myapp_log_t)

# PID File Type
type myapp_var_run_t;
files_pid_file(myapp_var_run_t)


########################################
# Policy Rules
#

# 1. Allow daemon execution and transition
domain_auto_trans(init_t, myapp_exec_t, myapp_t)

allow myapp_t myapp_exec_t:file { rx_file_perms };

# 2. Configuration access (Read-only)
allow myapp_t myapp_conf_t:dir { search_dir_perms };
allow myapp_t myapp_conf_t:file { r_file_perms };

# 3. Log access (Write/Append)
allow myapp_t myapp_log_t:dir { manage_dir_perms };
allow myapp_t myapp_log_t:file { manage_file_perms };

# 4. PID file access (Create/Write lock files in /var/run)
allow myapp_t myapp_var_run_t:dir { manage_dir_perms };
allow myapp_t myapp_var_run_t:file { manage_file_perms };

# 5. General system permissions via interfaces
logging_send_syslog_msg(myapp_t)
```

## 5. Compiling and Loading a .te File

Once your .te file is written, you typically pair it with a .fc (**File Contexts**) file  
and compile it using make or standard SELinux tools:

`make -f /usr/share/selinux/devel/Makefile myapp.pp`

1. Compile module: `make -f /usr/share/selinux/devel/Makefile myapp.pp`
1. Install module: `semodule -i myapp.pp`
1. Apply file contexts: `restorecon -R -v /path/to/myapp`
