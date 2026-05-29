#!/usr/bin/env bash
set -euo pipefail

STEP="${BRIGHTNESS_STEP:-5}"

available() {
    command -v brightnessctl >/dev/null 2>&1 || return 1
    [[ -e /sys/class/backlight ]] && compgen -G '/sys/class/backlight/*/brightness' >/dev/null
}

case "${1:-get}" in
    available)
        available
        exit $?
        ;;
    get)
        available || exit 1
        brightnessctl -c backlight -m 2>/dev/null | awk -F, 'NR == 1 { gsub("%", "", $4); print $4 }'
        ;;
    up)
        available || exit 0
        brightnessctl -c backlight -e4 -n2 set "${2:-$STEP}%+" >/dev/null
        ;;
    down)
        available || exit 0
        brightnessctl -c backlight -e4 -n2 set "${2:-$STEP}%-" >/dev/null
        ;;
    *)
        printf 'Usage: %s [available|get|up|down] [step]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac
