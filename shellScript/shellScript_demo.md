# shell script demo

## variable

```bash
a=123456789
echo ${a:1:3}
echo ${#a}
```

```bash
# comments
VAR="hello world"
echo $VAR
echo ${VAR}
unset VAR
echo $VAR
```

```bash
sum=`expr 10 + 6`
echo "Sum: $sum"
```

```bash
greet="Hello World"
$ echo ${greet/World/$(whoami)}
```

## spaces and tab

Spaces are the overwhelming modern standard for indentation in Linux shell scripting,  
though tabs possess a single specialized syntactic advantage.

Major industry style guides, such as the widely followed **Google Shell Style Guide**,  
explicitly mandate **using 2 spaces per indentation level** and forbid the use of physical tab characters.

## export variables

+ **An exported variable is undefined outside your script**
+ When you run a Linux script normally, **a script executes inside a temporary child shell process**,  
  and **environment variables can only pass downward to child processes, never upward to the parent shell**  
+ When your script finishes executing, that child subshell dies, along with any variables defined or exported inside it.

## common problems: export variables are not defined

1. You executed the script instead of sourcing it.
   + Run the script using the `source` command or the `dot operator`.  
     This forces the script to run inside your current terminal session.
     + `source ./script.sh`
     + `. ./script.sh`

2. For security reasons, **sudo strips out most environment variables and runs in a completely separate, clean privilege environment.**
   + Fix: Use the -E flag to explicitly pass your current environment variables through the sudo barrier.
     + `sudo -E ./script.sh`

## single or double quotes

+ single quotes (') preserve the literal value of all characters,  
  + `dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n`
+ double quotes (") allow the evaluation of variables, command substitutions, and specific backslash escapes.

## operation

### Addition

```bash
count=1
count=$(($count+1))
echo "counter=$count"
```

### Subtraction

```bash
n=3
n=$(($n-1))
echo "num=$n"
```

### Multiplication

```bash
n=3
n2=$(($n*5))
echo "number=$n2"
```

### Division

```bash
n=24
n3=$(($n/3))
echo "number=$n3"
```

## multi condition

And: [ condition_1 ] && [ condition_2 ]  
Or : [ condition_1 ] || [ condition_2 ]

```bash
var_a=17
if [ $var_a -ge 13 ] && [ $var_a -le 19 ]; then
  echo "He is a teenager"
else
  echo "He is not a teenager"
fi
```

## common conditions

### file existence

| options | check point |
| --- | --- |
| -e fileName | if file exists |
| -f fileName | if filename exists and is file |
| -d fileName | if filename exists and is directory |
| -x fileName | if filename exists and is executable |
| -L fileName | if filename exists and is soft-link |
| -S fileName | if filename exists and is socket |

```bash
if [ -f filename ]; then
  echo "file exists"
fi
```

### two numbers

| condition | description |
| --- | --- |
| "$a" -eq "$b" | if two number equal |
| "$a" -ne "$b" | if two number not equal |
| "$a" -gt "$b" | if a is larger than b |
| "$a" -ge "$b" | if a is larger or equal to b |
| "$a" -lt "$b" | if a is small than b |
| "$a" -le "$b" | if a is small or equal to b |

### string comparison

| condition | description |
| --- | --- |
| "$str1" == "$str2" | if two strings equal |
| "$str1" != "$str2" | if two strings not equal |
| -n "$str1" | if string length is not 0 |
| -z "$str1" | if string length is 0 |

---

## if

```bash
x="apple"
y="lemon"
if [ $x == $y ]; then
  echo "x is equal to y"
fi

if [ $x != $y ]; then
  echo "x is not equal to y"
fi
```

## if, elif

```bash
x=17
y=23
if [ $x -gt $y ]; then
  echo "x is greater than y"
elif  [ $x -lt $y ]; then
  echo "x is less than y"
fi
```

## if, else

```bash
if [ $x -ge $y ]; then
  echo "x is greater or equal than y"
else
  echo "x is less than y"
fi

if [ $x -le $y ]; then
  echo "x is less or equal than y"
else
  echo "x is greater than y"
fi
```

---

## case

```bash
var=1
case $var in
  1) echo "Value 1"
    ;;
  2) echo "Value 2"
    ;;
  3) echo "Value 3"
    ;;
  *) echo "out of case"
    exit 1
esac 
```

```bash
language='Python'

case $language in
  Java*)
    echo "language is Java"
    ;;
  Python*)
    echo "language is Python"
    ;;
  C*)
    echo "language C"
    ;;
  *)
    echo "not match"
esac
```

---

## for loop

```bash
for (( i=1; i<=5; i=i+1 )); do
  echo "$i"
done
```

```bash
SUM=0
for (( i=1; i<=5; i++ )); do
  SUM=$(( ${SUM} + ${i} ))
done
echo "SUM=${SUM}"
```

```bash
MEMBERS="Steven Tom Lisa Sandy"

for i in $MEMBERS; do
  echo $i
done 
```

```bash
for p in 2 3 5 7 11; do
  echo "prime number: $p"
done
```

---

## while loop

```bash
count=1
while [ $count -le 5 ]; do
  echo "Count: $count"
  ((count++))
done
```

```bash
counter=0
while [ $counter -le 5 ]; do
  counter=`expr $counter + 1`
  echo $counter
done
```

---

## until loop

```bash
count=1
until [ $count -gt 5 ]; do
  echo "Count: $count"
  count=`expr $count + 1`
done
```

---

## check exist

```bash
if [ -f fileName ]; then
  echo "file exists"
elif [ -d dirName ]; then
  echo "directory exists"
elif [ -e fileName ]; then
  echo "Exists"
else
  echo "NONE"
fi

```

## check rwx attributes

```bash
if [ -r sample.sh ]; then
  echo "file is readable"
fi
if [ -w sample.sh ]; then
  echo "file is writable"
fi
if [ -x sample.sh ]; then
  echo "file is executable"
fi
```

## function

```bash
function funcExample() {
  echo "filename=${0}, args: ${1}, ${2}!!"
}

funcExample 'world' 'rock'
```

## delay

`sleep 1s`

## read line by line

IFS is Internal Field Separator.

```bash
while IFS= read -r line; do
  echo "$line"
done < "inputFile"
```

```bash
while IFS=":" read -r f1 f2; do
  echo "key: " $f1
  echo "val: " $f2
done < inputFile
```

## mass rename

```bash
count=1
fns=$( ls | grep -e ".jpg$" )
for file in $fns; do
  new_name=$( printf "%03d" "$count" )
  (( count= count + 1 ))
  mv "$file" "${new_name}.jpg"
done
```
