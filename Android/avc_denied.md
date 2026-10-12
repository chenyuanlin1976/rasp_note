# avc denied

An AVC (Access Vector Cache) denied message means that  
**SELinux** (Security-Enhanced Linux) has blocked a process from performing an action on a resource  
because the active security policy does not permit it.

**When a process tries to access a file, network port, or another process, SELinux checks its security context.**  
If the policy lacks a rule allowing that specific interaction, the kernel logs an AVC denial and blocks the request.

## Troubleshooting and Fixing an AVC Denial

### 1. Locate and Analyze the Denial

Find the specific denial in your logs by running `dmesg | grep avc` or checking `/var/log/audit/audit.log`.  
To understand why it was blocked in plain English, install and run:  
`sudo audit2why < /var/log/audit/audit.log`  

+ How to verify: You will see output detailing the source context, target context, the denied permission  
(e.g., read, write, execute), and a human-readable explanation of why policy blocked it.

### 2. 2.Determine the Correct Fix

Depending on the cause, choose one of two main approaches:

1. Incorrect File Context: If a file was moved or created with the wrong label,  
   fix it using restorecon (e.g., restorecon -Rv /path/to/file) or update its context with chcon.
2. Missing Policy Rule: If a legitimate application needs a permission missing from the policy,  
   generate a local policy module using audit2allow:  
   `sudo grep avc /var/log/audit/audit.log | audit2allow -M myfix`  
   `sudo semodule -i myfix.pp`  
   How to verify: Run `semodule -l | grep myfix` to confirm your custom policy module is loaded.

### 3.Test and Verify

Trigger the action that previously caused the failure again, then check your logs to ensure the error no longer appears.  
`dmesg | grep -i avc`  

+ How to verify: The command should return no new avc: denied entries related to your action.
