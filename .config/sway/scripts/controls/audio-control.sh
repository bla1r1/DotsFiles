#!/usr/bin/env bash
set -euo pipefail

SYNC_HINT="string:x-canonical-private-synchronous:sys-notify"
DEFAULT_STEP=5

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

sink_volume() {
    pamixer --get-volume
}

sink_muted() {
    pamixer --get-mute
}

sink_icon() {
    local vol
    vol="$(sink_volume)"
    if [ "$vol" -eq 0 ] || [ "$(sink_muted)" = "true" ]; then
        printf '%s\n' "audio-volume-muted"
    elif [ "$vol" -le 30 ]; then
        printf '%s\n' "audio-volume-low"
    elif [ "$vol" -le 60 ]; then
        printf '%s\n' "audio-volume-medium"
    else
        printf '%s\n' "audio-volume-high"
    fi
}

notify_sink() {
    local vol icon
    vol="$(sink_volume)"
    icon="$(sink_icon)"
    notify_msg "$icon" "Volume: $vol %"
}

main() {
    local action="${1:---get}"
    local step="${2:-$DEFAULT_STEP}"
    command -v pamixer >/dev/null 2>&1 || die "Missing required command: pamixer"

    case "$action" in
        --get) sink_volume ;;
        --get-icon) sink_icon ;;
        --inc)
            pamixer -i "$step"
            notify_sink
            ;;
        --dec)
            pamixer -d "$step"
            notify_sink
            ;;
        --toggle)
            if [ "$(sink_muted)" = "true" ]; then
                pamixer -u
                notify_msg "$(sink_icon)" "Volume: ON"
            else
                pamixer -m
                notify_msg "$ICON_DIR/volume-mute.png" "Volume: OFF"
            fi
            ;;
        *)
            die "Usage: audio-control.sh [--get|--get-icon|--inc|--dec|--toggle] [step]"
            ;;
    esac
}

main "$@"
