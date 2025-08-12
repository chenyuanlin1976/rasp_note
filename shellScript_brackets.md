# shell script brackets

## Bash Brackets Quick Reference

Bash has lots of different kinds of brackets.  
Like, many much lots. It adds meaning to doubling up different brackets,  
and **a dollar sign in front** means something even more different.  
And, the brackets are used differently than many other languages.  

A tiny note on all of these is that Bash generally likes **to see a space between round or square brackets and whatever's inside**.  
It doesn't like space where curly braces are concerned. We'll go through in order of net total squigglyness.

## parenthesis

### Single parenthesis () will run the commands inside in a *subshell*

This means that they run through all of the commands inside, and then return a single exit code.

```bash
a='This string'
( a=banana; mkdir $a )
echo $a
ls
```

### Double Parentheses ((  )) is for use in *integer arithmetic*

You can perform assignments, logical operations, and mathematic operations like multiplication or modulo inside these parentheses.  
However, do note that **there is no output**.  
Any variable changes that happen inside them will stick, but don't expect to be able to assign the result to anything.

```bash
i=7
(( i += 3 ))
echo $i
```

### Angle Parentheses <( stuff ) is known as a process substitution

It's a lot like a pipe, except you can use it anywhere a command expects a file argument.

`sort -nr -k 5 <( ls -l /bin ) <( ls -l /usr/bin ) <( ls -l /sbin )`

### Dollar Single Parentheses $( command )

This is for interpolating a subshell command output into a string.  
The command inside gets run inside a subshell, and then any output gets placed into whatever string you're building.

```bash
intro="My name is $( whoami )"
echo $intro
```

### Dollar Double Parentheses $((  ))

you can use Dollar Double Parentheses $((  )) to perform an Arithmetic Interpolation,  
which is just a fancy way of saying, "Place the output result into this string."

```bash
legs=100
message="rabbit number is $(( legs / 4 ))"
echo $message
```

## Square Brackets

### Single Square Brackets [  ]

This is an alternate version of the built-in `test`.  
The commands inside are run and checked for "truthiness."  
Strings of zero length are false.  
Strings of length one or more are true. (even if those characters are whitespace)
One last thing that's important to note is that `test` and `[` are actually shell commands.

`[[  ]]` is actually part of the shell language itself.
What this means is that the stuff inside of Double Square Brackets **isn't treated like arguments**.  
The reason you would use **Single Square Brackets** is if you need to do word splitting or filename expansion.

```bash
if [ -f fileName ]; then
  echo "file exists"
else
  echo "file NOT exists"
fi
```

```bash
#touch xxx.txt
#touch yyy.txt
[ -f *.txt ]; echo $?
[[ -f *.txt ]]; echo $?
```

### Double Square Brackets [[  ]]

**True/false testing.**  
Double square brackets support extended regular expression matching.  
Use quotes around the second argument to force a raw match instead of a regex match.

## Curly Braces

### Single curly braces

Single curly braces {} are used for expansion.

`echo h{a,e,i,o,u}p`  
`echo {01..10}`

### dollar curly braces ${contents}

Note that there are **no spaces around the contents**.  
This is for variable interpolation. You use it when normal string interpolation could get weird.

```bash
fruit=banana
echo $fruitification
echo ${fruit}ification
```

The other thing you can use it for is variable manipulation.

```bash
function Greeting() {
  echo "Hello, ${1:-World}!"
}
Greeting Ryan
```
