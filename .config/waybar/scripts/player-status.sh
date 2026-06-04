#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    printf '{"text":"󰝚","class":"offline","tooltip":"No jq"}\n'
    exit 0
fi

if ! command -v playerctl >/dev/null 2>&1; then
    jq -n --arg text "󰝚" --arg class "offline" --arg tooltip "No playerctl" \
        '{text: $text, class: $class, tooltip: $tooltip}'
    exit 0
fi

status="$(playerctl status 2>/dev/null || true)"
if [ -z "$status" ]; then
    jq -n --arg text "󰝚" --arg class "offline" --arg tooltip "No active player" \
        '{text: $text, class: $class, tooltip: $tooltip}'
    exit 0
fi

title="$(playerctl metadata --format '{{title}}' 2>/dev/null || true)"
artist="$(playerctl metadata --format '{{artist}}' 2>/dev/null || true)"
player="$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)"

case "$status" in
    Playing) icon=""; class="playing" ;;
    Paused) icon=""; class="paused" ;;
    *) icon="󰝚"; class="stopped" ;;
esac

label="${title:-Media}"
if [ -n "$artist" ]; then
    label="$artist - $label"
fi

if [ "${#label}" -gt 42 ]; then
    label="${label:0:39}..."
fi

tooltip="${artist:+$artist - }${title:-Media}"
if [ -n "$player" ]; then
    tooltip="$tooltip\nvia $player"
fi

jq -n --arg text "$icon  $label" --arg class "$class" --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
