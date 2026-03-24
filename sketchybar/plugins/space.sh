#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Extract space number from item name (space.1 -> 1)
SPACE_NUM="${NAME##*.}"

# Get app names for this workspace
APPS="$(aerospace list-windows --workspace "$SPACE_NUM" --format '%{app-name}' 2>/dev/null)"
NAMES=""
SEEN=""

while IFS= read -r app; do
    [ -z "$app" ] && continue
    # Deduplicate (multiple windows of same app)
    case "$SEEN" in
        *"|$app|"*) continue ;;
    esac
    SEEN="$SEEN|$app|"
    if [ -z "$NAMES" ]; then
        NAMES="$app"
    else
        NAMES="$NAMES, $app"
    fi
done <<< "$APPS"

if [ "$FOCUSED_WORKSPACE" = "$SPACE_NUM" ]; then
    sketchybar --set $NAME \
        background.drawing=on \
        background.color=$PEACH \
        icon.color=$BASE \
        label.drawing=on \
        label.color=$BASE \
        label="${NAMES}"
else
    sketchybar --set $NAME \
        background.drawing=on \
        background.color=$BASE \
        icon.color=$PEACH \
        label.drawing=on \
        label.color=$PEACH \
        label="${NAMES}"
fi
