#!/usr/bin/env bash
# =============================================================================
# schedule_manager.sh — Manages schedule cache for Quickshell Calendar
# =============================================================================
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/schedule"
CACHE_FILE="${CACHE_DIR}/schedule.json"
CACHE_LIMIT=3600

UPDATER_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/get_schedule.sh"
mkdir -p "$CACHE_DIR"

trigger_update() {
    if [[ -x "$UPDATER_SCRIPT" ]]; then
        bash "$UPDATER_SCRIPT" > "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" || rm -f "$CACHE_FILE.tmp"
    fi
}

if [[ -f "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
    
    current_time=$(date +%s)
    file_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo "$current_time")
    age=$((current_time - file_time))
    
    if [[ "$age" -gt "$CACHE_LIMIT" ]]; then
        trigger_update &
    fi
else
    echo '{ "header": "No Classes Scheduled", "lessons": [], "link": "" }'
    trigger_update &
fi
