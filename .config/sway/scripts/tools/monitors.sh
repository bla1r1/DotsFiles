#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sway/state"
STATE_FILE="$STATE_DIR/monitors-layout.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_LIB="$SCRIPT_DIR/lib/settings.sh"

[[ -f "$SETTINGS_LIB" ]] && source "$SETTINGS_LIB"

RESTORE_SAVED_LAYOUT=true
AUTO_ARRANGE_FALLBACK=true
if declare -F settings_get_bool >/dev/null 2>&1; then
    RESTORE_SAVED_LAYOUT="$(settings_get_bool monitors.restoreSavedLayout "$RESTORE_SAVED_LAYOUT")"
    AUTO_ARRANGE_FALLBACK="$(settings_get_bool monitors.autoArrangeFallback "$AUTO_ARRANGE_FALLBACK")"
fi

command -v swaymsg >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

save_layout() {
    local payload="${1:-}"
    [[ -n "$payload" ]] || exit 1

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$payload" | jq '.' > "$STATE_FILE"
}

restore_saved_layout() {
    [[ -f "$STATE_FILE" ]] || return 1

    local outputs_json active_names matched_count commands
    outputs_json="$(swaymsg -t get_outputs 2>/dev/null || true)"
    [[ -n "$outputs_json" ]] || return 1

    active_names="$(jq -r '[.[] | select(.active == true) | .name] | sort | join("\n")' <<< "$outputs_json")"
    commands="$(
        jq -r --arg active_names "$active_names" '
            [ $active_names | split("\n")[] | select(length > 0) ] as $active
            | map(select(.name as $name | $active | index($name)))
            | sort_by(.x, .y, .name)
            | .[]
            | "output \(.name) mode \(.resW)x\(.resH)@\(.rate)Hz pos \(.x) \(.y) scale \(.sysScale)"
        ' "$STATE_FILE"
    )"

    matched_count="$(printf '%s\n' "$commands" | awk 'NF { count++ } END { print count + 0 }')"
    [[ "$matched_count" -gt 0 ]] || return 1

    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] || continue
        sh -c "swaymsg $cmd" >/dev/null 2>&1 || true
    done <<< "$commands"

    return 0
}

case "${1:-}" in
    save)
        save_layout "${2:-}"
        exit 0
        ;;
    restore|"")
        if [[ "$RESTORE_SAVED_LAYOUT" == "true" ]] && restore_saved_layout; then
            exit 0
        fi
        ;;
esac

[[ "$AUTO_ARRANGE_FALLBACK" == "true" ]] || exit 0

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
