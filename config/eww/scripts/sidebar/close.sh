#!/bin/bash
(
eww update sidebar-revealed=false
sleep 0.25
# auto close this
eww update gh-reload-pfp=false
eww close sidebar
) &
