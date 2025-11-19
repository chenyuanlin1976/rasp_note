# network command list

`sudo pppoeconf`  
`sudo pon dsl-provider` // 撥接連線  
`sudo poff`             // 中斷連線  
`plog`                  // 查詢連線紀錄  
`ifconfig`              // 列出所有的網路組態  
`ifconfig ppp0`         // 只列出ppp0的網路組態

`iwconfig`

## URI: Uniform Resource Identifier

A URI is a **string** of characters that uniquely identifies a resource on the internet.  
It consists of several components, including the scheme, authority, path, query and fragment.  
Each part plays a role in identifying and interacting with online resources and assets.

## URL: Uniform Resource Locator

A URL is a specific type of URI that not only identifies a resource but also provides the means to locate it.  
It includes information such as the protocol (e.g., HTTP or HTTPS) and the domain name, which directs users to the resource's location on the web.  
These are often referred to as the parts of a url.

## URI vs URL — what exactly are the differences

The terms URI and URL are often confused and used interchangeably but they serve different purposes when it comes to website creation.  
While all URLs are URIs, not all URIs are URLs.  
A URI can be a name, a location or both.  
URLs specifically provide the means to access a resource by describing its primary access mechanism.

This can be a tricky comparison to understand so let's lay it out like this:

+ URI (Uniform Resource Identifier): A generic term for all types of names and addresses that refer to objects on the web.
+ URL (Uniform Resource Locator): A specific type of URI that provides a means to locate a resource by describing its primary access mechanism.

## URI examples

1. HTTPS URI: `https://www.example.com`
2. URN: `urn:isbn:0451450523` (Identifies a book by its ISBN)
3. Data URI: `data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==` (Encodes a string in base64)
4. Mailto URI: `mailto:info@example.com` (Used to initiate an email)
5. File URI: `file:///sdcard/Movies/StarWar.mp4` (Identifies a file on the local filesystem)

## URL examples

1. HTTP URL: `http://www.example.com`
2. HTTPS URL: `https://secure.example.com`
3. FTP URL: `ftp://ftp.example.com/resource.txt`
4. URL with Path and Query: `https://www.example.com/search?q=URL+syntax`
5. URL with Fragment: `https://www.example.com/articles#section2`

## What is a URL syntax with examples

URL (Uniform Resource Locator) syntax refers to the structure and components that make up a URL.  
A URL typically consists of several parts, each serving a specific purpose. Here’s a breakdown of the syntax and components of a URL, along with examples:

+ Scheme: Indicates the protocol used to access the resource. Common schemes include `http`, `https`, `ftp`, etc.
+ Username:Password (optional): Authentication credentials for accessing secure resources. But this isnot commonly used in modern URLs due to security concerns.
+ Host: The domain name or IP address of the server where the resource is hosted, `www.example.com`
+ Port (optional): Specifies the port number on the server. If omitted, default ports are used (e.g., 80 for HTTP, 443 for HTTPS).
+ Path: The specific location of the resource on the server, `/path/to/resource`
+ Query (optional): A string of key-value pairs that provide additional parameters to the resource. It begins with a `?`. Example: `?key1=value1&key2=value2`
+ Fragment (optional): A reference to a specific section within the resource, starting with `#`.

## Example

`https://www.google.com`

+ https: Protocol
+ www: subdomain
+ google: domain name
+ com: extension
