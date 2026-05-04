#!/usr/bin/env bash
# screenshot.sh — grim + slurp + copyq
# Usage: screenshot.sh [full|monitor|region|window|delay5|delay10]
# Ported from Hyprland version; works with sway via swaymsg

SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$SCREENSHOT_DIR/screenshot_$TIMESTAMP.png"

notify() {
    notify-send -i "$FILE" "Screenshot" "$1"
}

case "$1" in
    full)
        grim "$FILE"
        copyq write image/png - < "$FILE" && copyq select 0
        notify "Full screen → $FILE"
        ;;
    monitor)
        # get focused output via swaymsg
        OUTPUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
        grim -o "$OUTPUT" "$FILE"
        copyq write image/png - < "$FILE" && copyq select 0
        notify "Monitor ($OUTPUT) → $FILE"
        ;;
    region)
        slurp | grim -g - "$FILE"
        copyq write image/png - < "$FILE" && copyq select 0
        notify "Region → $FILE"
        ;;
    window)
        # get focused window geometry via swaymsg
        GEOM=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
        grim -g "$GEOM" "$FILE"
        copyq write image/png - < "$FILE" && copyq select 0
        notify "Window → $FILE"
        ;;
    delay5)
        sleep 5
        grim "$FILE"
        copyq write image/png - < "$FILE" && copyq select 0
        notify "Delayed 5s → $FILE"
        ;;
    delay10)
        sleep 10
        grim "$FILE"
        copyq write image/png - < "$FILE" && copyq select 0
        notify "Delayed 10s → $FILE"
        ;;
    *)
        echo "Usage: $0 [full|monitor|region|window|delay5|delay10]"
        exit 1
        ;;
esac
