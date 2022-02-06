#!/bin/bash
(
eww update sidebar-revealed=false
sleep 0.25
# auto close this
eww update gh-reload-avatar=false
eww update gh-ctrb-day-current="$(date -u +%w)"
eww close sidebar
) &
