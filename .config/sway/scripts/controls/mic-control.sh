#!/usr/bin/env bash
set -euo pipefail

# Tell waybar to re-read instead of having it poll us. Call this ONLY from
# paths that CHANGE something: a read is what waybar itself runs, and
# signalling from there would loop — signal, re-exec, signal again. The module is
# "interval": "once" + "signal": 1; see waybar/modules.json.
notify_waybar() { pkill -RTMIN+1 waybar 2>/dev/null || true; }

ICON_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"
SYNC_HINT="string:x-canonical-private-synchronous:sys-notify-mic"

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

notify_msg() {
    local icon="$1"
    local title="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -h "$SYNC_HINT" -u low -i "$icon" "$title"
    fi
}

source_muted() {
    pamixer --default-source --get-mute
}

source_volume() {
    pamixer --default-source --get-volume
}

mic_icon() {
    if [ "$(source_muted)" = "true" ]; then
        printf '%s\n' "$ICON_DIR/mic-mute.png"
    else
        printf '%s\n' "$ICON_DIR/mic.png"
    fi
}

main() {
    local action="${1:---get}"
    command -v pamixer >/dev/null 2>&1 || die "Missing required command: pamixer"

    case "$action" in
        --get)
            source_volume
            ;;
        --get-muted)
            source_muted
            ;;
        --get-waybar)
            if [ "$(source_muted)" = "true" ]; then
                printf '󰍭\n'
            else
                printf '󰍬\n'
            fi
            ;;
        --get-icon)
            mic_icon
            ;;
        --toggle)
            if [ "$(source_muted)" = "true" ]; then
                pamixer --default-source -u
                notify_msg "$ICON_DIR/mic.png" "Mic: ON"
            else
                pamixer --default-source -m
                notify_msg "$ICON_DIR/mic-mute.png" "Mic: OFF"
            fi
            notify_waybar
            ;;
        *)
            die "Usage: mic-control.sh [--get|--get-muted|--get-waybar|--get-icon|--toggle]"
            ;;
    esac
}

main "$@"
