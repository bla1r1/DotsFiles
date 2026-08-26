#!/usr/bin/env bash
# swayidle.sh — idle management for Sway
# Handles screen dimming, locking, DPMS off, and suspend

# Prevent multiple instances
pgrep -x swayidle > /dev/null && exit 0

SCRIPTS="$HOME/.config/sway/scripts"
LOCK="bash $SCRIPTS/session/lock.sh"
DDCALL="b1air-daemon ddc"

exec swayidle -w \
    lock         "$LOCK"                              \
    \
    timeout 300  "$DDCALL dim >/dev/null 2>&1 &"      \
                 resume "$DDCALL undim >/dev/null 2>&1 &" \
    \
    timeout 600  "loginctl lock-session"              \
                 resume "sleep 1; $DDCALL undim >/dev/null 2>&1 &" \
    \
    timeout 900  "swaymsg 'output * dpms off'"        \
                 resume "swaymsg 'output * dpms on'; $DDCALL undim >/dev/null 2>&1 &" \
    \
    timeout 1200 "systemctl suspend"                  \
                 resume "swaymsg 'output * dpms on'; $DDCALL undim >/dev/null 2>&1 &" \
    \
    before-sleep "loginctl lock-session"
