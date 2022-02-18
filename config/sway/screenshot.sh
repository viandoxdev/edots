#!/bin/sh
if sel="$(
	swaymsg -t get_tree | \
	jq -r '.. | (.nodes? // empty)[] | select(.pid and .visible) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | \
	slurp -B ffffff11 -b 00000000 -c ffffffaa -s ffffff11 -w 1
)"; then
	grim -g "$sel" - | tee ~/pictures/screenshots/"$(date +'%F.%k.%M.%S.%N.png')" | wl-copy
fi
