#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="${SWAY_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/settings.json}"
INPUT_CONF="${SWAY_INPUT_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/conf.d/input.conf}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
STATE_FILE="$STATE_DIR/applied-settings.json"
WAYBAR_LAUNCHER="${WAYBAR_LAUNCHER:-$SCRIPT_DIR/core/waybar.sh}"

command -v jq >/dev/null 2>&1 || exit 0
[[ -f "$SETTINGS_FILE" ]] || exit 0

mkdir -p "$STATE_DIR"

current_subset() {
    jq -c '{
        input: {
            language: (.language // "us"),
            kbOptions: (.kbOptions // "")
        },
        waybar: {
            language: (.language // "us"),
            workspaceCount: (.workspaceCount // 8),
            guideShortcut: (.guideShortcut // true),
            topbarHelpIcon: (.topbarHelpIcon // false),
            barPosition: (.barPosition // "top"),
            barShowCava: (.barShowCava // true),
            barShowWeather: (.barShowWeather // true),
            barShowMedia: (.barShowMedia // true),
            barShowTray: (.barShowTray // true),
            barClock24h: (.barClock24h // true)
        },
        windows: {
            gapsInner: (.gapsInner // 8),
            gapsOuter: (.gapsOuter // 4),
            borderWidth: (.borderWidth // 2),
            smartBorders: (.smartBorders // true),
            smartGaps: (.smartGaps // false)
        },
        monitors: {
            workspaceAssignments: (.monitors.workspaceAssignments // [])
        }
    }' "$SETTINGS_FILE"
}

previous_subset() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || printf '{}\n'
}

write_input_conf() {
    local layout="$1"
    local options="$2"
    local tmp

    [[ -f "$INPUT_CONF" ]] || return 0
    tmp="$(mktemp "${INPUT_CONF}.XXXXXX")"

    awk -v layout="$layout" -v options="$options" '
        /^[[:space:]]*xkb_layout[[:space:]]+/ {
            indent = substr($0, 1, match($0, /[^[:space:]]/) - 1)
            print indent "xkb_layout  " layout
            next
        }
        /^[[:space:]]*xkb_options[[:space:]]+/ {
            indent = substr($0, 1, match($0, /[^[:space:]]/) - 1)
            print indent "xkb_options " options
            next
        }
        { print }
    ' "$INPUT_CONF" > "$tmp"

    if ! cmp -s "$tmp" "$INPUT_CONF"; then
        mv "$tmp" "$INPUT_CONF"
        return 10
    fi

    rm -f "$tmp"
    return 0
}

reload_sway() {
    command -v swaymsg >/dev/null 2>&1 && swaymsg reload >/dev/null 2>&1 || true
}

restart_waybar() {
    if [[ -x "$WAYBAR_LAUNCHER" || -f "$WAYBAR_LAUNCHER" ]]; then
        bash "$WAYBAR_LAUNCHER" restart >/dev/null 2>&1 || true
    elif command -v waybar >/dev/null 2>&1; then
        pkill -x waybar >/dev/null 2>&1 || true
        waybar >/dev/null 2>&1 &
        disown
    fi
}

apply_monitor_workspaces() {
    command -v swaymsg >/dev/null 2>&1 || return 0

    jq -r '
        .monitors.workspaceAssignments // []
        | if type == "array" then . else to_entries | map({name: .key, workspaces: .value}) end
        | .[]
        | select((.name // "") != "" and ((.workspaces // "") | tostring | length) > 0)
        | "\(.name)\t\(.workspaces | tostring)"
    ' "$SETTINGS_FILE" | while IFS=$'\t' read -r output workspaces; do
        [[ -n "$output" && -n "$workspaces" ]] || continue
        for workspace in $(printf '%s\n' "$workspaces" | tr ',' ' '); do
            [[ "$workspace" =~ ^[0-9]+$ ]] || continue
            swaymsg workspace number "$workspace" output "$output" >/dev/null 2>&1 || true
        done
    done
}

apply_windows_settings() {
    command -v swaymsg >/dev/null 2>&1 || return 0
    local gi go bw sb sg
    gi="$(jq -r '.windows.gapsInner // 8' <<<"$current")"
    go="$(jq -r '.windows.gapsOuter // 4' <<<"$current")"
    bw="$(jq -r '.windows.borderWidth // 2' <<<"$current")"
    sb="$(jq -r '.windows.smartBorders // true' <<<"$current")"
    sg="$(jq -r '.windows.smartGaps // false' <<<"$current")"

    swaymsg gaps inner all set "$gi" >/dev/null 2>&1 || true
    swaymsg gaps outer all set "$go" >/dev/null 2>&1 || true
    swaymsg default_border pixel "$bw" >/dev/null 2>&1 || true
    swaymsg smart_borders "$([[ "$sb" == "true" ]] && echo "on" || echo "off")" >/dev/null 2>&1 || true
    swaymsg smart_gaps "$([[ "$sg" == "true" ]] && echo "on" || echo "off")" >/dev/null 2>&1 || true
}

current="$(current_subset)"
previous="$(previous_subset)"

input_changed=0
waybar_changed=0
monitors_changed=0
windows_changed=0

if [[ "$(jq -c '.input // {}' <<<"$current")" != "$(jq -c '.input // {}' <<<"$previous")" ]]; then
    input_changed=1
fi

if [[ "$(jq -c '.waybar // {}' <<<"$current")" != "$(jq -c '.waybar // {}' <<<"$previous")" ]]; then
    waybar_changed=1
fi

if [[ "$(jq -c '.monitors // {}' <<<"$current")" != "$(jq -c '.monitors // {}' <<<"$previous")" ]]; then
    monitors_changed=1
fi

if [[ "$(jq -c '.windows // {}' <<<"$current")" != "$(jq -c '.windows // {}' <<<"$previous")" ]]; then
    windows_changed=1
fi

layout="$(jq -r '.input.language' <<<"$current")"
options="$(jq -r '.input.kbOptions' <<<"$current")"

if [[ "$input_changed" -eq 1 ]]; then
    if write_input_conf "$layout" "$options"; then
        :
    elif [[ "$?" -eq 10 ]]; then
        :
    fi
    reload_sway
fi

if [[ "$windows_changed" -eq 1 ]]; then
    apply_windows_settings
fi

if [[ "$waybar_changed" -eq 1 ]]; then
    restart_waybar
fi

if [[ "$monitors_changed" -eq 1 ]]; then
    apply_monitor_workspaces
fi

printf '%s\n' "$current" > "$STATE_FILE"
