# awk - pattern scanning and text processing language

<https://invisible-island.net/mawk/manpage/mawk.html>

Awk is a **scripting language** used for **manipulating data and generating reports**.  
The awk command programming language requires no compiling and allows the user to use variables, numeric functions, string functions, and logical operators.  

Awk is a utility that enables a programmer to write tiny but effective programs in the form of statements  
that define text **patterns** that are to be searched for in each line of a document  
and the **action** that is to be taken when a match is found within a line.  

Awk is mostly used for pattern scanning and processing.  
It searches one or more files to see if they contain lines that matches with the specified patterns and then perform the associated actions.  

AWK is a data-driven scripting language originally designed for **pattern searching and text manipulation**.  
It requires no compilation and allows us to use variables, functions, and logical operators.  
The AWK language has different **interpreters** like awk, nawk, gawk, and mawk on different operating systems.

## syntax

`awk options 'pattern {action }' inputfile > outputfile`  

| Option  | Description                       |
|---------|-----------------------------------|
| -F      | Sets a custom field separator     |
| -f      | Reads awk program from a file     |
| '{}'    | Encloses action to take on match  |

## WHAT CAN WE DO WITH AWK

1. AWK Operations:
    + Scans a file line by line
    + Splits each input line into fields
    + Compares input line/fields to pattern
    + Performs action(s) on matched lines

1. Useful For:
    + Transform data files
    + Produce formatted reports

1. Programming Constructs:
    + Format output lines
    + Arithmetic and string operations
    + Conditionals and loops

## Examples

1. Print All Lines (Default Behavior)  
    `awk '{print}' filename`
1. Search Lines with a Keyword  
    `awk '/hello/ {print}' filename`

1. Print Specific Columns  
   For each line, the awk command splits the line **delimited by space character** by default and stores it in the $n variables.  
   If the line has 4 words, it will be stored in $1, $2, $3 and $4 respectively. Also, $0 represents the whole line.  
    `awk '{print $1,$4}' filename`  
    `ls -l | awk '{print $1,$NF}'`  
    `ls -l | awk '{print $1,"filename="$9}'`  
    `ps | awk {print $1}`

## Built-In Variables In Awk

Awk's built-in variables include the field variables $1, $2, $3, and so on ($0 is the entire line), that break a line of text into individual words or pieces called fields.

+ **NR**: NR command keeps a current count of the number of input records. Remember that records are usually **lines**.  
  Awk command performs the pattern/action statements once for each record in a file.  
+ **NF**: NF command keeps a count of the number of fields within the current input record.  
+ **FS**: FS command contains the field separator character which is used to divide fields on the input line.  
  The default is "white space", meaning space and tab characters. FS can be reassigned to another character (typically in BEGIN) to change the field separator.  
+ **RS**: RS command stores the current record separator character. Since, by default, an input line is the input record, the default record separator character is a newline.  
+ **OFS**: OFS command stores the output field separator, which separates the fields when Awk prints them.  
  The default is a blank space. Whenever print has several parameters separated with commas, it will print the value of OFS in between each parameter.  
+ **ORS**: ORS command stores the output record separator, which separates the output lines when Awk prints them.  
  The default is a newline character. print automatically outputs the contents of ORS at the end of whatever it is given to print.  

### examples

+ Display Line Number  
    `awk '{print NR,$0}' filename`
+ Display 1st and Last Field  
    `awk '{print $1,$NF}' filename`
+ Display Line From 3 to 6  
    `awk 'NR==3, NR==6 {print NR,$0}' filename`
+ To find the length of the longest line present in the file  
    `awk '{ if (length($0) > max) max = length($0) } END { print max }' filename`
+ To count the lines in a file  
    `awk 'END { print NR }' filename`
+ Printing lines with more than 10 characters  
    `awk 'length($0) > 10' filename`
+ To find/check for any string in any specific column  
    `awk '{ if($3 == "B6") print $0;}' filename`
+ To print the squares of first numbers from 1 to n say 6  
    `awk 'BEGIN { for(i=1;i<=6;i++) print "square of", i, "is",i*i; }'`
+ Print the line if file size > 1M
    `ls -l | awk '{if ($5 > 1000000) print $NF}'`
