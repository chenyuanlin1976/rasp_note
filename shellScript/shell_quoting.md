# Quoting in shell scripts (and for regex)

The shell processes a command line before running it. Quotes decide which of these steps happen to which part of the line.
Examples were tested with GNU Bash 5.1.

## 1. What the shell does to a command line

In order, after splitting the line into words:

1. Brace expansion: `{a,b}`, `{1..3}`
2. Tilde expansion: `~`
3. Parameter and variable expansion `$var`, command substitution `$(cmd)`, arithmetic expansion `$((1+2))`
4. **Word splitting** of unquoted expansion results, on spaces, tabs and newlines (`$IFS`)
5. **Pathname expansion** (globbing) of unquoted `*`, `?`, `[...]`
6. Quote removal: the quote characters themselves are removed before the command sees its arguments

Double quotes allow step 3 but block steps 1, 2, 4 and 5. Single quotes block everything.

## 2. The quoting forms

| Form | `$var`, `$(cmd)` | `\` escapes | Word splitting, globs (`*`) | Example → output |
| --- | --- | --- | --- | --- |
| Unquoted | Expanded | Yes | **Yes** | `x="a  b *"; echo $x` → `a b` + file names |
| `"double"` | Expanded | Only before `$`, `` ` ``, `"`, `\`, newline | No | `echo "$x"` → `a  b *` |
| `'single'` | Literal | No (a `'` can't appear inside) | No | `echo '$HOME'` → `$HOME` |
| `$'ANSI-C'` *(Bash)* | Literal | C escapes: `\n`, `\t`, `\x41`, `\'` | No | `echo $'tab:\there'` → `tab:`, a tab, `here` |
| `\c` | — | Quotes one character | — | `echo \$HOME` → `$HOME` |

A single quote inside a single-quoted string: close, escape, reopen: `'it'\''s'` → `it's` (or `$'it\'s'`).

Quotes can be mixed within one word: `echo 'cost: $'"$price"` → `cost: $12`.

## 3. Rules of thumb

+ **Quote every expansion**: `"$var"`, `"$(cmd)"`, `"$@"`, `"${arr[@]}"`.
  Unquoted, a value with spaces becomes several arguments, and `*` turns into file names.
+ Use single quotes for fixed text that contains `$`, `` ` ``, `\`, or `!`:
  `dpkg-query -Wf '${Installed-Size}\t${Package}\n'` passes the `${...}` to dpkg, not to the shell.
+ Leave a variable unquoted only when you **want** splitting or globbing, and say so in a comment.
+ No splitting or globbing happens in plain assignments (`a=$b`) or inside `[[ ]]`, so quotes are optional there,
  except on the right side of `==`, `!=` and `=~` (section 5).
+ Check scripts with ShellCheck (`shellcheck script.sh`): it flags most missing quotes.

## 4. "$@" vs. "$*"

| Form | Result for arguments `"a b"` and `c` |
| --- | --- |
| `"$@"` | Two words: `a b` and `c`: each argument kept intact. Use this to pass arguments on |
| `"$*"` | One word: `a b c`, joined with the first character of `$IFS` (with `IFS=,`: `a b,c`) |
| `$@` or `$*` unquoted | Re-split and globbed: `a`, `b`, `c`. Almost always a bug |

The same applies to arrays: `"${arr[@]}"` vs. `"${arr[*]}"`.

## 5. Pitfalls

+ **Patterns in `[[ ]]`**: an unquoted right side is a pattern, a quoted one is literal text.

  ```shell
  p="J*"
  [[ John == $p ]]     # true: glob pattern
  [[ John == "$p" ]]   # false: compares with the literal text J*
  ```

  The same holds for `case` patterns.
+ **`!` in double quotes** triggers history expansion in an **interactive** Bash (`echo "Hi!"` may fail with "event not found").
  Scripts are not affected. Use single quotes, or `set +H` to turn it off.
+ **Here-documents**: `<<EOF` expands variables and `$(...)` in the body; `<<'EOF'` (any quoting of the delimiter) keeps it literal.

  ```shell
  cat <<'EOF'
  $HOME is printed literally
  EOF
  ```

+ **Nested shells** (`ssh host "cmd"`, `sh -c "cmd"`, `sudo sh -c "..."`): the string is parsed twice, once locally and once by the inner shell.
  Variables in double quotes expand **locally**; use single quotes to expand them on the remote/inner side.
  To pass a local value safely, quote it for the inner shell with `printf %q` (Bash):

  ```shell
  f="my file"
  ssh host "ls -l -- $(printf %q "$f")"   # inner shell receives: ls -l -- my\ file
  ssh host 'echo $HOME'                   # remote $HOME
  ```

## 6. Quotes and regular expressions

A regex has no quote syntax of its own. The quotes belong to the **shell** (or the programming language) that passes the pattern to the tool.
Regex metacharacters (`* ? [ ] $ ^ \ ( ) |`) overlap with shell syntax, so:

+ **Single quotes by default**: the tool gets the pattern exactly as written.
  `grep -E '^[0-9]+\.[0-9]+$' versions.txt`
+ **Double quotes** when part of the pattern comes from a variable: `grep "^$prefix" file`.
  `$` followed by a name is then expanded, and `\` before `` $ ` " \ `` is removed by the shell
  (`"\."` stays `\.`, but `"\\."` becomes `\.` too).
+ If the variable's value must match **literally** (dots, brackets, ...), use `grep -F "$text"`, or escape it.
+ Mixing works: `grep '^[0-9]*'"$suffix"'$' file`.
+ **Bash `=~`**: keep the regex in a variable and leave it **unquoted** on the right side;
  a quoted right side is matched as literal text.

  ```shell
  re='^[0-9]+$'
  [[ $x =~ $re ]] && echo "number"
  ```

Regex syntax itself: [regex_syntax.md](regex_syntax.md).

## Related notes

+ [bash_basic.md](bash_basic.md): Bash basics; [brackets.md](brackets.md): `[ ]`, `[[ ]]`, `$( )`, `${ }`
+ [grep_intro.md](grep_intro.md), [sed_intro.md](sed_intro.md), [awk_intro.md](awk_intro.md): tools that take quoted patterns and programs
+ [regex_syntax.md](regex_syntax.md): regular expression syntax

## Reference

+ [Bash manual: Quoting](https://www.gnu.org/software/bash/manual/html_node/Quoting.html)
+ [Bash manual: Shell Expansions](https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html)
+ [POSIX: Quoting](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html#tag_19_02)
+ [ShellCheck](https://www.shellcheck.net/)
