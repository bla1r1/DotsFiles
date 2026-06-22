#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
SEEK_FILE="$RUNTIME_DIR/quickshell_music_seek_data"
LOCK_FILE="$RUNTIME_DIR/quickshell_music_seek_lock"

command="${1:-}"
arg="${2:-}"
len_sec="${3:-}"
player_name="${4:-}"

if [[ -z "$player_name" ]]; then
    player_name="$(playerctl status -f "{{playerName}}" 2>/dev/null || true)"
fi
[[ -n "$player_name" ]] || exit 0

case "$command" in
    seek)
        printf '%s\t%s\t%s\n' "$arg" "$len_sec" "$player_name" > "$SEEK_FILE"

        if [[ -e "$LOCK_FILE" ]]; then
            exit 0
        fi

        : > "$LOCK_FILE"
        (
            sleep 0.05
            IFS=$'\t' read -r final_arg final_len final_player < "$SEEK_FILE"

            if [[ -n "$final_len" && "$final_len" != "0" ]]; then
                target_sec="$(awk -v len="$final_len" -v perc="$final_arg" 'BEGIN { printf "%.2f", (len * perc) / 100 }')"
                playerctl -p "$final_player" position "$target_sec"
            fi

            rm -f "$LOCK_FILE"
        ) &
        ;;
    next)
        playerctl -p "$player_name" next ;;
    prev)
        playerctl -p "$player_name" previous ;;
    play-pause)
        playerctl -p "$player_name" play-pause ;;
esac
