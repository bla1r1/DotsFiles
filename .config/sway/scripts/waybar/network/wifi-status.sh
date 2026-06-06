#!/usr/bin/env bash
set -euo pipefail

emit() {
    local text="$1"
    local class="$2"
    printf '{"text":"%s","class":"%s"}\n' "$text" "$class"
}

if ! command -v nmcli >/dev/null 2>&1; then
    emit "󰤮" "offline"
    exit 0
fi

radio="$(nmcli -t -f WIFI general 2>/dev/null | head -n1)"
if [ "$radio" != "enabled" ]; then
    emit "󰤮" "off"
    exit 0
fi

line="$(nmcli -t -f IN-USE,SSID,SIGNAL device wifi list 2>/dev/null | awk -F: '$1=="*" {print; exit}')"
if [ -z "$line" ]; then
    emit "󰤯" "disconnected"
    exit 0
fi

signal="$(printf '%s\n' "$line" | awk -F: '{print $3}')"
ssid="$(printf '%s\n' "$line" | awk -F: '{print $2}')"

if [ "${signal:-0}" -ge 80 ]; then
    icon="󰤨"
elif [ "${signal:-0}" -ge 60 ]; then
    icon="󰤥"
elif [ "${signal:-0}" -ge 40 ]; then
    icon="󰤢"
elif [ "${signal:-0}" -ge 20 ]; then
    icon="󰤟"
else
    icon="󰤯"
fi

emit "$icon  ${signal:-0}%" "connected"
