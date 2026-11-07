# Shell script recipes

Small, tested patterns for everyday scripts (GNU Bash 5.2). Language basics are in [shellScript_basic.md](shellScript_basic.md).

## 1. Read a file

```shell
# Line by line (the standard pattern)
while IFS= read -r line || [ -n "$line" ]; do     # IFS=: keep leading/trailing spaces; -r: keep backslashes
    echo "line: $line"
done < input.txt                                  # '|| [ -n "$line" ]' also reads a last line without '\n'

# Split each line into fields (here: key:value; the last variable gets the rest)
while IFS=: read -r key value; do
    echo "[$key] = [$value]"
done < config.txt

# Whole file into a variable, or into an array of lines (Bash 4+)
content=$(<input.txt)
mapfile -t lines < input.txt; echo "${#lines[@]} lines"
```

+ Redirect into the loop (`done < file`). `cat file | while ...` runs the loop in a subshell, and its variables are lost afterwards.
+ Avoid `for w in $(cat file)`: it splits on all whitespace and expands `*` as a glob.
  If you really want words: `read -ra words <<< "$line"`.
+ Summing a column: `awk '{ s += $1 } END { print s }' file`, or the Bash version [sumup_1st_col.sh](sumup_1st_col.sh).

## 2. Loop over files safely

```shell
for f in ./*.log; do
    [ -e "$f" ] || continue                       # no match: the glob stays literal
    gzip -- "$f"
done

find . -name '*.tmp' -type f -print0 | while IFS= read -r -d '' f; do rm -- "$f"; done   # any file name
find . -name '*.tmp' -type f -delete                                                      # simpler, if find can do it
```

Don't parse `ls` output. Names can contain spaces and newlines.

## 3. Rename many files (001.jpg, 002.jpg, ...)

```shell
n=1
for f in *.jpg; do
    [ -e "$f" ] || continue
    new=$(printf '%03d.jpg' "$n")
    mv -n -- "$f" "$new"          # -n: never overwrite an existing file
    n=$((n + 1))
done
```

Change extensions: `for f in *.jpeg; do mv -- "$f" "${f%.jpeg}.jpg"; done`.

## 4. Timestamps and delays

```shell
ts=$(date +%F_%H-%M-%S)          # 2026-11-03_10-15-30 (safe in file names)
cp app.log "app_${ts}.log"
date +%s                          # seconds since the epoch
sleep 1; sleep 0.5; sleep 2m      # GNU sleep accepts fractions and suffixes
```

`date` formats: `%Y %m %d %H %M %S`, `%F` = `%Y-%m-%d`, `%T` = `%H:%M:%S`, `%z` = UTC offset, `%Z` = zone name.

## 5. Running vs sourcing (why `export` "doesn't work")

A script started as `./script.sh` or `bash script.sh` runs in a **child process**.
Its variables, `export`s, and `cd` disappear when it exits, because the environment is passed only from parent to child.

```shell
./env.sh;  echo "$FOO"            # empty
source ./env.sh; echo "$FOO"      # set: the commands ran in the current shell (". ./env.sh" in POSIX sh)
```

`sudo` starts commands with a clean environment (`env_reset`):

```shell
sudo -E ./script.sh               # keep the caller's environment (if the sudoers policy allows it)
sudo FOO=bar ./script.sh          # pass one variable explicitly
```

## 6. Errors, cleanup, and logging

```shell
#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT          # cleanup runs on any exit, also after an error

log() { printf '%s %s\n' "$(date +%T)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

command -v adb >/dev/null || die "adb not found"
log "working in $tmp"
```

## 7. Arguments with options

```shell
verbose=0 out="out.txt"
while getopts "vo:h" opt; do
    case "$opt" in
        v) verbose=1 ;;
        o) out="$OPTARG" ;;
        h|*) echo "usage: $0 [-v] [-o file] args..." >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))              # "$@" now holds the remaining arguments
```

## Related notes

+ [shellScript_basic.md](shellScript_basic.md), [brackets_note.md](brackets_note.md), [quotes_note.md](quotes_note.md), [fallbacks.md](fallbacks.md)
+ [grep_demo.md](grep_demo.md), [awk_intro.md](awk_intro.md), [sed_demo.md](sed_demo.md)

## Reference

+ [Bash manual](https://www.gnu.org/software/bash/manual/bash.html)
+ [BashFAQ 001: How can I read a file line by line?](https://mywiki.wooledge.org/BashFAQ/001)
+ [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls)
