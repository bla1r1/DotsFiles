#!/usr/bin/env bash
# screenshot.sh — screenshot script for Hyprland
# Dependencies: grim, slurp, copyq, notify-send, jq
# Usage: screenshot.sh [mode]
#   full      — entire screen (all monitors)
#   monitor   — current monitor (where cursor is)
#   region    — mouse selection
#   window    — active window
#   delay5    — entire screen with 5s delay
#   delay10   — entire screen with 10s delay

SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$SAVE_DIR/$TIMESTAMP.png"

MODE="${1:-full}"

copy_to_clipboard() {
    local file="$1"
    copyq write image/png - < "$file"
    copyq select 0
}

notify_done() {
    local file="$1"
    notify-send \
        --icon="$file" \
        --app-name="Screenshot" \
        --hint=string:image-path:"$file" \
        "📸 Screenshot saved" \
        "$(basename "$file")"
}

notify_fail() {
    notify-send \
        --app-name="Screenshot" \
        --urgency=critical \
        "❌ Screenshot cancelled" \
        "$1"
}

case "$MODE" in
    full)
        grim "$FILE"
        copy_to_clipboard "$FILE"
        notify_done "$FILE"
        ;;

    monitor)
        # Get the monitor where the cursor is currently located
        MONITOR=$(hyprctl monitors -j | jq -r '
            .[] | select(.focused == true) | .name
        ')
        if [[ -z "$MONITOR" ]]; then
            notify_fail "Failed to determine current monitor"
            exit 1
        fi
        grim -o "$MONITOR" "$FILE"
        copy_to_clipboard "$FILE"
        notify_done "$FILE"
        ;;

    region)
        GEOM=$(slurp 2>/dev/null)
        if [[ -z "$GEOM" ]]; then
            notify_fail "Selection cancelled"
            exit 1
        fi
        grim -g "$GEOM" "$FILE"
        copy_to_clipboard "$FILE"
        notify_done "$FILE"
        ;;

    window)
        GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [[ -z "$GEOM" || "$GEOM" == "null,null nullxnull" ]]; then
            notify_fail "Failed to get window geometry"
            exit 1
        fi
        grim -g "$GEOM" "$FILE"
        copy_to_clipboard "$FILE"
        notify_done "$FILE"
        ;;

    delay5)
        notify-send --app-name="Screenshot" "⏱ Screenshot in 5 seconds..." ""
        sleep 5
        grim "$FILE"
        copy_to_clipboard "$FILE"
        notify_done "$FILE"
        ;;

    delay10)
        notify-send --app-name="Screenshot" "⏱ Screenshot in 10 seconds..." ""
        sleep 10
        grim "$FILE"
        copy_to_clipboard "$FILE"
        notify_done "$FILE"
        ;;

    *)
        echo "Unknown mode: $MODE"
        echo "Available: full | monitor | region | window | delay5 | delay10"
        exit 1
        ;;
esac
