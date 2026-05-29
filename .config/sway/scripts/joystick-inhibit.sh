#!/usr/bin/env bash

set -euo pipefail

pgrep -f "joystick-inhibit.sh" | grep -v "$$" >/dev/null && exit 0

ACTIVE_SECONDS="${JOYSTICK_INHIBIT_SECONDS:-120}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway/joystick-inhibit"
mkdir -p "$CACHE_DIR"

have() {
    command -v "$1" >/dev/null 2>&1
}

refresh_inhibitor() {
    local dev="$1"
    local name pid_file old_pid
    name="$(basename "$dev")"
    pid_file="$CACHE_DIR/$name.pid"

    old_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
    fi

    systemd-inhibit \
        --what=idle \
        --who="Joystick" \
        --why="$dev active" \
        --mode=block \
        sleep "$ACTIVE_SECONDS" &
    printf '%s\n' "$!" > "$pid_file"
}

watch_device() {
    local dev="$1"
    local name watch_pid_file old_watch_pid
    name="$(basename "$dev")"
    watch_pid_file="$CACHE_DIR/$name.watch.pid"

    old_watch_pid="$(cat "$watch_pid_file" 2>/dev/null || true)"
    if [[ -n "$old_watch_pid" ]] && kill -0 "$old_watch_pid" 2>/dev/null; then
        return 0
    fi

    (
        while [[ -e "$dev" ]]; do
            if dd if="$dev" of=/dev/null bs=8 count=1 status=none 2>/dev/null; then
                refresh_inhibitor "$dev"
            else
                sleep 1
            fi
        done
    ) &
    printf '%s\n' "$!" > "$watch_pid_file"
}

have systemd-inhibit || exit 0

for dev in /dev/input/js*; do
    [[ -e "$dev" ]] && watch_device "$dev"
done

if have inotifywait; then
    inotifywait -m -e create /dev/input/ 2>/dev/null | while read -r _ _ file; do
        [[ "$file" == js* ]] && watch_device "/dev/input/$file"
    done
else
    wait
fi
