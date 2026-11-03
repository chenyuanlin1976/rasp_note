# Bash scripting basics

A shell script is a text file of commands that a shell runs in order.
This note covers **Bash** (`/bin/bash`). Some features are Bash-only and don't work in a POSIX `sh` such as `dash`
(Debian/Ubuntu `/bin/sh`) or Android's `mksh`; they are marked *(Bash)*.

All examples were run with GNU Bash 5.2.

| Topic | Note |
| --- | --- |
| Brackets: `()`, `$()`, `(( ))`, `[ ]`, `[[ ]]`, `{}`, `${}` | [brackets_note.md](brackets_note.md) |
| Quoting | [quotes_note.md](quotes_note.md) |
| Ready-made recipes (read a file, rename files, `source`, ...) | [shellScript_recipes.md](shellScript_recipes.md) |
| Text tools | [grep_demo.md](grep_demo.md), [sed_demo.md](sed_demo.md), [awk_demo.md](awk_demo.md) |

## 1. A script

```shell
#!/usr/bin/env bash
# Comments start with '#'.
set -euo pipefail          # stop on errors, on unset variables, and on failures inside pipelines

backup_dir="/tmp/backup"
mkdir -p "$backup_dir"
echo "Backup directory is ready: $backup_dir"
```

```shell
chmod +x backup.sh
./backup.sh                # uses the interpreter from the shebang
bash backup.sh             # explicit interpreter; no execute bit needed
```

+ The **shebang** (`#!`) must be the first line. `#!/usr/bin/env bash` finds `bash` through `PATH`. `#!/bin/bash` is also common.
+ `set -e` exits on the first failing command (except in `if`, `&&`, `||` tests).
  `set -u` makes unset variables an error. `set -o pipefail` makes a pipeline fail if any part fails.
  They catch many bugs, but read up on their edge cases before relying on them.
+ Check scripts with **ShellCheck** (`shellcheck backup.sh`). It finds quoting mistakes and most of the pitfalls below.

## 2. Variables

```shell
name="Albert"              # no spaces around '='  (name = "Albert" runs a command named "name")
count=25
echo "Hello, $name"        # always quote expansions: "$name"
echo "${name}_report.txt"  # braces separate the name from following text
readonly PI=3              # constant
unset name                 # remove
export PATH="$HOME/bin:$PATH"   # visible to child processes
```

