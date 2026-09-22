# single or double quotes

When working with shell scripts and regular expressions (regex),  
the difference between double quotes (`""`) and single quotes (`''`) boils down to expansion, interpretation, and literal values.

## In Shell Scripts (Bash / Sh)

In the shell, quotes control how characters and variables are interpreted before a command is executed.

### Single Quotes ('' - Strong Quoting):

+ Literal preservation: **Everything inside single quotes is treated as a literal string**.
+ **No expansion**: Variable interpolation (e.g., `$VAR`), command substitution (e.g., `$(pwd)`), and backslashes **lose** their special meaning.
+ Example: `echo '$USER'` will literally output $USER, not your username.

### Double Quotes ("" - Weak Quoting):

+ **Allows expansion**: Variables and command substitutions inside double quotes are evaluated and expanded.
+ **Preserves spaces**: It prevents word splitting and globbing `(wildcards like *)`, keeping spaces intact within the argument.
+ Example: `echo "Hello, $USER"` will output your actual username.

## In Regular Expressions (Regex)

Regular expressions themselves do **NOT** have a built-in syntactic distinction between single and double quotes -  
they are just treated as literal characters unless part of a specific tool or programming language's string syntax.

However, how you pass a regex into a command-line tool matters significantly:

### Using Single Quotes for Regex in Shell:

+ Best practice: **Always** use single quotes for **regex patterns** in the terminal (e.g., `grep 'a[0-9]*' file.txt`).
+ Why: Regex often uses special characters like `*, $, ?, and [ ]` that the shell also uses for globbing or variables.  
  Single quotes protect these characters from being interpreted by the shell, passing the raw regex pattern directly to the tool.

### Using Double Quotes for Regex in Shell:

+ Use double quotes **only if** you need to dynamically inject a shell variable into your regex pattern.
+ Example: `grep "$pattern" file.txt` will expand the variable `$pattern` before running grep.

## Quick Reference

| Context                     | Single Quotes (`''`)                     | Double Quotes (`""`)                    |
| --------------------------- | ---------------------------------------- | --------------------------------------- |
| Shell Variables             | Ignored (treated as literal text `$VAR`) | Expanded (replaced with variable value) |
| Special Characters (`*, ?`) | Treated as literal characters            | Note_1                                  |
| Best Use for Regex          | Note_2a                                  | Note_2b                                 |

Note_1: Treated as literal characters, but shell variables/command substitutions still expand
Note_2a: Default choice for patterns to protect special regex characters from the shell
Note_2b: Use only when you need to embed shell variables inside the pattern
