#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_ENV="$SCRIPT_DIR/core/qt-env.sh"
DDCALL="$SCRIPT_DIR/controls/ddcutil_all.sh"
SETTINGS_LIB="$SCRIPT_DIR/lib/settings.sh"
[[ -f "$QT_ENV" ]] && source "$QT_ENV"
[[ -f "$SETTINGS_LIB" ]] && source "$SETTINGS_LIB"

DIM_ON_LOCK=true
declare -F settings_get_bool >/dev/null 2>&1 && DIM_ON_LOCK="$(settings_get_bool session.dimOnLock "$DIM_ON_LOCK")"

cleanup() {
    bash "$DDCALL" undim >/dev/null 2>&1 || true
}

[[ "$DIM_ON_LOCK" == "true" ]] && bash "$DDCALL" dim >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

quickshell -p ~/.config/sway/scripts/quickshell/Lock.qml
