# sed

## What is the Sed Command

**Stream editor** for filtering and transforming text.  
Sed is used for both simple and complex text transformations,  
such as **finding and replacing, inserting, or deleting text**.  
It's commonly used in shell scripts to automate file editing tasks.

## Sed Command Syntax

`sed [OPTIONS] 'COMMAND' [INPUTFILE...]`

Commonly Used SED Command Options:

| Option  | Description                             |
|---------|-----------------------------------------|
| -i      | Edit the file in-place (overwrite)      |
| -n      | Suppress automatic printing of lines.   |
| -e      | Allows multiple commands.               |
| -f      | Reads sed commands from a file.         |
| -r      | Use extended regular expressions.       |

## Examples of sed

### Replace - s

1. Replaces the word "unix" with "linux" in the file  
    `sed 's/unix/linux/' filename > outputfile`  
    `sed -i 's/unix/linux/' filename`

1. To replace **only the nth occurance** of a word in a line  
    `sed 's/unix/linux/n' filename`
1. Replacing all the Occurrence of the Pattern in a Line  
    `sed 's/unix/linux/g' filename`  
1. Replacing **from nth Occurrence** to all Occurrences in a Line  
    `sed 's/unix/linux/3g' filename`  

1. Parenthesize First Character of Each Word  
    `echo "Welcome To Taiwan" | sed 's/\(\b[A-Z]\)/\(\1\)/g'`  

1. Duplicating the Replaced Line with /p flag  
    `sed 's/unix/linux/p' filename`  
1. Printing Only the Replaced Lines  
    `sed -n 's/unix/linux/p' filename`

1. Replacing String on a Specific Line Number  
    `sed '3 s/unix/linux/' filename`
1. Replacing String on a Range of Lines  
    `sed '1,3 s/unix/linux/' filename`  

### Delete - d

1. To Delete a particular line say n in this example  
    `sed 'nd' filename`  
1. To Delete a last line  
    `sed '$d' filename`  
1. To Delete line from range x to y
    `sed 'x,yd' filename`
1. To Delete from nth to last line  
    `sed 'nth,$d' filename`
1. To Delete pattern matching line  
    `sed '/pattern/d' filename`

### Insert - i,a

1. Insert text before line 3  
    `sed '3i\new text' filename`
1. Insert text after line 3  
    `sed '3a\new text' filename`

### Regular Expressions - r

SED supports regular expressions that allows it to handle more complex pattern matching.  
To enable regular expressions, you need to use -r option

`sed -r 's/\bu\w+/Linux/g' filename`  
