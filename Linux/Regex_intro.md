# Regular expressions

Regular expressions (Regex) are **patterns** used to match character combinations in strings.  
Below is a comprehensive reference guide to regular expression syntax, categorized for quick lookup.

## Character Classes & Special Characters

Character classes match any one of a set of characters.

| Syntax   | Description                                         | Example   | Matches                          |
| -------- | --------------------------------------------------- | --------- | -------------------------------- |
| `[abc]`  | Any character between the brackets                  | `[aeiou]` | Any lowercase vowel              |
| `[^abc]` | Any character not between the brackets              | `[^0-9]`  | Any non-digit character          |
| `[a-z]`  | Range of characters (inclusive)                     | `[a-z]`   | Any lowercase letter from a to z |
| `.`      | Any character except a newline                      | `a.c`     | "abc", "a c", "a1c"              |
| `\d`     | Any digit (equivalent to [0-9])                     | `\d`      | "5"                              |
| `\D`     | Any non-digit (equivalent to [^0-9])                | `\D`      | "a", "%"                         |
| `\w`     | Any word character (alphanumeric + underscore)      | `\w`      | "a", "5", "_"                    |
| `\W`     | Any non-word character                              | `\W`      | "!", " "                         |
| `\s`     | Any whitespace character (spaces, tabs, newlines)   | `\s`      | Space or tab                     |
| `\S`     | Any non-whitespace character                        | `\S`      | Any visible character            |

## Quantifiers

Quantifiers specify how many instances of a character, group, or character class must be present for a match.

| Syntax  | Description                           | Example   | Matches                |
| ------- | ------------------------------------- | --------- | ---------------------- |
| `*`     | 0 or more times                       | `a*`      | "", "a", "aaa"         |
| `+`     | 1 or more times                       | `a+`      | "a", "aaa" (not "")    |
| `?`     | 0 or 1 time (optional)                | `colou?r` | "color", "colour"      |
| `{n}`   | Exactly $n$ times                     | `a{3}`    | "aaa"                  |
| `{n,}`  | $n$ or more times                     | `a{2,}`   | "aa", "aaa", "aaaa..." |
| `{n,m}` | Between $n$ and $m$ times (inclusive) | `a{2,4}`  | "aa", "aaa", "aaaa"    |

## Anchors & Boundaries

Anchors do not match characters; they match positions before or after characters.

| Syntax | Description                                      | Example   | Matches                                       |
| ------ | ------------------------------------------------ | --------- | --------------------------------------------- |
| `^`    | Start of the string (or line, in multiline mode) | `^The`    | "The cat" (at the start)                      |
| `$`    | End of the string (or line, in multiline mode)   | `end$`    | "The end" (at the end)                        |
| `\b`   | Word boundary                                    | `\bcat\b` | "cat" in "the cat sat", but not "concatenate" |
| `\B`   | Non-word boundary                                | `\Bcat\B` | "cat" inside "educate"                        |

## Groups & Alternatives

| Syntax    | Description                                           | Example                  | Matches      |
| --------- | ----------------------------------------------------- | ------------------------ | ------------ |
| `(...)`   | Capturing group                                       | `(ab)+`                  | "ab", "abab" |
| `(?:...)` | Non-capturing group (groups without saving the match) | `(?:un)?do`              | "undo", "do" |
| `         | `                                                     | Alternation (logical OR) | `cat         |

## Escaping Special Characters

To match a character that has special meaning in regex (like `.`, `*`, `?`, or `+`), prefix it with a backslash (`\`).

+ Example: `\.` matches a literal period (`.`).
+ Example: `\?` matches a literal question mark (`?`).
