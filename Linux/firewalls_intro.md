# Overview of Linux Firewalls

In Linux, firewalls are not a single standalone program,  
but rather *a combination of kernel-level packet filtering frameworks and user-space management tools*.  
The Linux kernel's core packet filtering architecture has evolved over the years,  
giving administrators powerful ways to control network traffic *entering, leaving, or passing through a system*.

## The Evolution of the Linux Firewall Framework

Understanding Linux firewalls requires looking at how the underlying kernel subsystems work:

+ **iptables**: The traditional standard for decades.  
  It interacts directly with the netfilter framework inside the Linux kernel to inspect, modify, drop, or accept network packets.  
  While extremely powerful, its rule syntax can become complex and difficult to read for large configurations.
+ **nftables**: The modern successor to iptables.  
  Introduced to address performance bottlenecks and syntax issues in iptables,  
  nftables provides a cleaner, more unified framework for IPv4, IPv6, ARP, and bridge traffic filtering.
+ **firewalld**: A higher-level management tool (commonly found on Red Hat, CentOS, and Fedora)  
  that dynamically manages nftables or iptables rules using the concept of zones (trust levels assigned to network interfaces).
+ **UFW** (Uncomplicated Firewall): A user-friendly front-end designed primarily for Ubuntu and Debian derivatives.  
  It wraps around `iptables` (or `nftables`) to simplify basic firewall management for everyday server administration.

## Key Concepts

Most Linux firewalls operate on a few foundational principles:

+ Chains/ Tables: Rules are organized into chains (like INPUT, OUTPUT, and FORWARD) that process packets at different stages of their lifecycle.
+ Default Policies: The baseline rule applied when no other specific rule matches a packet  
  (e.g., standard practice is to deny/drop all incoming traffic and allow all outgoing traffic).
+ Stateful Inspection: Modern Linux firewalls are stateful, meaning they track the state of a connection (NEW, ESTABLISHED, RELATED).  
  If your server initiates an outbound request, the firewall automatically remembers it and allows the legitimate response back in without needing an explicit inbound rule.

## Which Tool Should You Use?

+ **UFW**: Best for Ubuntu/Debian users, developers, and simple-to-intermediate server setups where ease of use is the priority.
+ firewalld: Best for Fedora, RHEL, and CentOS environments, especially those requiring dynamic network zoning  
  (e.g., switching between home, public, and work network profiles).
+ nftables / iptables: Best for advanced network engineers, custom routing configurations, or environments requiring granular, low-level packet manipulation.
