#!/usr/bin/env bash
set -euo pipefail

max_width=34
separator="  •  "
field_sep=$'\x1f'

if ! command -v jq >/dev/null 2>&1; then
    printf '{"text":"󰝚","class":"offline","tooltip":"No jq"}\n'
    exit 0
fi

if ! command -v playerctl >/dev/null 2>&1; then
    jq -cn --arg text "󰝚" --arg class "offline" --arg tooltip "No playerctl" \
        '{text: $text, class: $class, tooltip: $tooltip}'
    exit 0
fi

metadata="$(
    playerctl metadata --format "{{status}}${field_sep}{{artist}}${field_sep}{{title}}${field_sep}{{playerName}}" 2>/dev/null || true
)"

if [ -z "$metadata" ]; then
    jq -cn --arg text "" --arg class "hidden" --arg tooltip "No active player" \
        '{text: $text, class: $class, tooltip: $tooltip}'
    exit 0
fi

IFS="$field_sep" read -r status artist title player <<< "$metadata"

if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
    jq -cn --arg text "" --arg class "hidden" --arg tooltip "No active player" \
        '{text: $text, class: $class, tooltip: $tooltip}'
    exit 0
fi

case "$status" in
    Playing) icon=""; class="playing" ;;
    Paused) icon=""; class="paused" ;;
    *) icon="󰝚"; class="stopped" ;;
esac

label="${title:-Media}"
if [ -n "$artist" ]; then
    label="$artist - $label"
fi

display_label="$label"
if [ "${#label}" -gt "$max_width" ]; then
    looped_label="${label}${separator}"
    label_length=${#looped_label}
    offset=$(( $(date +%s) % label_length ))
    display_label="${looped_label:$offset}${looped_label:0:$offset}"
    display_label="${display_label:0:$max_width}"
fi

tooltip="${artist:+$artist - }${title:-Media}"
if [ -n "$player" ]; then
    tooltip="$tooltip\nvia $player"
fi

jq -cn --arg text "$icon  $display_label" --arg class "$class" --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