+ Values are strings. Arithmetic contexts (`$(( ))`, `-eq`, `declare -i`) treat them as integers.
+ Use lower-case names for script variables. Upper-case names are used by the environment (`PATH`, `HOME`, ...).
+ Expansions and string operations (`${var:-default}`, `${var%.*}`, ...) are in [brackets_note.md](brackets_note.md#4-dollar-curly-braces).

### 2.1 Arrays *(Bash)*

```shell
fruits=("apple" "lemon" "kiwi")
fruits+=("banana")
echo "${fruits[1]}"        # lemon (0-based)
echo "${#fruits[@]}"       # 4
for f in "${fruits[@]}"; do echo "$f"; done   # quoted: each element stays one word

declare -A port=([http]=80 [https]=443)       # associative array (Bash 4+)
echo "${port[https]}"
```

## 3. Arguments and special parameters

| Parameter | Meaning |
| --- | --- |
| `$0` | Script name as called |
| `$1` ... `$9`, `${10}` | Positional arguments (braces from 10 on) |
| `$#` | Number of arguments |
| `"$@"` | All arguments, **each as a separate word**: use this to pass arguments on |
| `"$*"` | All arguments joined into **one** string |
| `$?` | Exit status of the last command |
| `$$` | PID of the shell; `$!` is the PID of the last background job |

```shell
#!/usr/bin/env bash
if [ "$#" -lt 1 ]; then
    echo "usage: $0 <file>..." >&2
    exit 2
fi
for f in "$@"; do          # "a b" stays one argument
    echo "file: $f"
done
shift                      # drop $1; the rest move down
```

## 4. Exit status and conditions

Every command returns a status: **0 = success/true**, 1–255 = failure. `if` tests a command's status:

```shell
if grep -q "error" log.txt; then echo "found"; fi
mkdir -p out && echo "ok" || echo "failed"     # careful: "|| echo failed" also runs if the echo fails
```

`[ ... ]` (the `test` command) and `[[ ... ]]` *(Bash)* evaluate expressions:

| Test | True if |
| --- | --- |
| `-e f` / `-f f` / `-d f` / `-L f` / `-S f` | Exists / regular file / directory / symlink / socket |
| `-r f` / `-w f` / `-x f` / `-s f` | Readable / writable / executable / size > 0 |
| `-z "$s"` / `-n "$s"` | String empty / not empty |
| `"$a" = "$b"` / `"$a" != "$b"` | Strings equal / different (`==` works in Bash, `=` is POSIX) |
| `"$a" -eq "$b"` `-ne` `-lt` `-le` `-gt` `-ge` | Integer comparisons |
| `! expr` | Negation |
| `[ a ] && [ b ]`, `[ a ] \|\| [ b ]` | And / or (prefer these over the obsolete `-a` / `-o`) |
| `[[ $s == J*Doe ]]`, `[[ $s =~ ^[0-9]+$ ]]` | Glob match / regex match *(Bash)* |

```shell
score=85
if [ "$score" -ge 90 ]; then
    echo "A"
elif [ "$score" -ge 60 ]; then
    echo "pass"
else
    echo "fail"
fi
```

Quote variables inside `[ ]`: `[ $x = apple ]` breaks if `$x` is empty or contains spaces.

### 4.1 `case`

```shell
case "$lang" in
    java|kotlin) echo "JVM" ;;
    py*)         echo "Python" ;;      # glob patterns
    "")          echo "empty" ;;
    *)           echo "unknown: $lang" ;;   # default
esac
```

## 5. Loops

```shell
for f in *.log; do echo "$f"; done                   # files (glob, safe with spaces)
for i in {1..5}; do echo "$i"; done                  # 1 2 3 4 5 (inclusive)
for i in {0..10..2}; do echo "$i"; done              # step 2 (Bash 4+)
for ((i = 0; i < n; i++)); do echo "$i"; done        # C style, works with variables (Bash)
for i in $(seq "$start" "$step" "$end"); do echo "$i"; done   # POSIX-friendly, with variables

count=1
while [ "$count" -le 3 ]; do
    echo "count=$count"
    count=$((count + 1))
done

until ping -c1 -W1 192.168.1.1 >/dev/null; do sleep 1; done   # loop until the command succeeds
```

+ Brace expansion happens **before** variable expansion, so `{1..$n}` doesn't work. Use the C-style loop or `seq`.
+ `break` and `continue` work as in C.
+ Python's `range(1, 6)` is `{1..5}`: Bash ranges include the end.

## 6. Functions

```shell
greet() {
    local first="$1" last="$2"          # 'local' keeps variables inside the function
    echo "Hello, $first $last"
}
greet "John" "Doe"                      # called like a command: no parentheses, no commas

is_file() { [ -f "$1" ]; }              # status of the last command is the function's status
if is_file /etc/hosts; then echo "exists"; fi

square() { echo $(( $1 * $1 )); }       # "return" data by printing it
result=$(square 5)                      # 25
```

+ `return N` sets only the **exit status** (0–255; `return 300` gives 44). Return data through stdout or a global variable.
+ `function name { ... }` is the Bash keyword form. `name() { ... }` is POSIX and preferred.

## 7. Arithmetic

```shell
a="40"; b=2
echo $((a + b))  $((a / 3))  $((a % 3))  $((2 ** 10))    # 42 13 1 1024 (integers only)
((count++))                                             # arithmetic command (Bash); no '$' needed inside
declare -i n; n="20 + 5"; echo "$n"                     # 25: -i evaluates assignments (Bash)
echo "5.5 + 2.1" | bc                                   # 7.6: floating point needs bc or awk
awk 'BEGIN { printf "%.2f\n", 10 / 3 }'                 # 3.33
```

+ Validate input first: `[[ $x =~ ^-?[0-9]+$ ]]`.
  A non-numeric word in `$(( ))` or `declare -i` is read as a **variable name** (usually unset, so 0), not an error.
+ `expr 5 + 10` and backticks `` `cmd` `` are old forms. Use `$(( ))` and `$( )`.

## 8. Input, output, redirection

| Syntax | Meaning |
| --- | --- |
| `cmd > file`, `cmd >> file` | stdout (fd 1) to file: overwrite / append |
| `cmd 2> err.txt` | stderr (fd 2) to file |
| `cmd > all.txt 2>&1`, `cmd &> all.txt` *(Bash)* | stdout and stderr to the same file (order matters in the first form) |
| `cmd < file` | stdin (fd 0) from file |
| `cmd1 \| cmd2` | stdout of cmd1 to stdin of cmd2 |
| `cmd > /dev/null 2>&1` | Discard all output |
| `echo "error" >&2` | Write a message to stderr |

```shell
cat <<EOF > config.ini        # here-document; variables expand ('EOF' in quotes: no expansion)
name=$name
EOF

read -r -p "Username: " user      # -r: keep backslashes; -p: prompt (Bash)
read -r -s -p "Password: " pw; echo   # -s: no echo
read -r -t 5 -p "Continue? " ans || echo "timeout"   # -t: timeout in seconds
```

Use `printf` instead of `echo -e` for escapes and formats: `printf '%s=%d\n' "$name" "$count"`.
`echo` options differ between shells.

## 9. Style

+ Indent block bodies (`if`, loops, functions, `case`) consistently.
  The Google Shell Style Guide uses **2 spaces** and no tabs. 4 spaces are also common.
  Tabs have one special use: `<<-EOF` strips leading tabs from a here-document.
+ Quote every expansion (`"$var"`, `"$(cmd)"`, `"${arr[@]}"`) unless you want word splitting.
+ Prefer `$( )` over backticks, `[[ ]]` over `[ ]` in Bash-only scripts, and `printf` over `echo -e`.

## Related notes

+ [brackets_note.md](brackets_note.md), [quotes_note.md](quotes_note.md), [shellScript_recipes.md](shellScript_recipes.md), [fallbacks.md](fallbacks.md)
+ [grep_demo.md](grep_demo.md), [sed_demo.md](sed_demo.md), [awk_demo.md](awk_demo.md), [shellCmd_note.md](shellCmd_note.md)

## Reference

+ [GNU Bash manual](https://www.gnu.org/software/bash/manual/bash.html)
+ [POSIX Shell Command Language](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html)
+ [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
+ [ShellCheck](https://www.shellcheck.net/)
