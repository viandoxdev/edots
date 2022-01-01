#!/bin/bash

# courtesy of https://stackoverflow.com/a/40608559

s=$(date +@%s)
d=$(date -d $s +%e)

case $d in
    1?) d=${d}th ;;
    *1) d=${d}st ;;
    *2) d=${d}nd ;;
    *3) d=${d}rd ;;
    *)  d=${d}th ;;
esac
res="$(date -d $s "+%A, %B $d %Y")"
echo "{\"value\":\"$res\",\"length\":${#res}}"
