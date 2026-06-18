#!/usr/bin/env bash
set -euo pipefail

STEP="${BRIGHTNESS_STEP:-5}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_LIB="$SCRIPT_DIR/lib/settings.sh"

[[ -f "$SETTINGS_LIB" ]] && source "$SETTINGS_LIB"
declare -F settings_get_int >/dev/null 2>&1 && STEP="$(settings_get_int controls.brightnessStep "$STEP" 1 25)"

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
