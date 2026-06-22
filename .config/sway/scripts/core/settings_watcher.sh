#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="${SWAY_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/settings.json}"
APPLY_SCRIPT="$SCRIPT_DIR/core/apply-settings.sh"

[[ -x "$APPLY_SCRIPT" || -f "$APPLY_SCRIPT" ]] || exit 0

apply_settings() {
    bash "$APPLY_SCRIPT" >/dev/null 2>&1 || true
}

apply_settings

if command -v inotifywait >/dev/null 2>&1; then
    settings_dir="$(dirname "$SETTINGS_FILE")"
    settings_name="$(basename "$SETTINGS_FILE")"
    mkdir -p "$settings_dir"

    inotifywait -m -q -e close_write,move,create "$settings_dir" 2>/dev/null |
        while read -r _ _ changed_file; do
            [[ "$changed_file" == "$settings_name" ]] || continue
            apply_settings
        done
else
    last_mtime=""
    while true; do
        if [[ -f "$SETTINGS_FILE" ]]; then
            mtime="$(stat -c %Y "$SETTINGS_FILE" 2>/dev/null || stat -f %m "$SETTINGS_FILE" 2>/dev/null || printf 0)"
            if [[ "$mtime" != "$last_mtime" ]]; then
                last_mtime="$mtime"
                apply_settings
            fi
        fi
        sleep 2
    done
fi
