# URI and URL

A **URI** (Uniform Resource Identifier) is a string that identifies a resource. A **URL** (Uniform Resource Locator) is a URI that also says how to reach the resource, through its scheme (`https`, `ftp`, `file`, ...).
Every URL is a URI, but not every URI is a URL: a URN such as `urn:isbn:0451450523` names a book without saying where to get it.

## 1. URI vs URL

| | URI | URL |
| --- | --- | --- |
| Meaning | Any identifier for a resource: a name, a location, or both | An identifier that gives the access mechanism and location |
| Examples | `urn:isbn:0451450523`, `mailto:info@example.com`, `data:...` | `https://www.example.com/`, `ftp://ftp.example.com/file.txt` |
| Relation | The general term | A subset of URIs |

In everyday use the two words are often interchangeable. Current specifications (RFC 3986, the WHATWG URL standard) mostly just say "URI" or "URL" for all of them.

## 2. Syntax

```text
  https://user:pass@www.example.com:8443/path/to/page?key1=value1&key2=value2#section2
  \___/   \_______/ \_____________/ \__/\___________/ \_____________________/ \______/
 scheme   userinfo        host      port     path              query           fragment
          \_______________________________/
                      authority
```

| Part | Notes |
| --- | --- |
| Scheme | Protocol or URI type: `http`, `https`, `ftp`, `file`, `mailto`, `data`, ... Followed by `:` |
| Userinfo | Optional `user:password@`. Deprecated in URLs for security; browsers warn about it or ignore it |
| Host | Domain name or IP address (IPv6 in brackets: `http://[::1]/`) |
| Port | Optional. Defaults: 80 for HTTP, 443 for HTTPS, 21 for FTP |
| Path | Location of the resource on the server, e.g. `/path/to/page` |
| Query | Optional, starts with `?`. Usually `key=value` pairs separated by `&` |
| Fragment | Optional, starts with `#`. A part of the resource; the browser keeps it and doesn't send it to the server |

Special characters are percent-encoded, e.g. a space is `%20` (`+` also means a space in form queries).

### 2.1 Parts of a host name

In `www.google.com`, read the labels from right to left:

+ `com`: top-level domain (TLD)
+ `google`: second-level domain, the registered name
+ `www`: subdomain (a host name chosen by the domain owner)

## 3. Examples

| Kind | Example | Notes |
| --- | --- | --- |
| HTTP / HTTPS URL | `https://secure.example.com` | |
| FTP URL | `ftp://ftp.example.com/resource.txt` | |
| URL with path and query | `https://www.example.com/search?q=URL+syntax` | |
| URL with fragment | `https://www.example.com/articles#section2` | |
| File URI | `file:///sdcard/Movies/movie.mp4` | Empty host (`//`) followed by an absolute path |
| URN | `urn:isbn:0451450523` | Names a book by ISBN; no location |
| Mailto URI | `mailto:info@example.com` | Opens a new e-mail |
| Data URI | `data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==` | Inline content, here "Hello, World!" in base64 |

## Related notes

+ [network_troubleshoot.md](network_troubleshoot.md): `curl` for testing URLs
+ [wget_cmds.md](wget_cmds.md), [network_cmds.md](network_cmds.md)

## Reference

+ [RFC 3986: URI generic syntax](https://www.rfc-editor.org/rfc/rfc3986)
+ [WHATWG URL standard](https://url.spec.whatwg.org/)
+ [MDN: What is a URL?](https://developer.mozilla.org/en-US/docs/Learn_web_development/Howto/Web_mechanics/What_is_a_URL)
