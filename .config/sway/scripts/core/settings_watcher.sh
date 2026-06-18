#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="${SWAY_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/settings.json}"
SWAYIDLE_SCRIPT="$SCRIPT_DIR/session/swayidle.sh"
WEATHER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/weather"
LAST_HASH=""

hash_settings() {
    [[ -f "$SETTINGS_FILE" ]] || {
        printf 'missing\n'
        return
    }

    if command -v jq >/dev/null 2>&1; then
        jq -c '{controls,session,weather,monitors}' "$SETTINGS_FILE" 2>/dev/null | sha256sum | awk '{print $1}'
    else
        sha256sum "$SETTINGS_FILE" | awk '{print $1}'
    fi
}

apply_settings_change() {
    if command -v pkill >/dev/null 2>&1; then
        pkill -x swayidle >/dev/null 2>&1 || true
    fi

    if [[ -x "$SWAYIDLE_SCRIPT" || -f "$SWAYIDLE_SCRIPT" ]]; then
        bash "$SWAYIDLE_SCRIPT" >/dev/null 2>&1 &
        disown
    fi

    rm -f "$WEATHER_CACHE/weather.json" "$WEATHER_CACHE/.env_tracker" 2>/dev/null || true
}

LAST_HASH="$(hash_settings)"

while true; do
    sleep 2
    current_hash="$(hash_settings)"
    if [[ "$current_hash" != "$LAST_HASH" ]]; then
        LAST_HASH="$current_hash"
        apply_settings_change
    fi
done
