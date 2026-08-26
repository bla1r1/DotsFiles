#!/usr/bin/env bash
# =============================================================================
# get_schedule.sh — Calendar Schedule Fetcher / Fallback Provider
# =============================================================================
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/schedule"
CACHE_FILE="$CACHE_DIR/schedule.json"
mkdir -p "$CACHE_DIR"

# If user provided a custom generator or json, keep it; otherwise emit clean empty schedule
if [[ ! -f "$CACHE_FILE" ]]; then
    cat << 'EOF' > "$CACHE_FILE"
{
  "header": "No Classes Scheduled",
  "lessons": [],
  "link": ""
}
EOF
fi

cat "$CACHE_FILE"
