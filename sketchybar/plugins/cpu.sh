#!/bin/bash

CPU=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%')
sketchybar --set $NAME label="${CPU:-?}%"
