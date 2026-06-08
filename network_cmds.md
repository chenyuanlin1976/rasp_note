# network command list

+ `sudo pppoeconf`: an interactive, text-based terminal utility to automatically detect and configure P2P Protocol over Ethernet (PPPoE) DSL connections.
+ `sudo pon dsl-provider`: initiate a PPPoE (DSL) broadband dial-up connection using the background Point-to-Point Protocol Daemon (pppd).
+ `sudo poff`: to shut down an active Point-to-Point Protocol (PPP) network connection, such as dial-up or PPPoE links.
+ `plog`: a dedicated script used to display and monitor Point-to-Point Protocol (PPP) connection logs.
+ `ifconfig`: a legacy Linux utility used to view and adjust the configuration of network interfaces.
+ `iwconfig`: a dedicated Linux command-line tool used to display and configure wireless network interfaces.

## common commnads

+ Check IP Addresses & Network Interfaces:
  + Shows all active network interfaces, their link statuses (UP or DOWN), and assigned IPv4/IPv6 addresses: `ip addr`
  + Displays only the layer 2 hardware details (MAC addresses) and physical state of your adapters: `ip link`
  + Displays a clean, high-level summary of network connections managed by NetworkManager: `nmcli device status`
+ Verify Connectivity & Routing
  + Sends 4 packets to a public DNS server to verify basic external connectivity and look for packet loss: `ping -c 4 8.8.8.8`
    + Google DNS: `8.8.8.8 and 8.8.4.4`
    + CHT DNS: `168.95.1.1 and 168.95.192.1`
  + Shows your kernel routing table, which is critical for finding your default gateway (router IP): `ip route`
  + Traces the path packets take to a target host, helping identify which network router or hop is dropping your connection: `traceroute google.com`
  + Combines ping and traceroute into a real-time, interactive diagnostic interface: `mtr google.com`

## command: ifcofig

+ View active interfaces: `ifconfig`
+ View all interfaces (including down): `ifconfig -a`
+ View specific interface (e.g., eth0, ppp0): `ifconfig eth0`
+ Disable an interface: `sudo ifconfig eth0 down`
+ Enable an interface: `sudo ifconfig eth0 up`
+ Assign IP & Netmask: `sudo ifconfig eth0 192.168.1.10 netmask 255.255.255.0`
+ Change MTU size: `sudo ifconfig eth0 mtu 1500`
+ Change MAC address: `sudo ifconfig eth0 hw ether 00:1a:2b:3c:4d:5e`

## command (newer): ip command from the iproute2 package

+ View active interfaces: `ip addr show`
+ View all interfaces (including down): `ip addr show`
+ View specific interface (e.g., eth0): `ip addr show eth0`
+ Disable an interface: `sudo ip link set eth0 down`
+ Enable an interface: `sudo ip link set eth0 up`
+ Assign IP & Netmask: `sudo ip addr add 192.168.1.10/24 dev eth0`
+ Change MTU size: `sudo ip link set eth0 mtu 1500`
+ Change MAC address: `sudo ip link set eth0 address 00:1a:2b:3c:4d:5e`

## command arp

The `arp` command is used to view and manipulate the system's Address Resolution Protocol (ARP) cache.

+ View the full ARP table: `arp`
+ View the ARP table in BSD/alternate format: `arp -a`
+ Show numerical addresses only: `arp -n`
+ Filter by network interface: `arp -i eth0`
+ Delete an entry (Requires Root): `sudo arp -d 192.168.1.50`
+ Add a static entry (Requires Root): `sudo arp -s 192.168.1.50 00:11:22:33:44:55`

## command (newer): ip neigh

+ View Table: `ip neigh show`
+ Delete Entry: `sudo ip neigh del 192.168.1.1 dev eth0`
+ Add Static: `sudo ip neigh add 192.168.1.100 lladdr 00:11:22:33:44:55 dev eth0 nud permanent`
+ Flush Cache: `sudo ip neigh flush all`

## URI and URL

### URI: Uniform Resource Identifier

A URI is a **string** of characters that uniquely identifies a resource on the internet.  
It consists of several components, including the scheme, authority, path, query and fragment.  
Each part plays a role in identifying and interacting with online resources and assets.

### URL: Uniform Resource Locator

A URL is a specific type of URI that not only identifies a resource but also provides the means to locate it.  
It includes information such as the protocol (e.g., HTTP or HTTPS) and the domain name, which directs users to the resource's location on the web.  
These are often referred to as the parts of a url.

### URI vs URL — what exactly are the differences

The terms URI and URL are often confused and used interchangeably but they serve different purposes when it comes to website creation.  
While all URLs are URIs, not all URIs are URLs.  
A URI can be a name, a location or both.  
URLs specifically provide the means to access a resource by describing its primary access mechanism.

This can be a tricky comparison to understand so let's lay it out like this:

+ URI (Uniform Resource Identifier): A generic term for all types of names and addresses that refer to objects on the web.
+ URL (Uniform Resource Locator): A specific type of URI that provides a means to locate a resource by describing its primary access mechanism.

### URI examples

1. HTTPS URI: `https://www.example.com`
2. URN: `urn:isbn:0451450523` (Identifies a book by its ISBN)
3. Data URI: `data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==` (Encodes a string in base64)
4. Mailto URI: `mailto:info@example.com` (Used to initiate an email)
5. File URI: `file:///sdcard/Movies/StarWar.mp4` (Identifies a file on the local filesystem)

### URL examples

1. HTTP URL: `http://www.example.com`
2. HTTPS URL: `https://secure.example.com`
3. FTP URL: `ftp://ftp.example.com/resource.txt`
4. URL with Path and Query: `https://www.example.com/search?q=URL+syntax`
5. URL with Fragment: `https://www.example.com/articles#section2`

### What is a URL syntax with examples

URL (Uniform Resource Locator) syntax refers to the structure and components that make up a URL.  
A URL typically consists of several parts, each serving a specific purpose. Here’s a breakdown of the syntax and components of a URL, along with examples:

+ Scheme: Indicates the protocol used to access the resource. Common schemes include `http`, `https`, `ftp`, etc.
+ Username:Password (optional): Authentication credentials for accessing secure resources. But this isnot commonly used in modern URLs due to security concerns.
+ Host: The domain name or IP address of the server where the resource is hosted, `www.example.com`
+ Port (optional): Specifies the port number on the server. If omitted, default ports are used (e.g., 80 for HTTP, 443 for HTTPS).
+ Path: The specific location of the resource on the server, `/path/to/resource`
+ Query (optional): A string of key-value pairs that provide additional parameters to the resource. It begins with a `?`. Example: `?key1=value1&key2=value2`
+ Fragment (optional): A reference to a specific section within the resource, starting with `#`.

### syntax detail

`https://www.google.com`

+ https: Protocol
+ www: subdomain
+ google: domain name
+ com: extension
