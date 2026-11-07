# Quoting in shell scripts (and for regex)

The shell processes a command line before running it: it expands variables, substitutes commands, splits words, and expands globs.
Quotes control which of these steps happen. Tested with GNU Bash 5.2.

## 1. The quoting forms

| Form | `$var`, `$(cmd)` | `\` escapes | Word splitting, globs (`*`) | Example → output |
| --- | --- | --- | --- | --- |
| Unquoted | Expanded | Yes | **Yes** | `x="a  b *"; echo $x` → `a b` + file names |
| `"double"` | Expanded | Only before `$`, `` ` ``, `"`, `\`, newline | No | `echo "$x"` → `a  b *` |
| `'single'` | Literal | No (a `'` can't appear inside) | No | `echo '$HOME'` → `$HOME` |
| `$'ANSI-C'` *(Bash)* | Literal | C escapes: `\n`, `\t`, `\x41`, `\'` | No | `echo $'tab:\there'` → tab character |
| `\c` | — | Quotes one character | — | `echo \$HOME` → `$HOME` |

A single quote inside a single-quoted string: close, escape, reopen: `'it'\''s'` → `it's` (or `$'it\'s'`).

## 2. Rules of thumb

+ **Quote every expansion**: `"$var"`, `"$(cmd)"`, `"$@"`, `"${arr[@]}"`.
  Unquoted, a value with spaces becomes several arguments, and `*` turns into file names.
+ Use single quotes for fixed text that contains `$`, `` ` ``, `\`, or `!`:
  `dpkg-query -Wf '${Installed-Size}\t${Package}\n'` passes the `${...}` to dpkg, not to the shell.
+ Leave a variable unquoted only when you **want** splitting or globbing, and say so in a comment.
+ Inside `[[ ]]` and in assignments (`a=$b`), no splitting happens, but quoting is still harmless.

## 3. Quotes and regular expressions

A regex has no quote syntax of its own. The quotes belong to the **shell** (or the programming language) that passes the pattern to the tool.
Regex metacharacters (`* ? [ ] $ ^ \ ( ) |`) overlap with shell syntax, so:

+ **Single quotes by default**: the tool gets the pattern exactly as written.
  `grep -E '^[0-9]+\.[0-9]+$' versions.txt`
+ **Double quotes** when part of the pattern comes from a variable: `grep "^$prefix" file`.
  `$` followed by a name is then expanded, and `\` before `` $ ` " \ `` is removed by the shell.
+ If the variable's value must match **literally** (dots, brackets, ...), use `grep -F "$text"`, or escape it.
+ Mixing works: `grep '^[0-9]*'"$suffix"'$' file`.

Regex syntax itself: [regex_syntax.md](regex_syntax.md).

## Related notes

+ [shellScript_basic.md](shellScript_basic.md), [brackets_note.md](brackets_note.md)
+ [grep_intro.md](grep_intro.md), [sed_intro.md](sed_intro.md), [awk_intro.md](awk_intro.md)

## Reference

+ [Bash manual: Quoting](https://www.gnu.org/software/bash/manual/html_node/Quoting.html)
+ [POSIX: Quoting](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html#tag_19_02)
