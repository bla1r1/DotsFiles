#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_ENV="$SCRIPT_DIR/core/qt-env.sh"
[[ -f "$QT_ENV" ]] && source "$QT_ENV"

quickshell -p ~/.config/sway/scripts/quickshell/Lock.qml
