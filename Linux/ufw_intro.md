# ufw (Uncomplicated Firewall)

UFW (Uncomplicated Firewall) is a user-friendly command-line interface  
designed to manage netfilter (iptables) firewall rules on Linux distributions like Ubuntu and Debian.  
It is built to simplify the process of setting up a network firewall without requiring deep knowledge of complex rule syntax.

## Installation & Basic Controls

If UFW is not installed on your system, you can easily install and manage it using your package manager:

+ Install UFW: `sudo apt install ufw`
+ Enable the firewall: `sudo ufw enable`  
  (Note: If you are on a remote SSH server, make sure to allow SSH first, otherwise you will lock yourself out).
+ Disable the firewall: `sudo ufw disable`
+ Check status & rules: `sudo ufw status verbose` or `sudo ufw status numbered`
+ Reload rules: `sudo ufw reload`
+ Reset to defaults: `sudo ufw reset`

## Default Policies

It is best practice to set baseline rules that block all incoming traffic while allowing all outgoing traffic:

+ `sudo ufw default deny incoming`
+ `sudo ufw default allow outgoing`

## Managing Port Rules

You can allow or block traffic by specifying port numbers or service names.

+ Allow a port: `sudo ufw allow 80`
+ Allow specific protocol: `sudo ufw allow 53/udp`
+ Allow port range: `sudo ufw allow 6000:6007/tcp`
+ Allow by service name: `sudo ufw allow ssh` or `sudo ufw allow http`
+ Deny a port: `sudo ufw deny 23`
+ Rate-limit a port (e.g., SSH protection): `sudo ufw limit ssh` (blocks an IP if it attempts 6+ connections in 30 seconds)

## Advanced & IP-Specific Rules

You can restrict rules to specific IP addresses or subnets.

+ Allow a specific IP: `sudo ufw allow from 192.168.1.100`
+ Allow an IP to a specific port: `sudo ufw allow from 192.168.1.100 to any port 3306`
+ Allow an entire subnet: `sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp`
+ Block a specific IP: `sudo ufw deny from 203.0.113.50`

## Deleting Rules

1. First, list all rules with their corresponding numbers: `sudo ufw status numbered`
2. Delete a rule using its index number: `sudo ufw delete 3`  
   (Alternatively, you can prefix delete before the exact rule configuration, such as sudo ufw delete allow 80)
