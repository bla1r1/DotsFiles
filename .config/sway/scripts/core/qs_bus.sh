#!/usr/bin/env bash
set -euo pipefail

BUS_DIR="${XDG_RUNTIME_DIR:-/tmp}/qs-ui-bus"

mkdir -p "$BUS_DIR"

usage() {
    printf 'Usage: %s listen [channel] | send [channel] <payload>\n' "${0##*/}" >&2
    exit 2
}

state_file_for() {
    case "$1" in
        main) printf '/tmp/qs_widget_state' ;;
        widget) printf '/tmp/qs_current_widget' ;;
        *) printf '/tmp/qs_%s_state' "$1" ;;
    esac
}

case "${1:-}" in
    listen)
        channel="${2:-main}"
        socket="$BUS_DIR/$channel.sock"
        state_file="$(state_file_for "$channel")"

        if command -v socat >/dev/null 2>&1; then
            rm -f "$socket"
            exec socat -u "UNIX-RECV:$socket" -
        fi

        touch "$state_file"
        if command -v inotifywait >/dev/null 2>&1; then
            inotifywait -qq -e close_write,modify,create,move "$state_file" 2>/dev/null || true
        else
            sleep 0.75
        fi
        cat "$state_file"
        ;;

    send)
        shift
        if [ "$#" -ge 2 ]; then
            channel="$1"
            shift
        else
            channel="main"
        fi
        payload="${*:-}"
        [ -n "$payload" ] || usage

        socket="$BUS_DIR/$channel.sock"
        state_file="$(state_file_for "$channel")"

        if [ "$channel" = "main" ]; then
            printf '%s|%s\n' "$payload" "$(date +%s%N)" > "$state_file"
        else
            printf '%s\n' "$payload" > "$state_file"
        fi

        if command -v socat >/dev/null 2>&1 && [ -S "$socket" ]; then
            printf '%s\n' "$payload" | socat -u - "UNIX-SENDTO:$socket" >/dev/null 2>&1 || true
        fi
        ;;

    *)
        usage
        ;;
esac
