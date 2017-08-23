#! /bin/sh

ext="${1:-png}"

for i in *.dot
do
  output="`basename "$i" .dot`.${ext}"
  echo "$i -> ${output}" >&2
  dot -T"${ext}" "$i" > "${output}"
done
