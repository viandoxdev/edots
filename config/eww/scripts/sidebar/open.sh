#!/bin/bash
(
eww open sidebar
eww update sidebar-revealed=true
sleep 0.3
~/dots/config/eww/sh/ctrb.sh day

) &
