# shell script demo

## variable

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

## if

```bash
x=17
y=23

if [ $x == $y ]; then
  echo "x is equal to y"
fi

if [ $x != $y ]; then
  echo "x is not equal to y"
fi
```

## if, elif

```bash
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

## for loop

```bash
MEMBERS="Steven Tom Lisa Sandy"

for i in $MEMBERS
do
  echo $i
done 
```

```bash
for p in 2 3 5 7 11; do
  echo "prime number: $p"
done
```

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

## until loop

```bash
count=1
until [ $count -gt 5 ]; do
  echo "Count: $count"
  count=`expr $count + 1`
done
```

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
