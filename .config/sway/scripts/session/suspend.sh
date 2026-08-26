#!/usr/bin/env bash
set -euo pipefail

SCRIPTS="$HOME/.config/sway/scripts"
LOCK="$SCRIPTS/session/lock.sh"
# Give the Wayland session lock a short moment to acquire before sleeping.
bash "$LOCK" >/dev/null 2>&1 &
sleep "${SUSPEND_LOCK_DELAY:-0.8}"

b1air-daemon ddc undim >/dev/null 2>&1 || true
systemctl suspend
