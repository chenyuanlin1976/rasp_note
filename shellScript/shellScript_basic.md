# Linux shell script

*A Linux shell script is just a text file* containing a sequence of commands that you would normally type into the Linux terminal.  
Instead of typing them one by one, you put them in a file, tell the system it's executable, and run it all at once.

Think of it as a recipe: the shell (the command interpreter) is the chef, and the script is the step-by-step guide to making the dish.

## Anatomy of a Shell Script

```Bash
#!/bin/bash

# This is a comment - it's ignored by the computer.
echo "Starting the backup process..."

# Create a variable
BACKUP_DIR="/var/backups"

# Use a command to do some work
mkdir -p "$BACKUP_DIR"

echo "Backup directory is ready at $BACKUP_DIR!"
```

### The Key Components Explained

+ The Shebang (`#!/bin/bash`): This is always the very first line.  
  The `#!` (called "hash-bang" or "shebang") tells the operating system which interpreter should run this file.  
  `/bin/bash` tells it to use the Bash shell.
+ Comments (`#`): Any line starting with `#` (except the shebang) is a comment.  
  It's there for human eyes only-to explain what the code does.
+ Commands (`echo`, `mkdir`): These are the exact same commands you run in the terminal.  
  `echo` prints text to the screen; `mkdir` makes a directory.
+ Variables (`BACKUP_DIR="/var/backups"`): Variables store data for later use.  
  Note that in Bash, *there must be no spaces around the = sign when assigning a variable*  
  (e.g., `NAME="Alice"`, NOT `NAME = "Alice"`).

## practical guide to the essential syntax

### variable

In Shell scripting, variables are *untyped (they are treated as strings unless specified)*.  
The Golden Rule: **You must NOT put spaces around the equals = sign when assigning a variable**.  

```Bash
# Correct assignment (no spaces!)
name="Albert"
age=25

# Usage: Prefix the variable with a "$"
echo "Hello, my name is $name and I am $age years old."

# Best practice: Use curly braces ${} to avoid ambiguity
echo "File created: ${name}_report.txt"
```

### Conditionals (If-Else)

The syntax for condition checking is `if [ condition ]; then ... fi`  
(yes, fi is just if spelled backward to mark the end of the block).

```Bash
score=85

if [ "$score" -ge 60 ]; then
    echo "You passed!"
else
    echo "Please try again."
fi
```

#### Essential Operators

Because **everything in Bash starts as a string**,  
there are different operators for comparing numbers versus comparing strings:

`-eq`: Equal to
`-ne`: Not equal to
`-gt`: Greater than
`-lt`: Less than
`-ge`: Greater than or equal
`-le`: Less than or equal

#### File and Directory Tests

One of the main strengths of shell scripting is interacting with the filesystem.  
You can easily check if files or directories exist using special flags:

```Bash
LOG_FILE="/var/log/syslog"

# -f checks if a file exists and is a regular file
if [ -f "$LOG_FILE" ]; then
    echo "Log file exists."
fi

# -d checks if a directory exists
if [ -d "/tmp/backup" ]; then
    echo "Backup directory exists."
fi
```

### case statement

Key Syntax Rules:

+ it starts with case and ends with esac (case spelled backward).
+ Each pattern ends with a closing parenthesis `)`.
+ Each block of code must end with a double semicolon `;;` (this acts like the break statement in other languages).
+ The `*)` pattern acts as the default else / default case.

```Bash
case "$variable" in
    pattern1)
        # Commands to run if variable matches pattern1
        ;;
    pattern2)
        # Commands to run if variable matches pattern2
        ;;
    *)
        # Default fallback (wildcard) if no other patterns match
        ;;
esac
```

### Loop

Loops let you repeat actions over lists of items, ranges, or while conditions are met.

#### For Loop (Over a range or list)

```Bash
# Iterating over a list of strings
for fruit in Apple Banana Cherry; do
    echo "I like $fruit"
done

# Iterating over a range of numbers (1 to 5)
for i in {1..5}; do
    echo "Step: $i"
done
```

