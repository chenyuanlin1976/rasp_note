#!/bin/bash

sum=0
while read -r col1 rest; do
    sum=$((sum + col1))
done < $1
echo $sum
