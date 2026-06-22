#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
TYPE="${2:-}"
ID="${3:-}"
VAL="${4:-}"

case "$TYPE" in
    sink|source|sink-input) ;;
    *) exit 1 ;;
esac

case "$ACTION" in
    set-volume)
        pactl set-$TYPE-volume "$ID" "$VAL%"
        ;;
    toggle-mute)
        pactl set-$TYPE-mute "$ID" toggle
        ;;
    set-default)
        pactl set-default-$TYPE "$ID"
        ;;
esac
