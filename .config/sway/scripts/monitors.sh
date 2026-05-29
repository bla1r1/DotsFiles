#!/usr/bin/env bash
set -euo pipefail

command -v swaymsg >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

outputs_json="$(swaymsg -t get_outputs 2>/dev/null || true)"
[[ -n "$outputs_json" ]] || exit 0

mapfile -t outputs < <(
    jq -r '
        [.[] | select(.active == true)]
        | sort_by(.rect.x, .rect.y, .name)
        | .[].name
    ' <<< "$outputs_json"
)

[[ "${#outputs[@]}" -gt 0 ]] || exit 0

x=0
workspace=1
for output in "${outputs[@]}"; do
    read -r width height refresh < <(
        jq -r --arg name "$output" '
            .[] | select(.name == $name)
            | (.current_mode // .modes[0] // {})
            | "\(.width // 1920) \(.height // 1080) \(.refresh // 60000)"
        ' <<< "$outputs_json"
    )

    hz=$(( (refresh + 500) / 1000 ))
    [[ "$hz" -gt 0 ]] || hz=60

    swaymsg output "$output" mode "${width}x${height}@${hz}Hz" position "$x" 0 >/dev/null 2>&1 || \
        swaymsg output "$output" position "$x" 0 >/dev/null 2>&1 || true

    swaymsg workspace number "$workspace" output "$output" >/dev/null 2>&1 || true

    x=$(( x + width ))
    workspace=$(( workspace + 1 ))
done
