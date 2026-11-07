# Regular expression syntax

A regular expression (regex) is a pattern that matches text. The core syntax is the same everywhere,
but each tool uses one of a few **flavors**, and the differences (`\d`, `+`, `{}`, `( )`, lazy `*?`) cause most surprises.
Examples were run with GNU grep 3.11, GNU sed 4.9, gawk 5.2, mawk 1.3.4, Bash 5.2, and Python 3.12.

## 1. Flavors

| Flavor | Used by | Notes |
| --- | --- | --- |
| **BRE** (POSIX basic) | `grep`, `sed`, `vi` | `? + { } ( ) \|` are literal characters; write `\{ \} \( \)` for the operators. GNU adds `\+ \? \|` |
| **ERE** (POSIX extended) | `grep -E`, `sed -E`, `awk`, Bash `[[ =~ ]]`, `find -regextype posix-extended` | `? + { } ( ) \|` are operators without backslashes |
| **PCRE** / Perl-style | `grep -P`, Perl, PCRE2; Python `re`, JavaScript, Java, C++ `std::regex` are very similar | Adds `\d \w \s`, lazy quantifiers, lookarounds, non-capturing and named groups (section 6) |

When in doubt, use ERE (`grep -E`, `sed -E`): it is the same in GNU and BSD/macOS tools, apart from the GNU extensions noted below.

## 2. Characters and classes

| Syntax | Matches | Flavors |
| --- | --- | --- |
| `a`, `7`, `-` | That character | All |
| `.` | Any one character (except newline in Perl-style flavors without the `s` flag) | All |
| `[abc]`, `[a-z0-9]` | One character from the set or range | All |
| `[^0-9]` | One character **not** in the set | All |
| `[[:digit:]]`, `[[:alpha:]]`, `[[:alnum:]]`, `[[:space:]]`, `[[:upper:]]`, `[[:punct:]]` | POSIX classes. Only valid **inside** a bracket expression: `[[:digit:]]`, `[^[:space:]]` | BRE, ERE (PCRE also accepts them) |
| `\d` / `\D` | Digit / non-digit (`[0-9]`) | PCRE only |
| `\w` / `\W` | Word character (`[[:alnum:]_]`) / other | PCRE; GNU grep, sed, gawk |
| `\s` / `\S` | Whitespace (space, tab, newline, ...) / other | PCRE; GNU grep, sed, gawk |

+ Inside brackets, most metacharacters are literal: `[.*+?]` matches one of those four characters.
  To include `]`, put it first (`[]x]`); to include `-`, put it first or last (`[a-]`); `^` is literal if it isn't first.
