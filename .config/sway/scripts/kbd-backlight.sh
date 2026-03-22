#!/usr/bin/env bash
set -euo pipefail

ICON_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"
SYNC_HINT="string:x-canonical-private-synchronous:sys-notify-kbd"
DEVICE="apple::kbd_backlight"
DEFAULT_STEP=10

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

get_brightness() {
    brightnessctl -d "$DEVICE" get
}

get_max() {
    brightnessctl -d "$DEVICE" max
}

get_percent() {
    local cur max
    cur="$(get_brightness)"
    max="$(get_max)"
    printf '%d\n' $(( cur * 100 / max ))
}

notify_kbd() {
    local pct
    pct="$(get_percent)"
    notify_msg "$ICON_DIR/keyboard.png" "Keyboard backlight: $pct %"
}

main() {
    local action="${1:---get}"
    local step="${2:-$DEFAULT_STEP}"
    command -v brightnessctl >/dev/null 2>&1 || die "Missing required command: brightnessctl"

    # Проверяем что устройство вообще есть
    brightnessctl -d "$DEVICE" info >/dev/null 2>&1 \
        || die "Device '$DEVICE' not found. Run: brightnessctl --list"

    case "$action" in
        --get)
            get_percent
            ;;
        --inc)
            brightnessctl -d "$DEVICE" -e4 -n2 set "${step}%+"
            notify_kbd
            ;;
        --dec)
            brightnessctl -d "$DEVICE" -e4 -n2 set "${step}%-"
            notify_kbd
            ;;
        --set)
            # Прямое задание значения в процентах, например: kbd-backlight.sh --set 50
            local val="${2:-50}"
            brightnessctl -d "$DEVICE" set "${val}%"
            notify_kbd
            ;;
        --off)
            brightnessctl -d "$DEVICE" set 0
            notify_msg "$ICON_DIR/keyboard.png" "Keyboard backlight: OFF"
            ;;
        *)
            die "Usage: kbd-backlight.sh [--get|--inc|--dec|--set <val>|--off] [step]"
            ;;
    esac
}

main "$@"
