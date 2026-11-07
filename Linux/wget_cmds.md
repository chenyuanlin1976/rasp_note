# wget: download files from the command line

`wget` is a non-interactive downloader for HTTP, HTTPS and FTP. It needs no user input once started,
so it works well in scripts, over SSH and in the background, and it can resume broken downloads and mirror websites.
Examples were checked against GNU Wget 1.21.2.

## 1. Syntax

```shell
wget [options] URL...
```

Without options, the file is saved in the current directory under the name taken from the URL.
If that name already exists, wget saves the new copy as `file.1`, `file.2`, ...

## 2. Common options

| Option | Meaning |
| --- | --- |
| `-O <file>` | Save under this name (`-O -` writes to stdout) |
| `-P <dir>` | Save into this directory |
| `-c` | Continue a partially downloaded file |
| `-i <file>` | Read URLs from a file, one per line, and download them in order |
| `-b` | Run in the background; progress goes to `wget-log` in the current directory |
| `-q` | Quiet: no output |
| `--limit-rate=<rate>` | Limit the speed, e.g. `200k` or `2m` (bytes per second) |
| `-t <n>`, `--tries=<n>` | Number of retries (default 20) |
| `-T <s>`, `--timeout=<s>` | Network timeout in seconds |
| `-U <agent>` | Set the User-Agent string |
| `--user=<u> --ask-password` | HTTP/FTP login; prompts for the password so it isn't stored in shell history |

## 3. Downloading files

```shell
wget https://example.com/file.zip                     # save as ./file.zip
wget -O custom_name.zip https://example.com/file.zip  # save under another name
wget -P ~/Downloads https://example.com/file.zip      # save into a directory
wget -c https://example.com/large-file.iso            # resume an interrupted download
wget -b -c https://example.com/large-file.iso         # same, in the background
tail -f wget-log                                      # follow the background download
wget -c -i urls.txt                                   # download (and resume) every URL in a list
wget --limit-rate=200k https://example.com/file.zip   # don't saturate the link
wget -qO- https://example.com/install.sh | less       # print to stdout, e.g. to read a script before running it
```

`-c` only works if the server supports range requests. If it doesn't, wget starts the download over from the beginning.

## 4. Recursive downloads and mirroring

| Option | Meaning |
| --- | --- |
| `-r` | Recursive: follow links (default depth 5) |
| `-l <n>` | Maximum recursion depth (`inf` = unlimited) |
| `-np`, `--no-parent` | Never go above the starting directory |
| `-A <list>` / `-R <list>` | Accept / reject file name patterns, e.g. `-A '*.pdf'` |
| `-k`, `--convert-links` | Rewrite links in saved pages so they work offline |
| `-E`, `--adjust-extension` | Add `.html` to pages that lack the extension |
| `-p`, `--page-requisites` | Also fetch images, CSS and scripts needed to display each page |
| `-m`, `--mirror` | Shortcut for `-r -N -l inf --no-remove-listing` (`-N` = only fetch files newer than the local copy) |
| `-w <s>`, `--wait=<s>` | Wait between requests, to be polite to the server |

```shell
# mirror a site for offline viewing
wget --mirror --convert-links --adjust-extension --page-requisites --no-parent https://example.com/docs/

# download all PDFs from one directory listing, without climbing to the parent
wget -r -l 1 -np -A '*.pdf' https://example.com/papers/
```

Recursive downloads respect `robots.txt`. Use `--wait` on sites you don't own.

## 5. wget vs. curl

| | wget | curl |
| --- | --- | --- |
| Default output | Saves to a file | Writes to stdout (`-O` / `-o` to save) |
| Recursive / mirror | Yes | No |
| Resume | `-c` | `-C -` |
| Follows redirects | By default | Only with `-L` |
| Strength | Downloading files and whole sites | Talking to APIs: any method, headers, request bodies |

## Related notes

+ [rsync_cmds.md](rsync_cmds.md): copy and sync files between machines over SSH
+ [../shellScript/linux_cmds.md](../shellScript/linux_cmds.md): Linux command cheat sheet

## Reference

+ [GNU Wget manual](https://www.gnu.org/software/wget/manual/wget.html)