#### While Loop (Runs while a condition is true)

```Bash
count=1
while [ $count -le 3 ]; do
    echo "Count is $count"
    count=$((count + 1))  # $(( ... )) is used for basic arithmetic
done
```

### Positional Parameters (Arguments)

When you run a script, you can pass arguments to it.  
The script automatically stores these in special numeric variables:

+ `$0`: The name of the script itself.
+ `$1`, $2, ... $9: The 1st, 2nd, up to 9th arguments.
+ `$#`: The total number of arguments passed.
+ `$@`: All arguments as a list.

```Bash
#!/bin/bash
echo "Script name: $0"
echo "First argument (Name): $1"
echo "Second argument (Day): $2"
```

## indentation

Bash does NOT enforce indentation.  
The Linux shell does not care if your code is perfectly aligned or completely flat-it will run the exact same way.  
However, for human readability and sanity, the community has strong style conventions that you should follow.  

### The Golden Rules of Shell Script Indentation

1. Indent Inside Blocks: Any time you open a block of code (like a loop, a conditional statement, or a function),  
   you should indent the code inside it.
   + if ... then blocks
   + for / while loops
   + Function bodies
   + case statements
2. Use 2 Spaces (Recommended) or 4 Spaces: The industry standard (including Google's Shell Style Guide) is to use 2 spaces per indent level.  
   Because shell scripts can get deeply nested with various conditionals and loops,  
   2 spaces keeps the code from shifting too far to the right.  
   However, 4 spaces is also widely accepted. The most important thing is to be consistent throughout your script.
3. Use Spaces, Not Tabs: It is highly recommended to configure your text editor to convert tabs to spaces.  
   If you use raw tabs, your code might look perfectly aligned in your editor,  
   but if someone else opens it in a different terminal or editor with different tab-width settings, the layout can completely break.

## function

Functions allow you to group code into reusable blocks, making your script cleaner, organized, and much easier to read.

### Basic Function Syntax

There are 2 common ways to declare a function in Bash.  
They do the exact same thing, but the first one is the industry standard.
Important: Unlike languages like JavaScript or Python, *you do not use parentheses () when calling a function. You just type its name.*

```Bash
# Style A: The standard way (Recommended)
my_function() {
    # Code goes here
    echo "Hello from the function!"
}

# Style B: Using the 'function' keyword
function another_function {
    echo "This works too!"
}
```

### Passing Arguments to Functions

Functions don't have named parameters in their definitions.  
Instead, they accept arguments using the exact same *positional parameters* (`$1`, `$2`, etc.) that regular scripts use.
**Always use the `local` keyword inside functions.**  
This ensures the variable only exists inside that specific function  
and won't accidentally overwrite a variable with the same name somewhere else in your main script.

```Bash
#!/bin/bash

# Define the function
greet() {
    # Best Practice: Assign positional parameters to local variables 
    # so your code is easier to read.
    local first_name=$1
    local last_name=$2
    
    echo "Hello, $first_name $last_name!"
}

# Call the function (Separate arguments with spaces, NO parentheses)
greet "John" "Doe"
greet "Jane" "Smith"
```

### Returning Values (The Bash Way)

In standard programming, return sends data back.  
**In Bash, return only sends back an exit status code**  
(a number between 0 and 255, where 0 means success and anything else means an error).

If you want to "return" actual data (like a string or a calculated number), you use Command Substitution $().

#### Method A: Returning Success/Failure Status

```Bash
check_file() {
    if [ -f "$1" ]; then
        return 0 # Success
    else
        return 1 # Failure
    fi
}

# Use the function in an if-statement
if check_file "/etc/hosts"; then
    echo "Hosts file exists!"
fi
```

#### Method B: Returning Data (Strings or Numbers)

To capture actual text out of a function, use `echo` inside the function and grab the output when you call it.

```Bash
calculate_square() {
    local number=$1
    local result=$((number * number))
    
    # "Return" the result by printing it
    echo "$result"
}

# Capture the function's output into a variable using $()
output=$(calculate_square 5)

echo "The square of 5 is: $output"
```

## read file content

There are a few different ways to read file content in a shell script, depending on what you want to do with the data.
Here are the 3 most common and practical methods.

### Method 1: Line-by-Line (The Best Practice)

If you need to process a file one line at a time (for example, checking each line for a specific word, or updating config lines),  
use a `while` loop combined with the `read` command and input redirection (`<`).

```Bash
#!/bin/bash

FILE_PATH="users.txt"

# Check if the file exists first
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: $FILE_PATH does not exist."
    exit 1
fi

# Read line-by-line
# 'IFS=' prevents trimming leading/trailing whitespace
# '-r' prevents backslash escapes from being interpreted
while IFS= read -r line; do
    echo "Processing line: $line"
done < "$FILE_PATH"
```

### Method 2: Dump the Whole File (Quick & Simple)

If you don't need to loop through the file line-by-line and just want to display its entire content  
or save it directly into a variable, you can use command substitution with `cat` or the built-in redirection operator.

```Bash
# Option A: Print to the screen
cat "logs.txt"

# Option B: Save the content into a variable
file_content=$(cat "logs.txt")

echo "--- File Content Start ---"
echo "$file_content"
echo "--- File Content End ---"
```

### Method 3: Word-by-Word

If you want to split the file's content by spaces (or words) instead of lines, you can use a basic `for` loop.

```Bash
#!/bin/bash

# This will print every single word in the file on a new line
for word in $(cat words.txt); do
    echo "Word: $word"
done
```

## integer conversion

In Bash, all variables are stored as strings.
The conversion happens **implicitly** when you perform an arithmetic operation or use a numeric comparison.

### The Implicit Way: Arithmetic Evaluation (( ... ))

If a string contains digits, you can *immediately* perform math on it using the double parentheses `$(( ... ))` syntax.  
Bash will automatically treat the string as an **integer**.

```Bash
# Variables defined as strings
num_str1="40"
num_str2="2"

# Bash automatically treats them as numbers inside $(( ))
result=$((num_str1 + num_str2))

echo "The result is: $result" # Outputs: 42
```

### Using declare -i (Explicit Integer Attribute)

If you want to *explicitly* force a variable to behave only as an integer, you can declare it with the `-i` flag.  
Once declared, any value assigned to it is automatically evaluated mathematically.

```Bash
# Declare 'age' as an integer variable
declare -i age

age="20 + 5"  # It will evaluate the math inside the string!
echo "$age"   # Outputs: 25

# If you try to assign non-numeric text, it evaluates to 0
age="hello"
echo "$age"   # Outputs: 0
```

### Safe Practice: Check if a String is a Valid Number First

Before you perform math on a string, it is highly recommended to verify that it actually contains a valid number.  
Otherwise, Bash might throw an error or default it to 0.  
You can do this using a regular expression match (`=~`)

```Bash
user_input="150"

# This regex checks if the string contains only digits (integers)
if [[ "$user_input" =~ ^[0-9]+$ ]]; then
    echo "Valid number! Adding 10..."
    result=$((user_input + 10))
    echo "New value: $result"
else
    echo "Error: '$user_input' is not a valid integer."
fi
```

## What about Decimals (Floats)?

**Standard Bash only supports integers (whole numbers).**  
If you try to do math with a decimal string like "3.14", Bash will throw a syntax error.

To convert and calculate decimal strings,  
you must pipe them to an **external tool** like bc (An Arbitrary Precision Calculator Language).

```Bash
float_str1="5.5"
float_str2="2.1"

# Pipe the math string into 'bc'
result=$(echo "$float_str1 + $float_str2" | bc)

echo "Decimal result: $result" # Outputs: 7.6
```

## equivalent to Python's range

### Brace Expansion (Best for Fixed Ranges)

If your numbers are hardcoded, the cleanest equivalent to Python's range(start, stop, step) is *Brace Expansion ({start..stop..step})*.
Note: Unlike Python's range(), Bash range limits are inclusive (it includes the stop number).

```Bash
# Bash (inclusive, so 1 to 5); equivalent to Python: for i in range(1, 6)
for i in {1..5}; do
    echo "Number: $i"
done
```

+ Adding a Step (Increment): Just like range(0, 11, 2) in Python, you can add a third argument in Bash.

```Bash
# Count by 2s from 0 to 10
for i in {0..10..2}; do
    echo "Even: $i"
done
```

+ Counting Down

```Bash
# Count down from 5 to 1
for i in {5..1}; do
    echo "$i..."
done
```

### The seq Command (Best for Variables)

If your range limits are stored in variables (e.g., START and END),  
Brace Expansion will not work because Bash evaluates braces before expanding variables.  
Instead, use the `seq` (sequence) command

```Bash
START=1
END=5

# seq [start] [end]
for i in $(seq $START $END); do
    echo "Number: $i"
done
```

+ Adding a Step with `seq`: The syntax is slightly different: `seq [start] [step] [end]`.

```Bash
# Count by 5s from 0 to 20
for i in $(seq 0 5 20); do
    echo "Val: $i"
done
```

### Three-Expression C-Style Loop (Alternative)

If you prefer a highly readable programmatic style that natively supports variables without spawning an external process (like seq),  
use the C-style double-parentheses loop.

```Bash
LIMIT=5

# for ((initialization; condition; increment))
for ((i=1; i<=LIMIT; i++)); do
    echo "Number: $i"
done
```

## fundamental tools

### read

`read` is the standard way to **accept user input or parse files**, Useful Flags for `read`:

+ `-p` (Prompt): Lets you write the prompt text directly in the read command, saving you an echo line.
+ `-s` (Silent): Hides the input as the user types (perfect for passwords).
+ `-n` (Character limit): Automatically submits after a certain number of characters.
+ `-t` (Timeout): Stops waiting after a set number of seconds.

```Bash
echo "Enter your name: "
read name
echo "Hello, $name!"

# -p puts the prompt on the same line
read -p "Username: " username

# -s hides password input
read -s -p "Password: " password
echo "" # Prints a newline since hidden input doesn't create one

# -t 5 waits only 5 seconds
read -t 5 -p "Press Enter to continue (5s timeout)..."

read -p "Enter your first and last name: " first last
echo "First: $first"
echo "Last: $last"
```

### expr

`expr` (expression) is an external program used to perform manual arithmetic operations, string manipulations, or comparisons.  
Important Syntax Note: Unlike normal Bash assignments, you must put spaces between the operators and arguments in expr, otherwise it will treat them as a single string.

+ Basic Arithmetic with `expr`

```Bash
# Add 5 and 10 (Notice the spaces!)
result=$(expr 5 + 10)
echo "5 + 10 = $result" # Outputs: 15

# Multiplication requires escaping the * character
# (otherwise the shell thinks * means "all files in current directory")
mul=$(expr 10 \* 3)
echo "10 * 3 = $mul" # Outputs: 30
```

+ `expr` also has some built-in string utilities:

```Bash
str="hello_world"

# 1. Get length of string
len=$(expr length "$str")
echo "Length: $len" # Outputs: 11

# 2. Extract substring (expr substr [string] [start_index] [length])
# Note: expr uses 1-based indexing!
sub=$(expr substr "$str" 1 5)
echo "Substring: $sub" # Outputs: hello
```

#### Modern Alternative to `expr`

While `expr` is still useful for compatibility with old Unix shells, it is an external program, which makes it slower.  
In modern Bash, it is highly recommended to use the built-in **double-parentheses** `$(( ... ))` for math instead.  
It is faster, cleaner, and doesn't require escaping the `*` character:

```Bash
# The old 'expr' way:
result=$(expr 5 + 10)
mul=$(expr 10 \* 3)

# The modern Bash way (preferred):
result=$((5 + 10))
mul=$((10 * 3))
```
