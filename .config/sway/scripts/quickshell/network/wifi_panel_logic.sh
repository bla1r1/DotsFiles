#!/usr/bin/env bash
set -euo pipefail

POWER="$(nmcli radio wifi 2>/dev/null || printf disabled)"

if [[ "$POWER" == "disabled" ]]; then
    echo '{ "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

CACHE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/qs_network"
mkdir -p "$CACHE_DIR"

CURRENT_RAW=$(nmcli -t -f active,ssid,signal,security device wifi | awk -F: '$1=="yes"{print; exit}')

if [[ -n "$CURRENT_RAW" ]]; then
    IFS=':' read -r active ssid signal security <<< "$CURRENT_RAW"
    icon=$(get_icon "$signal")
    
    SAFE_SSID="${ssid//[^a-zA-Z0-9]/_}"
    CACHE_FILE="$CACHE_DIR/wifi_$SAFE_SSID"
    
    if [[ -f "$CACHE_FILE" ]]; then
        while IFS='=' read -r key value; do
            value="${value%\"}"
            value="${value#\"}"
            case "$key" in
                IP) IP="$value" ;;
                FREQ) FREQ="$value" ;;
            esac
        done < "$CACHE_FILE"
    fi
    
    if [ -z "$IP" ] || [ "$IP" == "No IP" ] || [ -z "$FREQ" ]; then
        IFACE=$(nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="wifi"{print $1;exit}')
        IP=$(ip -4 -o addr show dev "$IFACE" 2>/dev/null | awk '{ sub(/\/.*/, "", $4); print $4; exit }')
        [ -z "$IP" ] && IP="No IP"
        
        FREQ=$(iw dev "$IFACE" link 2>/dev/null | awk '/freq:/ {print $2}')
        [ -n "$FREQ" ] && FREQ="${FREQ} MHz" || FREQ="Unknown"
        
        echo "IP=\"$IP\"" > "$CACHE_FILE"
        echo "FREQ=\"$FREQ\"" >> "$CACHE_FILE"
    fi

    # Native Bash JSON generation
    ssid_esc="${ssid//\"/\\\"}"
    sec_esc="${security//\"/\\\"}"
    icon_esc="${icon//\"/\\\"}"
    CONNECTED_JSON="{\"id\":\"$ssid_esc\",\"ssid\":\"$ssid_esc\",\"icon\":\"$icon_esc\",\"signal\":\"$signal\",\"security\":\"$sec_esc\",\"ip\":\"$IP\",\"freq\":\"$FREQ\"}"
else
    CONNECTED_JSON="null"
fi

# AWK processes the entire network list natively, zero sub-shells
NETWORKS_JSON=$(nmcli -t -f active,ssid,signal,security device wifi list --rescan no | awk -F: '
    !seen[$2]++ && $2 != "" && $1 != "yes" {
        ssid=$2; signal=$3; security=$4;
        
        # Escape quotes inside strings
        gsub(/"/, "\\\"", ssid);
        gsub(/"/, "\\\"", security);
        
        if (signal >= 80) icon="󰤨";
        else if (signal >= 60) icon="󰤥";
        else if (signal >= 40) icon="󰤢";
        else if (signal >= 20) icon="󰤟";
        else icon="󰤯";
        
        printf "{\"id\":\"%s\",\"ssid\":\"%s\",\"icon\":\"%s\",\"signal\":\"%s\",\"security\":\"%s\"}\n", ssid, ssid, icon, signal, security
    }
' | head -n 24 | paste -sd, -)

if [ -z "$NETWORKS_JSON" ]; then
    NETWORKS_JSON="[]"
else
    NETWORKS_JSON="[$NETWORKS_JSON]"
fi

# Final JSON output
echo "{\"power\":\"on\",\"connected\":$CONNECTED_JSON,\"networks\":$NETWORKS_JSON}"
