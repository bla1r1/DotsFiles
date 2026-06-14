#!/usr/bin/env bash
set -euo pipefail

SCRIPTS="$HOME/.config/sway/scripts"
LOCK="$SCRIPTS/session/lock.sh"
DDCALL="$SCRIPTS/controls/ddcutil_all.sh"

# Give the Wayland session lock a short moment to acquire before sleeping.
bash "$LOCK" >/dev/null 2>&1 &
sleep "${SUSPEND_LOCK_DELAY:-0.8}"

bash "$DDCALL" undim >/dev/null 2>&1 || true
systemctl suspend
