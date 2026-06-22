#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_ENV="$SCRIPT_DIR/core/qt-env.sh"
DDCALL="$SCRIPT_DIR/controls/ddcutil_all.sh"
[[ -f "$QT_ENV" ]] && source "$QT_ENV"

cleanup() {
    bash "$DDCALL" undim >/dev/null 2>&1 || true
}

bash "$DDCALL" dim >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

quickshell -p ~/.config/sway/scripts/quickshell/Lock.qml
