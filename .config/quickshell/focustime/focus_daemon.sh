#!/usr/bin/env bash
# =============================================================================
# FocusTime Tracking Daemon (Native Bash + Sway IPC + SQLite)
# =============================================================================
set -euo pipefail

DB_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/focustime"
mkdir -p "$DB_DIR"
DB_PATH="$DB_DIR/focustime.db"

XDG_RUNTIME="${XDG_RUNTIME_DIR:-/tmp/focustime}"
mkdir -p "$XDG_RUNTIME"
STATE_FILE="$XDG_RUNTIME/focustime_state.json"

# Initialize SQLite tables
sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS focus_log (
    log_date TEXT,
    app_class TEXT,
    seconds INTEGER,
    app_title TEXT,
    PRIMARY KEY (log_date, app_class)
);
CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date);
CREATE TABLE IF NOT EXISTS focus_hourly (
    log_date TEXT,
    hour INTEGER,
    app_class TEXT,
    seconds INTEGER,
    PRIMARY KEY (log_date, hour, app_class)
);
CREATE TABLE IF NOT EXISTS focus_intervals (
    log_date TEXT,
    interval_idx INTEGER,
    app_class TEXT,
    seconds INTEGER,
    PRIMARY KEY (log_date, interval_idx, app_class)
);
CREATE TABLE IF NOT EXISTS focus_minutes (
    log_date TEXT,
    minute_idx INTEGER,
    app_class TEXT,
    seconds INTEGER,
    PRIMARY KEY (log_date, minute_idx, app_class)
);
EOF

CURRENT_APP="Desktop"
CURRENT_TITLE="Desktop"

get_active_app() {
    local tree
    if ! tree=$(swaymsg -t get_tree 2>/dev/null); then
        echo "Desktop|Desktop"
        return 0
    fi

    # Find focused node with jq
    local res
    res=$(echo "$tree" | jq -r '
        def find_focused:
            if .focused == true then .
            else (.nodes[]?, .floating_nodes[]? | find_focused) // empty
            end;
        find_focused |
        if . == null then "Desktop|Desktop"
        else
            (.app_id // .window_properties.class // "Unknown") + "|" +
            (.name // .window_properties.title // .app_id // "Unknown")
        end
    ' 2>/dev/null || echo "Desktop|Desktop")

    echo "${res:-Desktop|Desktop}"
}

# Daemon state loop
TICK=0
while true; do
    sleep 1
    TICK=$((TICK + 1))

    # Read active app
    IFS="|" read -r APP_CLS APP_NAME < <(get_active_app)

    # Check lock screen
    if pgrep -x swaylock >/dev/null 2>&1 || pgrep -f "quickshell.*Lock\.qml" >/dev/null 2>&1; then
        APP_CLS="Locked"
        APP_NAME="Locked"
    elif [[ "$APP_CLS" =~ quickshell|qs-master ]]; then
        APP_CLS="Quickshell"
        APP_NAME="Quickshell"
    fi

    [[ -n "$APP_CLS" ]] || APP_CLS="Desktop"
    [[ -n "$APP_NAME" ]] || APP_NAME="$APP_CLS"

    TODAY="$(date +%Y-%m-%d)"
    HOUR=$(date +%H | sed 's/^0*//')
    [[ -n "$HOUR" ]] || HOUR=0
    MINUTE=$(date +%M | sed 's/^0*//')
    [[ -n "$MINUTE" ]] || MINUTE=0
    MIN_IDX=$((HOUR * 60 + MINUTE))
    INTV_IDX=$((MIN_IDX / 15))

    # Batch update every 5 seconds to reduce I/O
    if (( TICK % 5 == 0 )); then
        # Escape quotes in names
        SAFE_CLS="${APP_CLS//\'/\'\'}"
        SAFE_NAME="${APP_NAME//\'/\'\'}"

        sqlite3 "$DB_PATH" << EOF
INSERT INTO focus_log (log_date, app_class, seconds, app_title)
VALUES ('$TODAY', '$SAFE_CLS', 5, '$SAFE_NAME')
ON CONFLICT(log_date, app_class) DO UPDATE SET
    seconds = seconds + 5,
    app_title = '$SAFE_NAME';

INSERT INTO focus_hourly (log_date, hour, app_class, seconds)
VALUES ('$TODAY', $HOUR, '$SAFE_CLS', 5)
ON CONFLICT(log_date, hour, app_class) DO UPDATE SET
    seconds = seconds + 5;

INSERT INTO focus_intervals (log_date, interval_idx, app_class, seconds)
VALUES ('$TODAY', $INTV_IDX, '$SAFE_CLS', 5)
ON CONFLICT(log_date, interval_idx, app_class) DO UPDATE SET
    seconds = seconds + 5;

INSERT INTO focus_minutes (log_date, minute_idx, app_class, seconds)
VALUES ('$TODAY', $MIN_IDX, '$SAFE_CLS', 5)
ON CONFLICT(log_date, minute_idx, app_class) DO UPDATE SET
    seconds = seconds + 5;
EOF

        # Generate lightweight live state JSON for Quickshell
        TOTAL_SECS=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = '$TODAY';")
        TOP_APPS=$(sqlite3 "$DB_PATH" "SELECT json_group_array(json_object('class', app_class, 'name', app_title, 'seconds', seconds)) FROM (SELECT app_class, app_title, seconds FROM focus_log WHERE log_date = '$TODAY' ORDER BY seconds DESC LIMIT 10);")

        cat << EOF > "$STATE_FILE.tmp"
{
  "selected_date": "$TODAY",
  "total": ${TOTAL_SECS:-0},
  "current": "$SAFE_NAME",
  "apps": ${TOP_APPS:-[]}
}
EOF
        mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
done
