#!/usr/bin/env bash
set -euo pipefail

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/waybar-single.lock"
ACTION="${1:-start}"

exec 9>"$LOCK_FILE"
flock 9

mapfile -t pids < <(pgrep -x waybar 2>/dev/null || true)
if [[ "$ACTION" == "restart" ]]; then
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    sleep 0.1
    exec waybar
fi

if ((${#pids[@]} > 0)); then
    keep="${pids[0]}"
    for pid in "${pids[@]:1}"; do
        kill "$pid" 2>/dev/null || true
    done
    exit 0
fi

exec waybar
