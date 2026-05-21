#!/usr/bin/env bash
# swayidle.sh — idle management for Sway
# Handles screen dimming, locking, DPMS off, and suspend

# Prevent multiple instances
pgrep -x swayidle > /dev/null && exit 0

SCRIPTS="$HOME/.config/sway/scripts"
LOCK="bash $SCRIPTS/swaylock.sh"
DDCALL="bash $SCRIPTS/ddcutil_all.sh"

exec swayidle -w \
    lock         "$LOCK"                              \
    \
    timeout 150  "$DDCALL dim"                        \
                 resume "$DDCALL undim"               \
    \
    timeout 300  "loginctl lock-session"              \
    \
    timeout 600  "swaymsg 'output * dpms off'"        \
                 resume "swaymsg 'output * dpms on'"  \
    \
    timeout 900  "systemctl suspend"                  \
                 resume "swaymsg 'output * dpms on'"  \
    \
    before-sleep "loginctl lock-session"