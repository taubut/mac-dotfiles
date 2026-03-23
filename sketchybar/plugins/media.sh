#!/bin/bash

source "$CONFIG_DIR/colors.sh"

TITLE=""
ARTIST=""

# Try Apple Music
if pgrep -x "Music" >/dev/null 2>&1; then
    STATE="$(osascript -e 'tell application "Music" to get player state' 2>/dev/null)"
    if [ "$STATE" = "playing" ]; then
        TITLE="$(osascript -e 'tell application "Music" to get name of current track' 2>/dev/null)"
        ARTIST="$(osascript -e 'tell application "Music" to get artist of current track' 2>/dev/null)"
    fi
fi

# Try Spotify if no Apple Music
if [ -z "$TITLE" ] && pgrep -x "Spotify" >/dev/null 2>&1; then
    STATE="$(osascript -e 'tell application "Spotify" to get player state' 2>/dev/null)"
    if [ "$STATE" = "playing" ]; then
        TITLE="$(osascript -e 'tell application "Spotify" to get name of current track' 2>/dev/null)"
        ARTIST="$(osascript -e 'tell application "Spotify" to get artist of current track' 2>/dev/null)"
    fi
fi

# Try browser media via nowplaying-cli as fallback
if [ -z "$TITLE" ]; then
    TITLE="$(nowplaying-cli get title 2>/dev/null | head -1)"
    ARTIST="$(nowplaying-cli get artist 2>/dev/null | head -1)"
    # Filter out null values
    case "$TITLE" in "null"|"NULL"|"(null)"|"") TITLE="" ;; esac
    case "$ARTIST" in "null"|"NULL"|"(null)"|"") ARTIST="" ;; esac
fi

if [ -n "$TITLE" ]; then
    [ ${#TITLE} -gt 30 ] && TITLE="${TITLE:0:27}..."
    [ ${#ARTIST} -gt 20 ] && ARTIST="${ARTIST:0:17}..."

    if [ -n "$ARTIST" ]; then
        DISPLAY="$TITLE — $ARTIST"
    else
        DISPLAY="$TITLE"
    fi
    sketchybar --set $NAME label="$DISPLAY" icon=󰎆 drawing=on
else
    sketchybar --set $NAME label="" icon="" drawing=off
fi
