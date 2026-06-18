#!/usr/bin/env bash
# swayidle.sh — idle management for Sway
# Handles screen dimming, locking, DPMS off, and suspend

# Prevent multiple instances
pgrep -x swayidle > /dev/null && exit 0

SCRIPTS="$HOME/.config/sway/scripts"
LOCK="bash $SCRIPTS/session/lock.sh"
DDCALL="bash $SCRIPTS/controls/ddcutil_all.sh"
SETTINGS_LIB="$SCRIPTS/lib/settings.sh"

[[ -f "$SETTINGS_LIB" ]] && source "$SETTINGS_LIB"

DIM_TIMEOUT=300
LOCK_TIMEOUT=600
DPMS_TIMEOUT=900
SUSPEND_TIMEOUT=1200
AUTO_SUSPEND=true

if declare -F settings_get_int >/dev/null 2>&1; then
    DIM_TIMEOUT="$(settings_get_int session.dimTimeout "$DIM_TIMEOUT" 30 86400)"
    LOCK_TIMEOUT="$(settings_get_int session.lockTimeout "$LOCK_TIMEOUT" 30 86400)"
    DPMS_TIMEOUT="$(settings_get_int session.dpmsTimeout "$DPMS_TIMEOUT" 30 86400)"
    SUSPEND_TIMEOUT="$(settings_get_int session.suspendTimeout "$SUSPEND_TIMEOUT" 30 86400)"
fi

if declare -F settings_get_bool >/dev/null 2>&1; then
    AUTO_SUSPEND="$(settings_get_bool session.autoSuspend "$AUTO_SUSPEND")"
fi

args=(
    -w
    lock "$LOCK"
    timeout "$DIM_TIMEOUT" "$DDCALL dim >/dev/null 2>&1 &"
        resume "$DDCALL undim >/dev/null 2>&1 &"
    timeout "$LOCK_TIMEOUT" "loginctl lock-session"
        resume "sleep 1; $DDCALL undim >/dev/null 2>&1 &"
    timeout "$DPMS_TIMEOUT" "swaymsg 'output * dpms off'"
        resume "swaymsg 'output * dpms on'; $DDCALL undim >/dev/null 2>&1 &"
)

if [[ "$AUTO_SUSPEND" == "true" ]]; then
    args+=(
        timeout "$SUSPEND_TIMEOUT" "systemctl suspend"
            resume "swaymsg 'output * dpms on'; $DDCALL undim >/dev/null 2>&1 &"
    )
fi

args+=(before-sleep "loginctl lock-session")

exec swayidle "${args[@]}"
