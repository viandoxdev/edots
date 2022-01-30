#!/bin/bash

# function that returns the gaps a workspace should have
# take in the old gaps 
new_gaps() {
	case "$1" in
		"20")
			printf "5"
			;;
		"5")
			printf "0"
			;;
		"0")
			printf "20"
			;;

		*) # default value
			printf "20"
			;;
	esac
}

mkdir -p /tmp/sw_gaps

# current workspace's id
current="$(swaymsg -t get_workspaces | jq '.[] | select(.focused==true) | .id')"
current_file="/tmp/sw_gaps/$current"
# current workspace's gap
current_gaps="$(new_gaps)"
if [ -f "$current_file" ]; then
	current_gaps="$(cat $current_file)"
fi
gaps="$(new_gaps "$current_gaps")"

swaymsg gaps inner current set "$gaps"
swaymsg gaps inner "$gaps"
printf "$gaps" > "$current_file"

