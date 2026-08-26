#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_ENV="$SCRIPT_DIR/core/qt-env.sh"
MAIN_QML="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/Main.qml"
SETTINGS_WATCHER="$SCRIPT_DIR/core/settings_watcher.sh"
SETTINGS_FILE="$HOME/.config/sway/settings.json"
FOCUSTIME_DAEMON="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/focustime/focus_daemon.sh"
WAYBAR_LAUNCHER="$SCRIPT_DIR/core/waybar.sh"
QS_LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
GUIDE_STARTUP_MARKER="${XDG_RUNTIME_DIR:-/tmp}/qs-guide-startup-opened"

[[ -f "$QT_ENV" ]] && source "$QT_ENV"

mkdir -p "$QS_LOG_DIR"

start_once() {
    local pattern="$1"
    shift

    if ! pgrep -f "$pattern" >/dev/null 2>&1; then
        "$@" >/dev/null 2>&1 &
        disown
    fi
}

start_once "$SETTINGS_WATCHER" bash "$SETTINGS_WATCHER"
start_once "quickshell.*Main\.qml" env QS_SCRIPT_DIR="$SCRIPT_DIR" quickshell -p "$MAIN_QML"
start_once "$FOCUSTIME_DAEMON" bash "$FOCUSTIME_DAEMON"

if command -v waybar >/dev/null 2>&1; then
    start_once "$WAYBAR_LAUNCHER" bash "$WAYBAR_LAUNCHER"
fi

if command -v swayosd-server >/dev/null 2>&1; then
    start_once "swayosd-server$" swayosd-server
fi

# Optional background apps & custom binaries from settings.json
if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS_FILE" ]; then
    # Background preset apps
    if jq -e '.autostartApps | index("telegram") != null' "$SETTINGS_FILE" >/dev/null 2>&1; then
        command -v telegram-desktop >/dev/null 2>&1 && start_once "telegram-desktop" telegram-desktop -startintray
    fi
    if jq -e '.autostartApps | index("discord") != null' "$SETTINGS_FILE" >/dev/null 2>&1; then
        command -v vesktop >/dev/null 2>&1 && start_once "vesktop" vesktop --start-minimized || \
        (command -v discord >/dev/null 2>&1 && start_once "discord" discord --start-minimized)
    fi
    if jq -e '.autostartApps | index("spotify") != null' "$SETTINGS_FILE" >/dev/null 2>&1; then
        command -v spotify >/dev/null 2>&1 && start_once "spotify" spotify --minimized
    fi
    if jq -e '.autostartApps | index("steam") != null' "$SETTINGS_FILE" >/dev/null 2>&1; then
        command -v steam >/dev/null 2>&1 && start_once "steam" steam -silent
    fi

    # Custom binaries and startup scripts
    while IFS= read -r cmd; do
        if [ -n "$cmd" ]; then
            start_once "$cmd" bash -c "$cmd"
        fi
    done < <(jq -r '.autostartCustom[]? | select(.enabled != false) | .command' "$SETTINGS_FILE" 2>/dev/null || true)
fi

if command -v jq >/dev/null 2>&1 \
    && [ -f "$SETTINGS_FILE" ] \
    && jq -e '.openGuideAtStartup == true' "$SETTINGS_FILE" >/dev/null 2>&1 \
    && [ ! -e "$GUIDE_STARTUP_MARKER" ]; then
    : > "$GUIDE_STARTUP_MARKER"
    (
        sleep 0.8
        qs -p "$MAIN_QML" ipc call main toggleGuide
    ) >/dev/null 2>&1 &
    disown
fi
