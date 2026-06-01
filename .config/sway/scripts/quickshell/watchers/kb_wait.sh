#!/usr/bin/env bash
PIPE="/tmp/qs_kb_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null
trap 'rm -f "$PIPE"; kill $(jobs -p) 2>/dev/null; exit 0' EXIT INT TERM

swaymsg -m -t subscribe '["input"]' 2>/dev/null > "$PIPE" &
(sleep 10 && echo "timeout" > "$PIPE") &

read -r _ < "$PIPE"
sleep 0.05
