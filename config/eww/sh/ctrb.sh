#!/bin/bash

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

duration=$(eww get GH_CTRB_TRANSITION_DURATION 2>/dev/null || echo "250")
duration_sleep=$(bc -l <<< "$duration / 1000")
week=$(eww get gh-ctrb-week 2>/dev/null || echo "0")
min="0"
max="$(eww get gh-ctrb 2>/dev/null | jq '.length' 2>/dev/null || echo "53")"
max=$((max - 1))

(
# lock
echo "" > /tmp/_ctrb_transition_lock
case "$1" in
	"next")
		week=$((week - 1))
		if [ "$week" -ge "$min" ]; then
			eww update gh-ctrb-transition="slideright"
			eww update gh-ctrb-reveal="right" # (right covers middle)
			sleep "$duration_sleep" # wait for it to finish
			eww update gh-ctrb-week="$week"
			eww update gh-ctrb-transition-duration="0s"
			sleep 0.1 # wait for hidden middle to update
			eww update gh-ctrb-reveal="center" # (middle replaces right)
			eww update gh-ctrb-transition-duration="${duration}ms"
			sleep "$duration_sleep"
		fi
		;;
	"previous")
		week=$((week + 1))
		if [ "$week" -le "$max" ]; then
			eww update gh-ctrb-transition="slideleft"
			eww update gh-ctrb-reveal="left" # (left covers middle)
			sleep "$duration_sleep" # wait for it to finish
			eww update gh-ctrb-week="$week"
			eww update gh-ctrb-transition-duration="0s"
			sleep 0.1
			eww update gh-ctrb-reveal="center" # (middle replaces left)
			eww update gh-ctrb-transition-duration="${duration}ms"
		fi
		;;
	*)
		;;
esac
next_week=$((week - 1 <  0  ?  0  : week - 1))
last_week=$((week + 1 > max ? max : week + 1))

eww update gh-ctrb-week-right="$next_week"
eww update gh-ctrb-week-left="$last_week"
sleep 0.1
rm /tmp/_ctrb_transition_lock
) &
