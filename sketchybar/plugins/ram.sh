#!/bin/bash

RAM=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage:" | awk '{print 100-$5}' | tr -d '%')
sketchybar --set $NAME label="${RAM:-?}%"
