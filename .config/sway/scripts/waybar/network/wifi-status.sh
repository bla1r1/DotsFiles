#!/usr/bin/env bash
# Waybar Wi-Fi module — event-driven, not polled.
#
# Was: forked every 5 seconds and ran two `nmcli` queries, whether or not the
# network had changed. Now one long-lived `nmcli monitor` supplies the events
# and the status is re-read only when something actually happened.
#
# Waybar runs this in continuous mode when the module has no `interval`.
set -uo pipefail

emit() {
    printf '{"text":"%s","class":"%s"}\n' "$1" "$2"
}

status() {
    local radio line in_use signal icon
    radio="$(nmcli -t -f WIFI general 2>/dev/null | head -n1)"
    if [ "$radio" != "enabled" ]; then
        emit "󰤮" "off"
        return
    fi

    line="$(nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null)"
    signal=""
    while IFS=: read -r in_use signal; do
        [ "$in_use" = "*" ] && break
        signal=""
    done <<< "$line"

    if [ -z "$line" ] || [ -z "$signal" ]; then
        emit "󰤯" "disconnected"
        return
    fi

    if   [ "$signal" -ge 80 ]; then icon="󰤨"
    elif [ "$signal" -ge 60 ]; then icon="󰤥"
    elif [ "$signal" -ge 40 ]; then icon="󰤢"
    elif [ "$signal" -ge 20 ]; then icon="󰤟"
    else                            icon="󰤯"
    fi
    emit "$icon  ${signal}%" "connected"
}

if ! command -v nmcli >/dev/null 2>&1; then
    emit "󰤮" "offline"
    sleep infinity
fi

status

# Signal strength drifts without any NM event, so a slow tick runs alongside the
# event stream. 30s, not 5 — the icon steps in 20% bands, so finer is wasted.
#
# Both feed the SAME pipe on purpose: a ticker writing to the script's own
# stdout would send "tick" straight to waybar, which reads stdout as JSON.
{
    nmcli monitor 2>/dev/null &
    monitor=$!
    trap 'kill "$monitor" 2>/dev/null' EXIT
    while sleep 30; do echo tick; done
} | while read -r _; do
    status
done
