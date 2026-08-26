#!/usr/bin/env bash

cleanup() {
    b1air-daemon ddc undim >/dev/null 2>&1 || true
}

b1air-daemon ddc dim >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

quickshell -p ~/.config/quickshell/Lock.qml
