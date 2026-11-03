# Bash brackets quick reference

| Syntax | Name | Result |
| --- | --- | --- |
| `( cmds )` | Subshell | Runs `cmds` in a child shell; variable changes don't survive |
| `{ cmds; }` | Group | Runs `cmds` in the current shell; changes survive |
| `$( cmd )` | Command substitution | The **output** of `cmd` as a string |
| `<( cmd )`, `>( cmd )` | Process substitution *(Bash)* | A file name (`/dev/fd/N`) connected to `cmd` |
| `(( expr ))` | Arithmetic command *(Bash)* | Status 0 if `expr` ≠ 0; assignments stick |
| `$(( expr ))` | Arithmetic expansion | The **value** of `expr` |
| `[ expr ]` | `test` | POSIX condition |
| `[[ expr ]]` | Conditional *(Bash)* | Condition with globs, regex, `&&`/`\|\|`, no word splitting |
| `{a,b}`, `{1..5}` | Brace expansion | Generates words |
| `${var...}` | Parameter expansion | Value of a variable, with optional operations |
| `arr=( ... )`, `${arr[i]}` | Array *(Bash)* | See [shellScript_basic.md](shellScript_basic.md#21-arrays-bash) |

**Spaces**: `[`, `]`, `[[`, `]]`, `{` and `}` (as a group) are separate words, so they need spaces around them,
and a group needs `;` or a newline before `}`: `{ echo a; }`.
Round brackets don't need spaces: `(cd /tmp && ls)`.
Inside `${...}` there are no spaces.

All examples were run with GNU Bash 5.2.

## 1. Parentheses

### 1.1 `( cmds )`: subshell

```shell
a="original"
( a="changed"; cd /tmp )     # runs in a child shell
echo "$a"; pwd               # original, and the directory didn't change
```

Use it to change directory, variables, or `set` options temporarily.

### 1.2 `$( cmd )`: command substitution

```shell
intro="My name is $(whoami)"
files_count=$(ls | wc -l)
today="$(date +%F)"          # quote it when assigning or using it, to keep spaces and newlines
```

+ The result is **one string**, with trailing newlines removed. It is not an array.
  To get one array element per line, use `mapfile -t lines < <(cmd)` *(Bash 4+)*.
+ `` `cmd` `` (backticks) is the old form, which is hard to nest. Use `$( )`.
+ The exit status of `cmd` is in `$?` afterwards. Testing it directly is clearer:
  `if grep -q PATTERN file; then ...` instead of `echo $(grep -q PATTERN file)$?`.

### 1.3 `<( cmd )`: process substitution *(Bash)*

The output of `cmd` appears as a file, for commands that need file names instead of stdin:

```shell
diff <(sort a.txt) <(sort b.txt)
while read -r line; do echo "$line"; done < <(ls /etc)   # loop in the current shell (a pipe would use a subshell)
```

### 1.4 `(( expr ))` and `$(( expr ))`: arithmetic

```shell
i=7
(( i += 3 ))                 # command: changes i, no output
(( i > 5 )) && echo "big"    # status 0 when the expression is non-zero
legs=100
echo "rabbits: $(( legs / 4 ))"   # expansion: substitutes the value (25)
```

Integers only. Inside, variables don't need `$`. See [shellScript_basic.md](shellScript_basic.md#7-arithmetic).

## 2. Square brackets

### 2.1 `[ expr ]`: POSIX test

`[` is a command (a shell builtin, also `/usr/bin/[`) whose last argument must be `]`.

```shell
if [ -f "$file" ] && [ "$count" -gt 0 ]; then echo "ok"; fi
```

Quote variables: `[ $x = y ]` fails with "unary operator expected" when `$x` is empty.

### 2.2 `[[ expr ]]`: Bash conditional

```shell
name="John Doe"
[[ $name == J*Doe ]] && echo "glob match"            # right side unquoted = pattern
[[ $ver =~ ^([0-9]+)\.([0-9]+)$ ]] && echo "major=${BASH_REMATCH[1]}"
[[ -f $f && $f != *.bak ]] && echo "use $f"          # && and || inside
```

No word splitting or globbing inside `[[ ]]`, so unquoted variables are safe there.
Quote the right side of `==` to compare literally: `[[ $a == "$b" ]]`.

Operator table: [shellScript_basic.md](shellScript_basic.md#4-exit-status-and-conditions).

## 3. Curly braces

### 3.1 `{ cmds; }`: group in the current shell

```shell
{ echo "header"; date; } > report.txt     # one redirection for several commands
[ -f config ] || { echo "missing config" >&2; exit 1; }
```

### 3.2 Brace expansion

```shell
echo h{a,e,i,o,u}p           # hap hep hip hop hup
echo {01..05}                # 01 02 03 04 05 (zero-padded)
echo {0..10..5}              # 0 5 10
cp config.ini{,.bak}         # cp config.ini config.ini.bak
mkdir -p proj/{src,include,test}
```

Brace expansion happens before variable expansion: `{1..$n}` stays literal.

## 4. Dollar curly braces

`${...}` expands a variable. The braces delimit the name, and operators inside transform the value:

| Expansion | Result (`s=hello_world.tar.gz`) |
| --- | --- |
| `${s}suffix` | Value followed by text (`$ssuffix` would be a variable named `ssuffix`) |
| `${#s}` | Length: `18` |
| `${s:0:5}` | Substring (offset, length): `hello` |
| `${s#*.}` / `${s##*.}` | Remove shortest / longest prefix matching `*.`: `tar.gz` / `gz` |
| `${s%.*}` / `${s%%.*}` | Remove shortest / longest suffix matching `.*`: `hello_world.tar` / `hello_world` |
| `${s/o/0}` / `${s//o/0}` | Replace first / all `o`: `hell0_world.tar.gz` / `hell0_w0rld.tar.gz` |
| `${s^^}` / `${s,,}` | Upper / lower case *(Bash 4+)* |
| `${v:-default}` | `default` if `v` is unset **or empty** (`${v-default}`: only if unset) |
| `${v:=default}` | Like `:-`, and also assigns the default to `v` |
| `${v:?message}` | Exit with `message` if `v` is unset or empty |
| `${v:+alt}` | `alt` if `v` is set and not empty, otherwise empty |
| `${arr[@]}`, `${#arr[@]}` | All elements / number of elements *(Bash)* |

```shell
greeting() { echo "Hello, ${1:-World}!"; }
greeting            # Hello, World!
greeting Ryan       # Hello, Ryan!

for f in *.jpeg; do mv -- "$f" "${f%.jpeg}.jpg"; done   # change extensions
```

More on defaults: [fallbacks.md](fallbacks.md).

## Related notes

+ [shellScript_basic.md](shellScript_basic.md), [quotes_note.md](quotes_note.md), [shellScript_recipes.md](shellScript_recipes.md)

## Reference

+ [Bash manual: Shell Expansions](https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html)
+ [Bash manual: Compound Commands](https://www.gnu.org/software/bash/manual/html_node/Compound-Commands.html)
+ [Bash brackets quick reference (dev.to)](https://dev.to/rpalo/bash-brackets-quick-reference-4eh6)
