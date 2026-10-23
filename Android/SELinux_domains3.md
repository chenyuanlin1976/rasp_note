# domain of SELinux

`httpd_t` and `mysqld_t` are other specific security domains (process types) used in SELinux,  
but they belong to **standard Linux server distributions** (such as RHEL, CentOS, Fedora, Debian, or Ubuntu) rather than Android.

They are classic examples of how SELinux isolates traditional server applications:

## 1. What are they?

### `httpd_t` (The Apache / Web Server Domain):

+ What it is: The security domain assigned to the Apache HTTP Server  
  (and sometimes other web services like Nginx in certain policies) when it runs on a Linux server.
+ What it does: It ensures that if someone hacks your website (e.g., via a PHP vulnerability),  
  the attacker can only do what the web server is explicitly allowed to do  
  (like read files inside /var/www/html/ and write to specific log folders).  
  It blocks the hacker from stealing user passwords from /etc/shadow or modifying system binaries.

### mysqld_t (The MySQL / MariaDB Database Domain):

+ What it is: The security domain assigned to the MySQL or MariaDB database daemon process.
+ What it does: It isolates the database engine.  
  It allows mysqld_t to read and write database files located in /var/lib/mysql/,  
  but blocks it from accessing general user home directories, web roots, or unrelated system configuration files.

## 2. How do they compare to Android domains?

Just like Android 14 separates apps into `untrusted_app` and system services into `system_server`,  
traditional Linux server distributions use specialized domains to isolate every common server daemon:

| Server Application   | SELinux Domain (_t) | Typical Executable Path       | Primary Purpose                                              |
| -------------------- | ------------------- | ----------------------------- | ------------------------------------------------------------ |
| Apache Web           | `Serverhttpd_t`     | `/usr/sbin/httpd`             | Serves web pages safely with restricted file/network access. |
| MySQL/ MariaDB       | `mysqld_t`          | `/usr/sbin/mysqld`            | Manages databases while locked away from the rest of the OS. |
| SSH Server (OpenSSH) | `sshd_t`            | `/usr/sbin/sshd`              | Handles secure remote shell logins.                          |
| Postfix Mail Server  | `postfix_master_t`  | `/usr/libexec/postfix/master` | Manages outgoing and incoming emails.                        |
