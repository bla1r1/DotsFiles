#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_ENV="$SCRIPT_DIR/core/qt-env.sh"
cleanup() {
    b1air-daemon ddc undim >/dev/null 2>&1 || true
}

b1air-daemon ddc dim >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

quickshell -p ~/.config/quickshell/Lock.qml
