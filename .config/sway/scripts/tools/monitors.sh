#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sway/state"
STATE_FILE="$STATE_DIR/monitors-layout.json"

# Called from the shell as well as from sway itself, and swaymsg will not hunt
# for its own socket.
: "${SWAYSOCK:=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/sway-ipc.*.sock 2>/dev/null | head -1)}"
export SWAYSOCK

command -v swaymsg >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

normalize_layout() {
    jq -c '
        def n($fallback): tonumber? // $fallback;
        if type != "array" then [] else . end
        | map({
            name: (.name // "" | tostring),
            resW: (.resW | n(1920) | floor),
            resH: (.resH | n(1080) | floor),
            rate: ((.rate // 60 | tostring) | sub("Hz$"; "")),
            sysScale: (.sysScale | n(1)),
            x: (.x | n(0) | floor),
            y: (.y | n(0) | floor)
        })
        | map(select(.name != "" and .resW > 0 and .resH > 0 and .sysScale > 0))
    '
}

save_layout() {
    local payload="${1:-}"
    [[ -n "$payload" ]] || exit 1

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$payload" | normalize_layout | jq '.' > "$STATE_FILE"
}

apply_layout_payload() {
    local payload="${1:-}"
    [[ -n "$payload" ]] || return 1

    local normalized output_count
    normalized="$(printf '%s\n' "$payload" | normalize_layout)"
    output_count="$(jq 'length' <<< "$normalized")"
    [[ "$output_count" -gt 0 ]] || return 1

    while IFS= read -r output_json; do
        [[ -n "$output_json" ]] || continue

        local name width height rate scale x y mode
        name="$(jq -r '.name' <<< "$output_json")"
        width="$(jq -r '.resW' <<< "$output_json")"
        height="$(jq -r '.resH' <<< "$output_json")"
        rate="$(jq -r '.rate' <<< "$output_json")"
        scale="$(jq -r '.sysScale' <<< "$output_json")"
        x="$(jq -r '.x' <<< "$output_json")"
        y="$(jq -r '.y' <<< "$output_json")"

        mode="${width}x${height}"
        [[ -n "$rate" && "$rate" != "null" ]] && mode="${mode}@${rate}Hz"

        swaymsg output "$name" mode "$mode" position "$x" "$y" scale "$scale" >/dev/null 2>&1 || \
            swaymsg output "$name" position "$x" "$y" scale "$scale" >/dev/null 2>&1 || true
    done < <(jq -c '.[]' <<< "$normalized")

    printf '%s\n' "$normalized"
}

apply_and_save_layout() {
    local payload="${1:-}"
    local applied

    applied="$(apply_layout_payload "$payload")" || return 1
    save_layout "$applied"
}

restore_saved_layout() {
    [[ -f "$STATE_FILE" ]] || return 1

    local outputs_json connected_names saved_subset matched_count
    outputs_json="$(swaymsg -t get_outputs 2>/dev/null || true)"
    [[ -n "$outputs_json" ]] || return 1

    connected_names="$(jq -r '[.[].name] | sort | join("\n")' <<< "$outputs_json")"
    saved_subset="$(
        jq -c --arg connected_names "$connected_names" '
            [ $connected_names | split("\n")[] | select(length > 0) ] as $connected
            | map(select(.name as $name | $connected | index($name)))
        ' "$STATE_FILE" | normalize_layout
    )"
    matched_count="$(jq 'length' <<< "$saved_subset")"
    [[ "$matched_count" -gt 0 ]] || return 1

    apply_layout_payload "$saved_subset" >/dev/null
}

fallback_layout() {
    local outputs_json
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

    local x=0 workspace=1 output width height refresh hz scale logical_width
    for output in "${outputs[@]}"; do
        read -r width height refresh scale < <(
            jq -r --arg name "$output" '
                .[] | select(.name == $name)
                | (.current_mode // .modes[0] // {}) as $mode
                | "\($mode.width // .rect.width // 1920) \($mode.height // .rect.height // 1080) \($mode.refresh // 60000) \(.scale // 1)"
            ' <<< "$outputs_json"
        )

        hz=$(( (refresh + 500) / 1000 ))
        [[ "$hz" -gt 0 ]] || hz=60

        swaymsg output "$output" mode "${width}x${height}@${hz}Hz" position "$x" 0 scale "$scale" >/dev/null 2>&1 || \
            swaymsg output "$output" position "$x" 0 scale "$scale" >/dev/null 2>&1 || true

        swaymsg workspace number "$workspace" output "$output" >/dev/null 2>&1 || true

        logical_width="$(awk -v width="$width" -v scale="$scale" 'BEGIN { printf "%d", width / scale }')"
        x=$(( x + logical_width ))
        workspace=$(( workspace + 1 ))
    done
}

case "${1:-restore}" in
    apply)
        apply_and_save_layout "${2:-}"
        ;;
    save)
        save_layout "${2:-}"
        ;;
    restore)
        restore_saved_layout || fallback_layout
        ;;
    *)
        printf 'usage: %s [restore|apply|save] [layout-json]\n' "$0" >&2
        exit 2
        ;;
esac
