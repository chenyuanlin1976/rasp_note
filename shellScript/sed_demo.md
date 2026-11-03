# sed: stream editor

`sed` reads input line by line, applies editing commands (substitute, delete, insert, print), and writes the result to stdout.
With `-i`, it edits files in place.

Examples were run with **GNU sed 4.9** (Linux). BSD/macOS sed differs where noted.

## 1. Syntax and options

```shell
sed [options] 'script' [file...]
sed [options] -f script.sed [file...]
```

| Option | Meaning |
| --- | --- |
| `-n` | Don't print each line automatically; print only with `p` |
| `-e 'cmd'` | Add a command (several `-e`, or separate commands with `;`) |
| `-f file` | Read commands from a file |
| `-E` | Extended regex (ERE): `+ ? \| ( ) { }` without backslashes. `-r` is the older GNU-only spelling |
| `-i[SUFFIX]` | Edit in place; with a suffix, keep a backup (`-i.bak`). BSD/macOS needs an argument: `-i ''` |

A command has the form `[address]command`. The address is a line number (`3`), a range (`2,4`, `5,$`), or a regex (`/pattern/`).
Without an address, the command applies to every line.

## 2. Substitute: `s/regex/replacement/flags`

```shell
sed 's/unix/linux/' file           # first match on each line
sed 's/unix/linux/g' file          # all matches
sed 's/unix/linux/2' file          # only the 2nd match on each line
sed 's/unix/linux/3g' file         # 3rd match and later
sed -n 's/unix/linux/p' file       # print only the changed lines
sed '3s/unix/linux/' file          # only on line 3
sed '1,3s/unix/linux/' file        # lines 1-3
sed '/^#/!s/foo/bar/' file         # lines that are NOT comments
sed 's|/usr/local|/opt|g' file     # another delimiter avoids escaping '/'
sed -i.bak 's/old/new/g' file      # edit in place, keep file.bak
```

+ `&` in the replacement is the whole match: `sed 's/[0-9]\+/<&>/g'`.
+ Groups: `\( \)` in basic regex, `( )` with `-E`. Refer to them as `\1`, `\2`, ...:

```shell
echo "Welcome To Taiwan" | sed -E 's/\b([A-Z])/(\1)/g'   # (W)elcome (T)o (T)aiwan
```

`\b`, `\w`, `\+` are GNU extensions. For portable scripts, use `[[:alnum:]_]` and `-E` with `+`.

## 3. Delete, print, insert

```shell
sed '5d' file                      # delete line 5
sed '$d' file                      # delete the last line
sed '2,4d' file                    # delete lines 2-4
sed '5,$d' file                    # delete from line 5 to the end
sed '/pattern/d' file              # delete matching lines
sed '/^$/d' file                   # delete empty lines
sed -n '2,3p' file                 # print only lines 2-3 (like head/tail)
sed -n '/start/,/end/p' file       # print from a line matching 'start' to one matching 'end'
sed '3i new text' file             # insert a line before line 3 (GNU one-line form)
sed '3a new text' file             # append a line after line 3
sed '/\[section\]/a key=value' file
```

POSIX sed requires the text of `i`/`a`/`c` on the next line (`3i\` + newline + text).
The one-line form above is a GNU extension.

## 4. Several commands, whitespace

```shell
sed -e 's/a/A/' -e 's/e/E/' file
sed '/^$/d; s/^[[:space:]]*//' file    # drop empty lines, then trim leading whitespace
sed 's/[[:space:]]*$//' file           # trim trailing whitespace
sed -i 's/\r$//' file                  # convert CRLF (Windows) line endings to LF
```

`sed` always uses regular expressions. `-E` only switches from basic (BRE) to extended (ERE) syntax.
Regex syntax: [../Linux/Regex_intro.md](../Linux/Regex_intro.md).

## Related notes

+ [grep_demo.md](grep_demo.md), [awk_demo.md](awk_demo.md), [quotes_note.md](quotes_note.md)

## Reference

+ [GNU sed manual](https://www.gnu.org/software/sed/manual/sed.html)
+ [POSIX sed](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/sed.html)
