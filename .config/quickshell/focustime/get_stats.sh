#!/usr/bin/env bash
# =============================================================================
# get_stats.sh — FocusTime Statistics Exporter (Bash + SQLite + jq)
# =============================================================================
set -euo pipefail

DB_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/focustime/focustime.db"
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"
APP_FILTER=""

if [[ "${2:-}" == "--app" && -n "${3:-}" ]]; then
    APP_FILTER="$3"
fi

if [[ ! -f "$DB_PATH" ]]; then
    echo '{ "total": 0, "average": 0, "week_range": "", "yesterday": 0, "current": "History", "apps": [], "week_apps": [], "week": [], "month": [], "hourly": [], "week_heatmap": [], "peak_usage_str": "N/A" }'
    exit 0
fi

# Calculate week bounds (Monday to Sunday)
MONDAY=$(date -d "$TARGET_DATE -$(($(date -d "$TARGET_DATE" +%u) - 1)) days" +%Y-%m-%d 2>/dev/null || date -v-$(($(date -j -f "%Y-%m-%d" "$TARGET_DATE" +%u 2>/dev/null || echo 1) - 1))d -jf "%Y-%m-%d" "$TARGET_DATE" +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")
SUNDAY=$(date -d "$MONDAY +6 days" +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")
YESTERDAY=$(date -d "$TARGET_DATE -1 day" +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")

# Fetch metrics from SQLite
TOTAL_SECS=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = '$TARGET_DATE';")
YESTERDAY_SECS=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = '$YESTERDAY';")
WEEK_TOTAL=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date >= '$MONDAY' AND log_date <= '$SUNDAY';")
DAYS_ACTIVE=$(sqlite3 "$DB_PATH" "SELECT COUNT(DISTINCT log_date) FROM focus_log WHERE log_date >= '$MONDAY' AND log_date <= '$SUNDAY' AND seconds > 0;")
AVG_SECS=0
if [[ "${DAYS_ACTIVE:-0}" -gt 0 ]]; then
    AVG_SECS=$((WEEK_TOTAL / DAYS_ACTIVE))
fi

# Fetch apps for target date
APPS_JSON=$(sqlite3 "$DB_PATH" "
SELECT COALESCE(json_group_array(
    json_object(
        'class', app_class,
        'name', app_title,
        'icon', '',
        'seconds', seconds,
        'percent', CASE WHEN $TOTAL_SECS > 0 THEN ROUND(seconds * 100.0 / $TOTAL_SECS, 1) ELSE 0 END
    )
), '[]')
FROM (
    SELECT app_class, app_title, SUM(seconds) as seconds
    FROM focus_log
    WHERE log_date = '$TARGET_DATE'
    GROUP BY app_class
    ORDER BY seconds DESC
);")

# Fetch week apps
WEEK_APPS_JSON=$(sqlite3 "$DB_PATH" "
SELECT COALESCE(json_group_array(
    json_object(
        'class', app_class,
        'name', app_title,
        'icon', '',
        'seconds', seconds,
        'percent', CASE WHEN $WEEK_TOTAL > 0 THEN ROUND(seconds * 100.0 / $WEEK_TOTAL, 1) ELSE 0 END
    )
), '[]')
FROM (
    SELECT app_class, app_title, SUM(seconds) as seconds
    FROM focus_log
    WHERE log_date >= '$MONDAY' AND log_date <= '$SUNDAY'
    GROUP BY app_class
    ORDER BY seconds DESC
    LIMIT 50
);")

# Output complete structured JSON
jq -n \
    --arg sel_date "$TARGET_DATE" \
    --argjson total "${TOTAL_SECS:-0}" \
    --argjson average "${AVG_SECS:-0}" \
    --arg week_range "$MONDAY - $SUNDAY" \
    --argjson yesterday "${YESTERDAY_SECS:-0}" \
    --arg current "History" \
    --argjson apps "${APPS_JSON:-[]}" \
    --argjson week_apps "${WEEK_APPS_JSON:-[]}" \
    '{
        selected_date: $sel_date,
        total: $total,
        average: $average,
        week_range: $week_range,
        yesterday: $yesterday,
        current: $current,
        apps: $apps,
        week_apps: $week_apps,
        week: [],
        month: [],
        hourly: [],
        week_heatmap: [],
        peak_usage_str: "N/A"
    }'
