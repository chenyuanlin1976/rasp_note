# the explanation of Domain Transition

## What is a Domain Transition

A Domain Transition is a core security mechanism in SELinux  
where a running process switches from one security domain to an entirely different security domain during execution.

Think of it like an employee holding a standard visitor badge (the parent process's domain)  
who enters a specific secure server room that requires a high-level executive keycard (a dedicated, restricted domain).

## 1. Why Do We Need Domain Transitions? (Core Purpose)

In traditional Linux, permissions are tied to User IDs (UIDs) -  
for example, everything run by root has full, unrestricted power.  
SELinux breaks this limitation to enforce **the Principle of Least Privilege**.

### Without a domain transition

+ If you run a program as root, that program inherits full root privileges.
+ If that program (like a web server) has a security vulnerability and gets hacked, the attacker gains control over the entire system.

### With a domain transition

+ When systemd or an init script starts a specific service (like Nginx or MySQL),  
  the process immediately breaks away from the parent process's domain (leaving behind broad permissions like init_t).
+ It enters a dedicated, highly restricted sandbox domain (such as httpd_t or mysqld_t).
+ The Benefit: Even if the application is compromised, the attacker is trapped inside that narrow sandbox  
  and cannot freely read sensitive system files (like /etc/shadow or other users' data).

## 2. How Does a Domain Transition Work? (The Three Elements)

For a domain transition to successfully happen, the SELinux policy must explicitly define three things:

+ **Source Domain**: The domain of the **parent process** launching the program (e.g., init_t).
+ **Executable Type**: The SELinux **label** assigned to the **binary file** on disk (e.g., myapp_exec_t).
+ **Target Domain**: The new, specialized domain the process should enter upon execution (e.g., myapp_t).

In a .te file, this is usually declared using a macro:  
`domain_auto_trans(init_t, myapp_exec_t, myapp_t)`

This rule tells SELinux:  
"When a process in the init_t domain executes a file labeled with myapp_exec_t, automatically transition that process's domain to myapp_t."

## 3. What Happens If a Domain Transition Fails or Doesn't Exist?

+ Stays in Place: The process remains trapped in the parent process's domain (as discussed previously).
+ Incorrect Permissions: If it was launched by a user shell or init_t, it might either have dangerously broad permissions or fail to run properly  
  because it lacks the custom allow rules required for its specialized tasks (resulting in an **AVC Denial**).
