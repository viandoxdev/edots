#!/bin/bash

# this script helps in switching the current week in eww, by setting the correct vars at the right time

wt=0
timeout=50 # 5 seconds
if [ -f "/tmp/_ctrb_transition_lock" ]; then
	while [ -f "/tmp/_ctrb_transition_lock" ] && [ "$wt" -lt "$timeout" ]; do
		sleep 0.1
		wt=$((wt + 1))
	done
fi

# if it still exists after that, just remove it
[ -f "/tmp/_ctrb_transition_lock" ] && rm /tmp/_ctrb_transition_lock

# transition duration
duration=$(eww get GH_CTRB_TRANSITION_DURATION 2>/dev/null || echo "250")
# same but in a format sleep can parse
duration_sleep=$(bc -l <<< "$duration / 1000")
# the current week's index (0 -> now, 1...n -> n weeks ago)
week=$(eww get gh-ctrb-week 2>/dev/null || echo "0")
# min week index
min="0"
# maw week index
max="$(eww get gh-ctrb 2>/dev/null | jq '.length' 2>/dev/null || echo "53")"
# first command returns the number of weeks, so -1 for the max index
max=$((max - 1))

(
# lock
echo "" > /tmp/_ctrb_transition_lock
case "$1" in
	"next")
		week=$((week - 1))
		if [ "$week" -ge "$min" ]; then
			eww update gh-ctrb-transition="slideright"

 			# cover middle with right
			eww update gh-ctrb-reveal="right"
			sleep "$duration_sleep" # wait for it to finish

			# update middle (hidden)
			eww update gh-ctrb-week="$week"
			sleep 0.1 # wait for it to finish

			# invisibly replace right with middle
			eww update gh-ctrb-transition-duration="0s"
			eww update gh-ctrb-reveal="center"

			# reset duration
			eww update gh-ctrb-transition-duration="${duration}ms"
		fi
		;;
	"previous")
		week=$((week + 1))
		if [ "$week" -le "$max" ]; then
			eww update gh-ctrb-transition="slideleft"
			
			# cover middle with left
			eww update gh-ctrb-reveal="left" # 
			sleep "$duration_sleep" # wait for it to finish
			
			# update middle (hidden)
			eww update gh-ctrb-week="$week"
			sleep 0.1

			# invisibly replace left with middle
			eww update gh-ctrb-transition-duration="0s"
			eww update gh-ctrb-reveal="center" # (middle replaces left)

			# reset duration
			eww update gh-ctrb-transition-duration="${duration}ms"
		fi
		;;
	"day")
		# $2 is index
		[ -z "$2" ] || eww update gh-ctrb-day-current="$2"
		;;
	*)
		;;
esac

day="$(eww get gh-ctrb-day-current 2>/dev/null || 0)"
# date of selected day in YYYY-MM-DD format
date="$(eww get gh-ctrb | jq -r ".data[$week][$day].date")"
# update data about selected day
~/dots/config/eww/sh/contributions.sh "$date"

next_week=$((week - 1 <  0  ?  0  : week - 1))
last_week=$((week + 1 > max ? max : week + 1))

# prepare left and right to have them ready when switching.
eww update gh-ctrb-week-right="$next_week"
eww update gh-ctrb-week-left="$last_week"
sleep 0.1
# unlock
rm /tmp/_ctrb_transition_lock
) &
