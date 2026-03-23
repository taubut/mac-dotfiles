#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Extract space number from item name (space.1 -> 1)
SPACE_NUM="${NAME##*.}"

# Map app names to Nerd Font icons
icon_for_app() {
    case "$1" in
        "Ghostty"|"Terminal"|"iTerm2"|"Alacritty"|"WezTerm")  echo "" ;;
        "Safari"|"Firefox"|"Arc"|"Google Chrome"|"Brave Browser"|"Zen") echo "󰈹" ;;
        "Finder")           echo "" ;;
        "Code"|"Visual Studio Code") echo "󰨞" ;;
        "Slack")            echo "󰒱" ;;
        "Discord")          echo "󰙯" ;;
        "Telegram")         echo "" ;;
        "Messages")         echo "󰍡" ;;
        "Mail")             echo "󰇮" ;;
        "Spotify"|"Music")  echo "󰎆" ;;
        "Notes")            echo "󰎞" ;;
        "Preview")          echo "" ;;
        "System Settings"|"System Preferences") echo "" ;;
        "Claude"|"Claude Code") echo "󰚩" ;;
        "Xcode")            echo "󰀵" ;;
        "Docker"|"Docker Desktop") echo "󰡨" ;;
        "Obsidian")         echo "󰏫" ;;
        "Notion")           echo "󰎞" ;;
        "FaceTime")         echo "󰍢" ;;
        "Calendar")         echo "" ;;
        "App Store")        echo "" ;;
        *)                  echo "󰣆" ;;
    esac
}

# Get app icons for this workspace
APPS="$(aerospace list-windows --workspace "$SPACE_NUM" --format '%{app-name}' 2>/dev/null)"
ICONS=""
SEEN=""

while IFS= read -r app; do
    [ -z "$app" ] && continue
    # Deduplicate (multiple windows of same app)
    case "$SEEN" in
        *"|$app|"*) continue ;;
    esac
    SEEN="$SEEN|$app|"
    ICON="$(icon_for_app "$app")"
    ICONS="$ICONS $ICON"
done <<< "$APPS"

LABEL="${ICONS# }"

if [ "$FOCUSED_WORKSPACE" = "$SPACE_NUM" ]; then
    sketchybar --set $NAME \
        background.drawing=on \
        background.color=$PEACH \
        icon.color=$BASE \
        label.drawing=on \
        label.color=$BASE \
        label="${LABEL}"
else
    sketchybar --set $NAME \
        background.drawing=off \
        icon.color=$PEACH \
        label.drawing=on \
        label.color=$PEACH \
        label="${LABEL}"
fi
