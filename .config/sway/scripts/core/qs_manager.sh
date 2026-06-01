#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-}}"
if [[ -z "$SRC_DIR" && -f "$HOME/.config/sway/settings.json" ]]; then
    SRC_DIR="$(jq -r '.wallpaperDir // empty' "$HOME/.config/sway/settings.json" 2>/dev/null || true)"
    SRC_DIR="${SRC_DIR/#\~/$HOME}"
fi
SRC_DIR="${SRC_DIR:-$HOME/Pictures/Wallpapers}"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

# User-specific cache directory matching the QML logic
QS_NETWORK_CACHE="${XDG_RUNTIME_DIR:-$HOME/.cache}/qs_network"
mkdir -p "$QS_NETWORK_CACHE"

BUS_SCRIPT="$QS_DIR/core/qs_bus.sh"
BUS_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/qs-ui-bus/main.sock"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"
MAIN_QML_PATH="$QS_DIR/quickshell/Main.qml"
BAR_QML_PATH="$QS_DIR/quickshell/TopBar.qml"
QS_LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
mkdir -p "$QS_LOG_DIR"
QS_MANAGER_LOG="$QS_LOG_DIR/manager.log"

ACTION="${1:-}"
TARGET="${2:-}"
SUBTARGET="${3:-}"

send_ipc() {
    local payload="$1"
    printf '[%s] bus-send %s\n' "$(date '+%F %T')" "$payload" >> "$QS_MANAGER_LOG"
    "$BUS_SCRIPT" send "$payload"
}

send_main_ipc() {
    local action="$1"
    local target="${2:-}"
    local subtarget="${3:-}"

    if [[ "$action" == "close" ]]; then
        send_ipc "close"
    else
        send_ipc "$action:$target:$subtarget"
    fi
}

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    send_main_ipc "close"

    if [[ "${2:-}" == "move" ]]; then
        swaymsg "move container to workspace number $WORKSPACE_NUM" >/dev/null 2>&1
    else
        swaymsg "workspace number $WORKSPACE_NUM" >/dev/null 2>&1
    fi
    exit 0
fi

# -----------------------------------------------------------------------------
# PREP FUNCTIONS
# -----------------------------------------------------------------------------
handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"
    
    # The lock is now inside the subshell. It stops duplicate thumbnailers,
    # but never blocks the main script from opening/closing the widget instantly.
    (
        LOCKFILE="/tmp/qs_manager_wallpaper.lock"
        exec 9> "$LOCKFILE"
        if ! flock -n 9; then
            exit 0
        fi

        for thumb in "$THUMB_DIR"/*; do
            [ -e "$thumb" ] || continue
            filename=$(basename "$thumb")
            clean_name="${filename#000_}"
            if [ ! -f "$SRC_DIR/$clean_name" ]; then rm -f "$thumb"; fi
        done

        for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
            [ -e "$img" ] || continue
            filename=$(basename "$img")
            extension="${filename##*.}"

            if [[ "${extension,,}" == "webp" ]]; then
                new_img="${img%.*}.jpg"
                magick "$img" "$new_img"
                rm -f "$img"
                img="$new_img"
                filename=$(basename "$img")
                extension="jpg"
            fi

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                     ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" > /dev/null 2>&1
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                fi
            fi
        done
    ) &

    TARGET_THUMB=""
    CURRENT_SRC=""

    if pgrep -a "mpvpaper" > /dev/null; then
        CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
        [ -n "$CURRENT_SRC" ] && CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ] && command -v swww >/dev/null; then
        CURRENT_SRC=$(swww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
        [ -n "$CURRENT_SRC" ] && CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -n "$CURRENT_SRC" ]; then
        EXT="${CURRENT_SRC##*.}"
        if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            TARGET_THUMB="000_$CURRENT_SRC"
        else
            TARGET_THUMB="$CURRENT_SRC"
        fi
    fi
    
    export WALLPAPER_THUMB="$TARGET_THUMB"
}

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) &
}

if ! pgrep -f "quickshell.*Main\.qml" >/dev/null; then
    QS_SCRIPT_DIR="$QS_DIR" quickshell -p "$MAIN_QML_PATH" >>"$QS_LOG_DIR/main.log" 2>&1 &
    disown
    sleep 0.2
fi

if ! pgrep -f "quickshell.*TopBar\.qml" >/dev/null; then
    QS_SCRIPT_DIR="$QS_DIR" quickshell -p "$BAR_QML_PATH" >>"$QS_LOG_DIR/topbar.log" 2>&1 &
    disown
fi

if command -v socat >/dev/null 2>&1 && [ ! -S "$BUS_SOCKET" ]; then
    for _ in {1..20}; do
        [ -S "$BUS_SOCKET" ] && break
        sleep 0.025
    done
fi

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    send_main_ipc "close"
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        (bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)
    printf '[%s] action=%s target=%s subtarget=%s\n' "$(date '+%F %T')" "$ACTION" "$TARGET" "$SUBTARGET" >> "$QS_MANAGER_LOG"

    if [[ "$TARGET" == "network" ]]; then
        handle_network_prep
        [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
        send_main_ipc "$ACTION" "$TARGET" "$SUBTARGET"
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        send_main_ipc "$ACTION" "$TARGET" "$WALLPAPER_THUMB"
    else
        send_main_ipc "$ACTION" "$TARGET" "$SUBTARGET"
    fi
    exit 0
fi
