#!/usr/bin/env bash
# =============================================================================
# game-mode.sh — High-Performance Game Mode for SwayFX
#
# Optimizes compositor (0% GPU overhead), CPU governor, audio latency,
# and background services when gaming.
# =============================================================================

set -euo pipefail

SETTINGS_FILE="$HOME/.config/sway/settings.json"
STATE_FILE="/tmp/sway-game-mode.state"

get_setting() {
    local key="$1"
    local default="$2"
    if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq -r ".$key // $default" "$SETTINGS_FILE" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

set_setting() {
    local key="$1"
    local val="$2"
    if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
        local tmp
        tmp="$(mktemp)"
        jq --argjson v "$val" ".$key = \$v" "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    fi
}

is_active() {
    [ -f "$STATE_FILE" ]
}

enable_game_mode() {
    # ── 1. Compositor Effects (SwayFX) ────────────────────────────────────────
    # Disable blur, shadows, rounded corners, and borders for pure 0% GPU overhead
    swaymsg blur disable 2>/dev/null || true
    swaymsg shadows disable 2>/dev/null || true
    swaymsg corner_radius 0 2>/dev/null || true
    swaymsg default_border pixel 0 2>/dev/null || true

    # Adaptive Sync (VRR) — user configurable (default false)
    local vrr
    vrr="$(get_setting "gameModeAdaptiveSync" "false")"
    if [ "$vrr" = "true" ]; then
        swaymsg output "*" adaptive_sync on 2>/dev/null || true
    fi

    # ── 2. CPU & Power Profile ────────────────────────────────────────────────
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance 2>/dev/null || true
    elif [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "performance" | sudo tee "$gov" >/dev/null 2>&1 || true
        done
    fi

    if command -v gamemoded >/dev/null 2>&1; then
        gamemoded -r 2>/dev/null || true
    fi

    # ── 3. Low Latency Audio (PipeWire) ───────────────────────────────────────
    if command -v pw-metadata >/dev/null 2>&1; then
        pw-metadata -n settings 0 clock.force-quantum 256 2>/dev/null || true
    fi

    # ── 4. Waybar Hiding (default true) ───────────────────────────────────────
    local hide_waybar
    hide_waybar="$(get_setting "gameModeHideWaybar" "true")"
    if [ "$hide_waybar" = "true" ]; then
        killall -SIGUSR1 waybar 2>/dev/null || true
    fi

    # ── 5. Do Not Disturb / Notifications (default false) ─────────────────────
    local dnd
    dnd="$(get_setting "gameModeDND" "false")"
    if [ "$dnd" = "true" ]; then
        if command -v makoctl >/dev/null 2>&1; then
            makoctl mode -a dnd 2>/dev/null || true
        fi
    fi

    # Save state
    touch "$STATE_FILE"
    set_setting "gameModeEnabled" true

    # Notification
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Game Mode" -i "input-gaming" "Game Mode Enabled" "Compositor effects disabled • Performance active" 2>/dev/null || true
    fi
}

disable_game_mode() {
    # ── 1. Restore Compositor Effects (SwayFX) ────────────────────────────────
    swaymsg blur enable 2>/dev/null || true
    swaymsg shadows enable 2>/dev/null || true
    swaymsg corner_radius 12 2>/dev/null || true
    swaymsg default_border pixel 2 2>/dev/null || true
    swaymsg output "*" adaptive_sync off 2>/dev/null || true

    # ── 2. Restore Power Profile ──────────────────────────────────────────────
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced 2>/dev/null || true
    fi

    # ── 3. Restore Audio Latency ──────────────────────────────────────────────
    if command -v pw-metadata >/dev/null 2>&1; then
        pw-metadata -n settings 0 clock.force-quantum 0 2>/dev/null || true
    fi

    # ── 4. Restore Waybar ─────────────────────────────────────────────────────
    local hide_waybar
    hide_waybar="$(get_setting "gameModeHideWaybar" "true")"
    if [ "$hide_waybar" = "true" ]; then
        killall -SIGUSR1 waybar 2>/dev/null || true
    fi

    # ── 5. Restore Notifications ──────────────────────────────────────────────
    local dnd
    dnd="$(get_setting "gameModeDND" "false")"
    if [ "$dnd" = "true" ]; then
        if command -v makoctl >/dev/null 2>&1; then
            makoctl mode -r dnd 2>/dev/null || true
        fi
    fi

    # Remove state
    rm -f "$STATE_FILE"
    set_setting "gameModeEnabled" false

    # Notification
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Game Mode" -i "input-gaming" "Game Mode Disabled" "Standard desktop profile restored" 2>/dev/null || true
    fi
}

action="${1:-toggle}"

case "$action" in
    on|enable)
        enable_game_mode
        ;;
    off|disable)
        disable_game_mode
        ;;
    toggle)
        if is_active; then
            disable_game_mode
        else
            enable_game_mode
        fi
        ;;
    status)
        if is_active; then
            echo '{"enabled": true}'
        else
            echo '{"enabled": false}'
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}"
        exit 1
        ;;
esac
