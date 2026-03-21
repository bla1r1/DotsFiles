#!/usr/bin/env bash

# Не запускать второй экземпляр
pgrep -x swayidle > /dev/null && exit 0

LOCK="bash $HOME/.config/sway/scripts/swaylock.sh"

exec swayidle -w \
    lock         "$LOCK"                              \
    timeout 150  "brightnessctl -s set 10"            \
                 resume "brightnessctl -r"            \
    timeout 300  "loginctl lock-session"              \
    timeout 600  "swaymsg 'output * dpms off'"        \
                 resume "swaymsg 'output * dpms on'"  \
    timeout 900  "systemctl suspend"                  \
    before-sleep "loginctl lock-session"
