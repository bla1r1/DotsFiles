#!/usr/bin/env bash
# Waybar player module — continuous, not polled.
#
# Was: forked once every 2 seconds, 30 times a minute, whether or not anything
# was playing. Most of that work was re-rendering a marquee that stepped once
# per poll — a scroll so coarse it read as a stutter rather than motion.
#
# Now: one long-lived `playerctl --follow`, which emits a line only when the
# track or the playback state actually changes. Long titles elide via
# `max-length` in modules.json instead of scrolling.
#
# Waybar runs this in continuous mode when the module has no `interval`.
set -uo pipefail

emit() {
    local text="$1" class="$2" tooltip="$3"
    text=${text//\\/\\\\}; text=${text//\"/\\\"}
    tooltip=${tooltip//\\/\\\\}; tooltip=${tooltip//\"/\\\"}
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tooltip"
}

if ! command -v playerctl >/dev/null 2>&1; then
    emit "󰝚" "offline" "No playerctl"
    # Nothing to follow — hold the line open so waybar does not respawn us.
    sleep infinity
fi

# A unit separator keeps titles containing the delimiter from splitting wrong.
sep=$'\x1f'

playerctl --follow metadata \
    --format "{{status}}${sep}{{artist}}${sep}{{title}}${sep}{{playerName}}" 2>/dev/null |
while IFS="$sep" read -r status artist title player; do
    case "$status" in
        Playing) icon=""; class="playing" ;;
        Paused)  icon=""; class="paused" ;;
        *)       emit "" "hidden" "No active player"; continue ;;
    esac

    label="${title:-Media}"
    [ -n "$artist" ] && label="$artist - $label"

    tooltip="${artist:+$artist - }${title:-Media}"
    [ -n "$player" ] && tooltip="$tooltip via $player"

    emit "$icon  $label" "$class" "$tooltip"
done

# playerctl exits when the last player goes away; waybar restarts us.
emit "" "hidden" "No active player"
