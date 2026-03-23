#!/bin/bash

source "$CONFIG_DIR/colors.sh"

TITLE=""
ARTIST=""

# Get frontmost app to prioritize active media
FRONT_APP="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)"

# Helper: check Apple Music
get_apple_music() {
    if pgrep -x "Music" >/dev/null 2>&1; then
        STATE="$(osascript -e 'tell application "Music" to get player state' 2>/dev/null)"
        if [ "$STATE" = "playing" ]; then
            TITLE="$(osascript -e 'tell application "Music" to get name of current track' 2>/dev/null)"
            ARTIST="$(osascript -e 'tell application "Music" to get artist of current track' 2>/dev/null)"
        fi
    fi
}

# Helper: check Spotify
get_spotify() {
    if pgrep -x "Spotify" >/dev/null 2>&1; then
        STATE="$(osascript -e 'tell application "Spotify" to get player state' 2>/dev/null)"
        if [ "$STATE" = "playing" ]; then
            TITLE="$(osascript -e 'tell application "Spotify" to get name of current track' 2>/dev/null)"
            ARTIST="$(osascript -e 'tell application "Spotify" to get artist of current track' 2>/dev/null)"
        fi
    fi
}

# Helper: check Subtui via Ghostty window titles
get_subtui() {
    SUBTUI_WIN="$(osascript -e '
        tell application "System Events"
            repeat with p in (every process whose name is "ghostty")
                try
                    repeat with w in (every window of p)
                        set t to name of w
                        if t contains " - " and t does not contain "Claude" and t does not contain "~" then
                            return t
                        end if
                    end repeat
                end try
            end repeat
        end tell
        return ""
    ' 2>/dev/null)"
    if [ -n "$SUBTUI_WIN" ]; then
        TITLE="${SUBTUI_WIN%% - *}"
        ARTIST="${SUBTUI_WIN#* - }"
        [ "$TITLE" = "$ARTIST" ] && TITLE="" && ARTIST=""
    fi
}

# Helper: check YouTube in browsers
get_youtube() {
    for BROWSER in qutebrowser Safari "Google Chrome" Firefox; do
        YT_WIN="$(osascript -e "
            tell application \"System Events\"
                try
                    tell process \"$BROWSER\"
                        repeat with w in (every window)
                            set t to name of w
                            if t contains \"YouTube\" then
                                return t
                            end if
                        end repeat
                    end tell
                end try
            end tell
            return \"\"
        " 2>/dev/null)"
        if [ -n "$YT_WIN" ]; then
            TITLE="${YT_WIN%% - YouTube*}"
            break
        fi
    done
}

# Prioritize based on frontmost app
case "$FRONT_APP" in
    qutebrowser|Safari|Google\ Chrome|Firefox)
        get_youtube
        [ -z "$TITLE" ] && get_apple_music
        [ -z "$TITLE" ] && get_spotify
        [ -z "$TITLE" ] && get_subtui
        ;;
    *)
        get_apple_music
        [ -z "$TITLE" ] && get_spotify
        [ -z "$TITLE" ] && get_subtui
        [ -z "$TITLE" ] && get_youtube
        ;;
esac

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
