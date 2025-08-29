# shell script brackets

<https://dev.to/rpalo/bash-brackets-quick-reference-4eh6>

## Bash Brackets Quick Reference

Bash has lots of different kinds of brackets.  
Like, many much lots. It adds meaning to doubling up different brackets,  
and **a dollar sign in front** means something even more different.  
And, the brackets are used differently than many other languages.  

A tiny note on all of these is that Bash generally likes **to see a space between round or square brackets and whatever's inside**.  
It doesn't like space where curly braces are concerned. We'll go through in order of net total squigglyness.

---

## Catalog

+ [Parenthesis](#parenthesis-)
+ [Square brackets](#square-brackets-)
+ [Curly braces](#curly-braces-)

---

## Parenthesis ()

### Single parenthesis ( command )

+ **Subshell Execution**: Commands within single parentheses are executed in a subshell, meaning variables and environment changes made inside are not persistent in the parent shell.
+ **Command Grouping**: Group commands to redirect their collective output or manage their execution flow.

This means that they run through all of the commands inside, and then return a single exit code.

```bash
a='This string'
( a=banana; mkdir $a )
echo $a
ls
```

### Dollar single parentheses $( command )

**Command Substitution**: The output of the command(s) inside is captured and substituted into the surrounding command line.  
This is for interpolating a subshell command output into a **string**.  
The command inside gets run inside a subshell, and then any output gets placed into whatever string you're building.

```bash
intro="My name is $( whoami )"
echo $intro
```

The following code block takes the output from COMMAND and creates an **array-variable** from it.

```bash
var=$( ls )
echo $var
```

```bash
fruits=("apple" "lemon" "banana" "cherry" "kiwi")
echo ${#fruits[@]}
for i in ${fruits[@]}; do
  echo "$i"
done
array=("123" "456" "789")
echo ${array[1]}
```

### Dollar single parentheses dollar question mark $( command )$?

If you want to interpolate a command, but only the exit code and not the value, this is what you use.

`echo $( grep -q PATTERN FILE )$?`

### Angle parentheses <( stuff ) is known as a process substitution

It's a lot like a pipe, except you can use it anywhere a command expects a **file argument**.

`sort -nr -k 5 <( ls -l /bin ) <( ls -l /usr/bin ) <( ls -l /sbin )`

### Double parentheses (( arithmetic ))

**Arithmetic Evaluation**: Used for **integer arithmetic** operations.  
Variables are treated as integers, and various arithmetic and boolean operators are supported.  
The exit status is 0 if the arithmetic result is non-zero, and 1 if it's zero.  

You can perform assignments, logical operations, and mathematic operations like multiplication or modulo inside these parentheses.  
However, do note that **there is no output**.  
**Any variable changes that happen inside them will stick**, but don't expect to be able to assign the result to anything.

```bash
i=7
(( i += 3 ))
echo $i
```

### Dollar double parentheses $(( arithmetic ))

**Arithmetic Expansion**: Performs arithmetic operations and substitutes the numerical result into the command line.  
you can use Dollar Double Parentheses $((  )) to perform an Arithmetic Interpolation,  
which is just a fancy way of saying, "**Place the output result into this string**."

```bash
legs=100
message="rabbit number is $(( legs / 4 ))"
echo $message
```

---

## Square brackets []

### Single square brackets [  ]

**Conditional Expressions (Test Command)**: Used for basic conditional tests, including string comparisons, numerical comparisons, and file tests. This is POSIX compliant.
Strings of zero length are false.  
Strings of length one or more are true. (even if those characters are whitespace)
One last thing that's important to note is that `test` and `[` are actually shell commands.

```bash
if [ -f fileName ]; then
  echo "file exists"
else
  echo "file NOT exists"
fi
```

### Double square brackets [[  ]]

**Extended Conditional Expressions**: Offers more advanced features than single square brackets,  
including extended regular expression matching (=~), pattern matching, and locale-aware string comparisons (<, >). This is a Bash-specific extension.

```bash
name="John Doe"
if [[ "$name" == J*Doe ]]; then
  echo "Name matches pattern."
fi
```

---

## Curly Braces {}

### Single curly braces

+ **Parameter Expansion**: Used to delimit variable names, especially when concatenating with other characters, e.g., ${var}suffix.
+ **Brace Expansion**: Generates sequences of strings, e.g., {a,b,c} expands to a b c.
+ **Command Grouping (without subshell)**: Groups commands for redirection or flow control without creating a subshell, so variables and environment changes persist in the current shell.

`echo h{a,e,i,o,u}p`  
`echo {01..10}`

```bash
sum=0
for i in {1..100}; do
  (( sum=$sum+i ))
done
echo $sum
```

### dollar curly braces ${contents}

Note that there are **no spaces around the contents**.  
This is for variable interpolation. You use it when normal string interpolation could get weird.

```bash
fruit=banana
echo $fruitification
echo ${fruit}ification
echo {0..10..2}
```

The other thing you can use it for is variable manipulation.

```bash
function Greeting() {
  echo "Hello, ${1:-World}!"
}
Greeting Ryan
```
