#!/usr/bin/env bash
# day-night-cycle.sh — Automated day/night wallpaper & ambiance scheduler
set -euo pipefail

SETTINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/settings.json"
DAY_HOUR=7
NIGHT_HOUR=20

get_current_mode() {
    local hour
    hour=$(date +%-H)
    if (( hour >= DAY_HOUR && hour < NIGHT_HOUR )); then
        echo "day"
    else
        echo "night"
    fi
}

apply_mode() {
    local mode="$1"
    local wp_dir="${HOME}/.wallpapers"
    
    if [[ "$mode" == "day" ]]; then
        # Check if day wallpaper exists or use default
        if [[ -f "${wp_dir}/day.png" ]]; then
            swaymsg "output * bg '${wp_dir}/day.png' fill" >/dev/null 2>&1 || true
        fi
        # Turn off night light if enabled
        pkill wlsunset 2>/dev/null || true
    else
        # Check if night wallpaper exists
        if [[ -f "${wp_dir}/night.png" ]]; then
            swaymsg "output * bg '${wp_dir}/night.png' fill" >/dev/null 2>&1 || true
        fi
    fi
}

LAST_MODE=""
while true; do
    CURR_MODE=$(get_current_mode)
    if [[ "$CURR_MODE" != "$LAST_MODE" ]]; then
        LAST_MODE="$CURR_MODE"
        apply_mode "$CURR_MODE"
    fi
    sleep 300 # check every 5 minutes
done
