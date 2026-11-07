# grep and line-oriented text tools

`grep` prints the lines that match a pattern. The other tools here (`sort`, `uniq`, `cut`, `tr`, `column`, `head`, `tail`)
are commonly piped after it. For editing lines, see [sed_demo.md](sed_demo.md). For columns and sums, see [awk_demo.md](awk_demo.md).
Examples were run with GNU grep and coreutils.

## 1. grep

```shell
grep [options] PATTERN [file...]
grep [options] -e PAT1 -e PAT2 [file...]
```

| Option | Meaning |
| --- | --- |
| `-i` | Ignore case |
| `-v` | Invert: lines that do **not** match |
| `-w` / `-x` | Match whole words / whole lines only |
| `-n` / `-c` / `-o` | Show line numbers / count matching lines / print only the matched part |
| `-E` / `-F` / `-P` | Extended regex (ERE) / fixed string, no regex / Perl regex (GNU) |
| `-e PAT`, `-f file` | Pattern (several allowed; useful if it starts with `-`) / patterns from a file |
| `-r` / `-R` | Recurse into directories (`-R` also follows symlinks) |
| `-l` / `-L` | Print only the names of files with / without a match |
| `-A N` / `-B N` / `-C N` | N lines of context after / before / around each match |
| `--include='*.c'`, `--exclude-dir=.git` | Limit a recursive search |
| `-q` | No output; only the exit status (0 = match). For `if` |

```shell
grep -i "error" app.log                         # no need for "cat file | grep"
grep -E "warn|error" app.log                    # alternatives (BRE: "warn\|error", GNU only)
grep -C3 "panic" dmesg.txt                      # 3 lines of context
grep -rnw --include='*.c' -e malloc .           # whole word "malloc" in .c files, with line numbers
grep -rl "TODO" --exclude-dir=.git .            # files that contain TODO
grep -c "^$" file                               # number of empty lines
grep -o 'v[0-9]\+\.[0-9]\+' notes.txt           # print only the version strings
if grep -q "^ro.debuggable=1" build.prop; then echo "debuggable"; fi
```

### 1.1 Output appears late in a pipeline

`prog | grep pattern` sometimes shows nothing until `prog` exits. Usually the **producer** is the cause:
a program writing to a pipe (not a terminal) block-buffers its stdout (C stdio, C++ iostreams, Python).
grep itself prints each line at once when its output is a terminal.

```shell
stdbuf -oL ./prog | grep pattern                 # make the producer line-buffered (C stdio programs)
python3 -u script.py | grep pattern               # Python: unbuffered
tail -f log | grep --line-buffered err | tee e.txt   # grep in the middle of a pipeline: line-buffer grep too
```

In your own C/C++ program, call `fflush(stdout)` or `setvbuf(stdout, NULL, _IOLBF, 0)`, or use `std::endl` / `std::flush`.

## 2. sort, uniq

`sort` compares text by default, so `10` sorts before `9`.

```shell
sort -n file          # numeric
sort -nr file         # numeric, descending
sort -k2,2n file      # by field 2 only, numeric (-t, sets the field separator)
sort -h file          # human-readable sizes: 2K < 45M < 2G   (du -sh * | sort -h)
sort -g file          # general numbers: decimals, 1.2e6
sort -u file          # sorted, duplicates removed (= sort | uniq)
sort file | uniq -c | sort -nr     # count identical lines, most frequent first
```

`uniq` only removes **adjacent** duplicates, so sort first.

## 3. cut, tr, column, head, tail

```shell
cut -c20-80 file            # characters 20-80 of each line
cut -d: -f1,7 /etc/passwd   # fields 1 and 7, ':' separated (cut can't handle runs of spaces: use awk)
tr 'a-z' 'A-Z' < file       # translate characters (works on characters, not strings)
tr -d '\r' < in > out       # delete characters (CRLF -> LF)
column -t -s, data.csv      # align a CSV as a table
head -n 20 file; tail -n 20 file
tail -f /var/log/syslog     # follow a growing file
```

## Related notes

+ [sed_demo.md](sed_demo.md), [awk_demo.md](awk_demo.md), [quotes_note.md](quotes_note.md), [linux_cmds.md](linux_cmds.md)
+ [regex_syntax.md](regex_syntax.md)

## Reference

+ [GNU grep manual](https://www.gnu.org/software/grep/manual/grep.html)
+ [GNU coreutils manual](https://www.gnu.org/software/coreutils/manual/coreutils.html)
