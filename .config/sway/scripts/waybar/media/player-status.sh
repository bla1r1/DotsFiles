#!/usr/bin/env bash
set -euo pipefail

max_width=34
separator="  •  "
field_sep=$'\x1f'

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

emit() {
    local text="$1"
    local class="$2"
    local tooltip="$3"
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(json_escape "$text")" \
        "$(json_escape "$class")" \
        "$(json_escape "$tooltip")"
}

if ! command -v playerctl >/dev/null 2>&1; then
    emit "󰝚" "offline" "No playerctl"
    exit 0
fi

metadata="$(
    playerctl metadata --format "{{status}}${field_sep}{{artist}}${field_sep}{{title}}${field_sep}{{playerName}}" 2>/dev/null || true
)"

if [ -z "$metadata" ]; then
    emit "" "hidden" "No active player"
    exit 0
fi

IFS="$field_sep" read -r status artist title player <<< "$metadata"

if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
    emit "" "hidden" "No active player"
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
    printf -v now '%(%s)T' -1
    offset=$(( now % label_length ))
    display_label="${looped_label:$offset}${looped_label:0:$offset}"
    display_label="${display_label:0:$max_width}"
fi

tooltip="${artist:+$artist - }${title:-Media}"
if [ -n "$player" ]; then
    tooltip="$tooltip\nvia $player"
fi

emit "$icon  $display_label" "$class" "$tooltip"