+ Outside brackets, prefix a metacharacter with `\` to match it literally: `\.`, `\*`, `\[`, `\$`, `\\`.
  In ERE, also `\+`, `\?`, `\(`, `\{`, `\|`. A class works too and is easier to read: `[.]`.

**`\d` is not POSIX.** GNU grep (without `-P`), sed, and mawk don't reject it; they match a **literal `d`**:

```shell
echo "d5" | grep -o '\d'        # d  (not 5!)
echo "d5" | grep -oP '\d'       # 5
echo "d5" | grep -o '[0-9]'     # 5  (portable)
```

gawk warns about `\d` and also treats it as `d`; Bash `[[ =~ ]]` doesn't support it.

## 3. Anchors and boundaries

Anchors match a **position**, not a character.

| Syntax | Matches at | Flavors |
| --- | --- | --- |
| `^` / `$` | Start / end of the line (grep, sed, awk work line by line) or string | All |
| `\b` / `\B` | A word boundary / not a word boundary. `\bcat\b` matches "the cat", not "concat"; `\Bcat\B` matches inside "educate" | PCRE; GNU grep, sed |
| `\<` / `\>` | Start / end of a word | GNU grep, sed, gawk |
| `\y` | Word boundary (gawk uses `\y` because `\b` is backspace in awk) | gawk |
| `\A`, `\z`, `(?m)` | Start / end of the whole string, multiline mode (`^`/`$` at each line) | PCRE, Python |

`grep -w pattern` is the simplest way to match whole words.

## 4. Quantifiers

A quantifier repeats the item before it (a character, a class, or a group).

| ERE / PCRE | BRE | Repeats |
| --- | --- | --- |
| `*` | `*` | 0 or more |
| `+` | `\+` (GNU) | 1 or more |
| `?` | `\?` (GNU) | 0 or 1: `colou?r` matches "color" and "colour" |
| `{n}` | `\{n\}` | Exactly n: `[0-9]{4}` |
| `{n,}` | `\{n,\}` | n or more |
| `{n,m}` | `\{n,m\}` | n to m |

+ Quantifiers are **greedy**: they match as much as possible, and the overall match is the leftmost-longest one in POSIX tools.
+ Lazy (non-greedy) forms `*?`, `+?`, `??`, `{n,m}?` exist **only in Perl-style flavors**. In ERE, `+?` is just `+` followed by `?`, which is still greedy.
  The portable way is a negated class:

```shell
echo '<a><b>' | grep -oE '<.+>'       # <a><b>       (greedy)
echo '<a><b>' | grep -oE '<.+?>'      # <a><b>       (ERE has no lazy quantifier)
echo '<a><b>' | grep -oP '<.+?>'      # <a> and <b>  (PCRE lazy)
echo '<a><b>' | grep -oE '<[^>]+>'    # <a> and <b>  (portable)
```

## 5. Groups, alternation, back-references

| ERE / PCRE | BRE | Meaning |
| --- | --- | --- |
| `(...)` | `\(...\)` | Group: apply a quantifier to it (`(ab)+`) and capture the text it matched |
| `a\|b` (`a|b`) | `\|` (GNU) | Alternation: `cat|dog`, `c(at|ow)`. It has the lowest precedence: `^a|b$` means `(^a)|(b$)` |
| `\1` ... `\9` | `\1` ... `\9` | Back-reference to group n in the **pattern** (`(..)\1` matches "abab"). POSIX defines it for BRE; GNU ERE supports it too |

In the table, `\|` stands for the `|` character (Markdown tables need the escape). Replacement strings use the groups too:

```shell
echo 2026-11-03 | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3.\2.\1/'   # 03.11.2026
echo abc | sed 's/b/[&]/'                                                # a[b]c  (& = the whole match)
```

## 6. Perl-style extensions

Only in PCRE (`grep -P`), Perl, Python, JavaScript, Java, and similar flavors. Lazy quantifiers are in section 4.

| Syntax | Meaning |
| --- | --- |
| `(?:...)` | Non-capturing group: `(?:un)?do` matches "undo" and "do" |
| `(?<name>...)` (PCRE, Java, JavaScript), `(?P<name>...)` (Python, also PCRE) | Named group |
| `x(?=y)`, `x(?!y)` | Lookahead: x followed / not followed by y. `\d+(?=USD)` matches 100 in "100USD" |
| `(?<=y)x`, `(?<!y)x` | Lookbehind |
| `\K` (PCRE) | Drop what was matched so far from the result: `grep -oP 'key=\K\w+'` prints only the value |
| `(?i)` | Flags inside the pattern: ignore case (also `m` multiline, `s` dot matches newline) |

## 7. Regexes in the shell

+ Put patterns in **single quotes**, so the shell doesn't expand `$`, `*`, or `\` first ([quotes_note.md](quotes_note.md)).
+ For a fixed string with no regex at all, use `grep -F` (`grep -F 'a.b[1]'`).
+ `\t` and `\n` are understood by GNU sed and PCRE, but not by `grep` (BRE/ERE). Use Bash's `$'\t'` there: `grep $'a\tb'`.
+ In Bash, store the pattern in a variable and use it **unquoted** on the right of `=~`; quoting it makes it a literal string:
  `re='^v([0-9]+)\.([0-9]+)$'; [[ $s =~ $re ]] && echo "${BASH_REMATCH[1]}"`.

## 8. Common patterns (ERE)

| Pattern | Matches |
| --- | --- |
| `^$` / `^[[:space:]]*$` | Empty line / blank line |
| `[[:space:]]+$` | Trailing whitespace |
| `^[[:space:]]*#` | Comment line (shell, config files) |
| `"[^"]*"` | A double-quoted string (not `".*"`, which runs to the last quote on the line) |
| `[0-9]+(\.[0-9]+)*` | Version number: 6, 6.14, 6.14.0 |
| `0x[0-9A-Fa-f]+` | Hex number |
| `([0-9]{1,3}\.){3}[0-9]{1,3}` | IPv4-like address (doesn't check that each number is ≤ 255) |
| `([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}` | MAC address |
| `^[A-Za-z_][A-Za-z0-9_.]*=` | `KEY=` at the start of a line (shell variables, `.env`; the `.` is for `build.prop` keys such as `ro.debuggable`) |

```shell
grep -cE '^[[:space:]]*$' file                         # count blank lines
grep -vE '^[[:space:]]*(#|$)' app.conf                 # show a config file without comments and blank lines
ip -4 addr | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}'
sed -E 's/[[:space:]]+$//' file                        # strip trailing whitespace
```

Regexes are fine for finding things in text. For structured formats (JSON, XML, HTML, CSV with quotes), use a parser (`jq`, `xmllint`, Python).

## Related notes

+ [grep_intro.md](grep_intro.md), [sed_intro.md](sed_intro.md), [awk_intro.md](awk_intro.md)
+ [quotes_note.md](quotes_note.md): quoting patterns in the shell
+ [shellScript_basic.md](shellScript_basic.md): `[[ =~ ]]` in Bash

## Reference

+ [POSIX regular expressions (The Open Group, Base Definitions ch. 9)](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap09.html)
+ [GNU grep manual: regular expressions](https://www.gnu.org/software/grep/manual/grep.html)
+ [GNU sed manual: BRE and ERE syntax](https://www.gnu.org/software/sed/manual/sed.html)
+ [gawk manual: regexp operators](https://www.gnu.org/software/gawk/manual/html_node/Regexp-Operators.html)
+ [PCRE2 pattern syntax](https://www.pcre.org/current/doc/html/pcre2pattern.html), [Python `re`](https://docs.python.org/3/library/re.html)
