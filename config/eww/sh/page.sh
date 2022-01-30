#!/bin/bash

# yes this is entirely doable in yuck, and doesn't require bash,
# but it does weird things in yuck so bash it is.

# In yuck, there seems to be race conditions when clicking a button that
# updates a var depending on its value, leading it to sometime
# activate twice, which made the page naviguation pretty much
# random.

current=$(eww get sidebar-page)
max=$(eww get sidebar-page-max)

case "$1" in
	"next")
		if [ "$((current + 1))" -gt "$max" ]; then
			eww update sidebar-page=0
		else
			eww update sidebar-page="$((current + 1))"
		fi
		;;
	"previous")
		if [ "$((current - 1))" -lt "0" ]; then
			eww update sidebar-page="$max"
		else
			eww update sidebar-page="$((current - 1))"
		fi
		;;
	"last")
		eww update sidebar-page="$max"
		;;
	"first")
		eww update sidebar-page=0
		;;
	*)
		;;
esac
