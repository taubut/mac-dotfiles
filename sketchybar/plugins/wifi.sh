#!/bin/bash

source "$CONFIG_DIR/colors.sh"

IP="$(ipconfig getifaddr en0 2>/dev/null)"

if [ -n "$IP" ]; then
    sketchybar --set $NAME icon=󰖩 label="Wi-Fi"
else
    sketchybar --set $NAME icon=󰖪 label="Off"
fi
