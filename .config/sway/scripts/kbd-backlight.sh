#!/usr/bin/env bash
set -euo pipefail

ICON_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"
SYNC_HINT="string:x-canonical-private-synchronous:sys-notify-kbd"
DEVICE="${KBD_BACKLIGHT_DEVICE:-}"
DEFAULT_STEP=10
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
DEVICE_CACHE="$CACHE_DIR/kbd-backlight-device"
MAX_CACHE="$CACHE_DIR/kbd-backlight-max"

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

available() {
    command -v brightnessctl >/dev/null 2>&1 || return 1
    DEVICE="$(detect_device)" || return 1
    [[ -n "$DEVICE" ]] || return 1
    brightnessctl -d "$DEVICE" get >/dev/null 2>&1
}

detect_device() {
    local cached

    if [[ -n "$DEVICE" ]]; then
        printf '%s\n' "$DEVICE"
        return 0
    fi

    cached="$(cat "$DEVICE_CACHE" 2>/dev/null || true)"
    if [[ -n "$cached" ]] && brightnessctl -d "$cached" get >/dev/null 2>&1; then
        printf '%s\n' "$cached"
        return 0
    fi

    mkdir -p "$CACHE_DIR"
    brightnessctl -l 2>/dev/null \
        | sed -n "s/^Device '\([^']*kbd_backlight[^']*\)'.*/\1/p" \
        | head -n1 \
        | tee "$DEVICE_CACHE"
}

get_brightness() {
    brightnessctl -d "$DEVICE" get
}

get_max() {
    local max
    max="$(cat "$MAX_CACHE" 2>/dev/null || true)"
    if [[ ! "$max" =~ ^[0-9]+$ || "$max" -le 0 ]]; then
        mkdir -p "$CACHE_DIR"
        max="$(brightnessctl -d "$DEVICE" max)"
        printf '%s\n' "$max" > "$MAX_CACHE"
    fi
    printf '%s\n' "$max"
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

    if [[ "$action" == "--available" ]]; then
        available
        exit $?
    fi

    if ! available; then
        [[ "$action" == "--get" ]] && exit 1
        exit 0
    fi

    case "$action" in
        --get)
            get_percent
            ;;
        --inc)
            brightnessctl -d "$DEVICE"  set "${step}%+"
            notify_kbd
            ;;
        --dec)
            brightnessctl -d "$DEVICE"  set "${step}%-"
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
            die "Usage: kbd-backlight.sh [--available|--get|--inc|--dec|--set <val>|--off] [step]"
            ;;
    esac
}

main "$@"
