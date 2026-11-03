#!/usr/bin/env bash
# Sum the first column of a file (integers). Lines whose first field isn't an integer are skipped.
# Usage: sumup_1st_col.sh <file>
# For decimals use awk instead:  awk '{ s += $1 } END { print s }' file

set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -r "$1" ]; then
    echo "usage: $0 <readable file>" >&2
    exit 2
fi

sum=0
# '|| [ -n "$col1" ]' also handles a last line without a trailing newline
while read -r col1 _ || [ -n "${col1:-}" ]; do
    if [[ $col1 =~ ^-?[0-9]+$ ]]; then
        sum=$((sum + col1))
    fi
done < "$1"

echo "$sum"
