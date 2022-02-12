#!/bin/bash

case "$1" in
	"raise")
		amixer sset Master 2%+
		;;
	"lower")
		amixer sset Master 2%-
		;;
	"toggle")
		amixer sset Master toggle
		;;
	*)
		exit 1
		;;
esac


volume="$(amixer sget Master | awk -F'[%[]' '/^\s*Front Left/ {print $2}')"
active="$(amixer sget Master | awk -F'[][]' '/^\s*Front Left/ {print $4}')"

# open volume window if not already open
eww windows | grep '^\*volume$' >/dev/null 2>&1 || eww open volume
eww update volume-duration="0s"
eww update volume-visible=true
eww update volume-duration="4s"

eww update volume-value="$volume"

if [ "$active" = "on" ]; then
	# shellcheck disable=SC2194
	case 1 in
		$((volume <= 0)))
			eww update volume-icon="󰝟"
			;;
		$((volume <= 5)))
			eww update volume-icon="󰕿"
			;;
		$((volume <= 20)))
			eww update volume-icon="󰖀"
			;;
		*)
			eww update volume-icon="󰕾"
			;;
	esac
else
	eww update volume-icon="󰖁"
fi

(
# unique identifier, as long as this script isn't called twice in the same nanosecond
id="$(date +%s.%N | tee /tmp/dots_volume)"
# /tmp/dots_volume holds the id of the last instance of this script that wrote it there

# whichever one has its id there takes control of the volume window. The file is read by
# other instances to know if they still control the window or not.

sleep 1

# exit if we lost the control
[ "$id" = "$(cat /tmp/dots_volume)" ] || exit
eww update volume-visible=false

sleep 4

# same but later
[ "$id" = "$(cat /tmp/dots_volume)" ] || exit
eww close volume
) &
