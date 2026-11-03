# awk: pattern scanning and processing

`awk` is a small language for column-oriented text: it reads input **record by record** (normally line by line),
splits each record into **fields**, and runs `pattern { action }` rules on it.
It is good for reports, sums, and reformatting columns. For simple search, use `grep`. For substitutions, use `sed`.

Implementations: **gawk** (GNU, most features), **mawk** (fast; the default `awk` on Debian/Ubuntu), BusyBox awk (embedded/Android).
All examples were run with gawk 5.2 and mawk.

## 1. Syntax

```shell
awk [-F sep] [-v var=value] 'pattern { action } ...' [file...]
awk -f program.awk [file...]
```

| Part | Meaning |
| --- | --- |
| `-F sep` | Field separator (default: runs of spaces/tabs). `-F:`, `-F','`, `-F'\t'` |
| `-v var=value` | Pass a shell value into the program (safer than splicing it into the quotes) |
| `pattern` | Regex `/re/`, condition `$3 > 10`, range `NR==2, NR==5`, `BEGIN`, `END`. No pattern = every record |
| `{ action }` | Statements. No action = `{ print }` (print the record) |

Always put the program in **single quotes**, so the shell leaves `$1` alone (see [quotes_note.md](quotes_note.md)).

## 2. Built-in variables

| Variable | Meaning |
| --- | --- |
| `$0` | The whole record. `$1`, `$2`, ... are the fields |
| `NF` | Number of fields in the record. `$NF` is the last field |
| `NR` | Record number over all input. `FNR` restarts for each file |
| `FS` / `OFS` | Input / output field separator (`OFS` goes between `print` arguments separated by commas) |
| `RS` / `ORS` | Input / output record separator (default newline) |
| `FILENAME` | Current input file |

## 3. Examples

Input `a.txt`:

```text
alice 30 B6 x
bob 25 A1 y
carol 41 B6 z
```

```shell
awk '{ print $1, $NF }' a.txt                    # first and last field
awk '/bob/' a.txt                                # lines matching a regex (like grep)
awk '$3 == "B6"' a.txt                           # field equals a value
awk 'NR==2, NR==3 { print NR": "$0 }' a.txt      # line range, with line numbers
awk 'END { print NR }' a.txt                     # count lines
awk 'length($0) > 12' a.txt                      # lines longer than 12 characters
awk '{ if (length($0) > max) max = length($0) } END { print max }' a.txt   # longest line
awk -v min=28 '$2 > min { print $1 }' a.txt     # shell value via -v
awk '{ s += $2 } END { print s, s/NR }' a.txt    # sum and average of column 2: 96 32
awk '{ c[$3]++ } END { for (k in c) print k, c[k] }' a.txt   # count per value (order not defined)
awk 'BEGIN { OFS = "," } { print $1, $2 }' a.txt            # CSV output
awk '{ printf "%-6s %3d\n", $1, $2 }' a.txt      # formatted columns
awk -F: '{ print $1 }' /etc/passwd               # other separator
awk 'BEGIN { for (i = 1; i <= 6; i++) print "square of", i, "is", i*i }'   # no input needed
```

With other commands:

```shell
ps -eo pid,comm,%mem --sort=-%mem | awk 'NR > 1 && $3 > 1.0'   # processes using > 1 % memory
df -h | awk 'NR > 1 { print $5, $6 }'                          # usage per mount point
adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'      # serials of connected devices
```

Don't parse `ls -l` for file names (names may contain spaces). Use `find` or a glob.
For sizes: `find . -type f -size +1M`.

## Related notes

+ [grep_demo.md](grep_demo.md), [sed_demo.md](sed_demo.md), [quotes_note.md](quotes_note.md), [sumup_1st_col.sh](sumup_1st_col.sh)

## Reference

+ [The GNU Awk User's Guide](https://www.gnu.org/software/gawk/manual/gawk.html)
+ [POSIX awk](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/awk.html)
