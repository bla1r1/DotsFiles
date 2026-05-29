#!/usr/bin/env bash
# screenshot.sh — grim + slurp + copyq
# Usage: screenshot.sh [full|monitor|region|window|delay5|delay10]
# Ported from Hyprland version; works with sway via swaymsg

set -euo pipefail

SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$SCREENSHOT_DIR/screenshot_$TIMESTAMP.png"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -i "$FILE" "Screenshot" "$1" || true
}

copy_image() {
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy --type image/png < "$FILE" 2>/dev/null && return 0
    elif command -v copyq >/dev/null 2>&1; then
        copyq write image/png - < "$FILE" && copyq select 0 && return 0
    fi

    if command -v copyq >/dev/null 2>&1 && pgrep -x copyq >/dev/null 2>&1; then
        (copyq write image/png - < "$FILE" && copyq select 0) >/dev/null 2>&1 &
    fi

    return 0
}

case "${1:-}" in
    full)
        grim "$FILE"
        copy_image
        notify "Full screen → $FILE"
        ;;
    monitor)
        # get focused output via swaymsg
        OUTPUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
        grim -o "$OUTPUT" "$FILE"
        copy_image
        notify "Monitor ($OUTPUT) → $FILE"
        ;;
    region)
        GEOM="$(slurp)"
        [[ -n "$GEOM" ]] || exit 0
        grim -g "$GEOM" "$FILE"
        copy_image
        notify "Region → $FILE"
        ;;
    window)
        # get focused window geometry via swaymsg
        GEOM=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
        grim -g "$GEOM" "$FILE"
        copy_image
        notify "Window → $FILE"
        ;;
    delay5)
        sleep 5
        grim "$FILE"
        copy_image
        notify "Delayed 5s → $FILE"
        ;;
    delay10)
        sleep 10
        grim "$FILE"
        copy_image
        notify "Delayed 10s → $FILE"
        ;;
    *)
        echo "Usage: $0 [full|monitor|region|window|delay5|delay10]"
        exit 1
        ;;
esac
