#!/usr/bin/env bash
# ddcutil_all.sh — universal brightness control
# Works with both external monitors (DDC/CI) and laptop built-in displays (backlight)
# Usage: ddcutil_all.sh dim|undim

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
mkdir -p "$CACHE_DIR"

# --- Helpers ---

dim_backlight() {
    # Save current raw brightness value, then dim to 10%
    brightnessctl get > "$CACHE_DIR/brightness"
    brightnessctl set 10%
}

undim_backlight() {
    # Restore previously saved brightness, fall back to 100% if cache missing
    local saved
    saved=$(cat "$CACHE_DIR/brightness" 2>/dev/null)
    if [[ -n "$saved" ]]; then
        brightnessctl set "$saved"
    else
        brightnessctl set 100%
    fi
}

undim_external() {
    local count i
    count=$(ddcutil detect --brief 2>/dev/null | grep -c "^Display")
    for i in $(seq 1 "$count"); do
        (
            val=$(cat "$CACHE_DIR/brightness_display_$i" 2>/dev/null)
            ddcutil setvcp 10 "${val:-100}" --display "$i" --noverify
        ) &
    done
    wait
}

dim_external() {
    local count i
    count=$(ddcutil detect --brief 2>/dev/null | grep -c "^Display")
    for i in $(seq 1 "$count"); do
        (
            current=$(ddcutil getvcp 10 --display "$i" --noverify 2>/dev/null \
                | grep -oP 'current value =\s*\K[0-9]+')
            echo "${current:-100}" > "$CACHE_DIR/brightness_display_$i"
            ddcutil setvcp 10 10 --display "$i" --noverify
        ) &
    done
    wait
}

has_backlight() {
    # Check if kernel backlight interface exists (laptop internal display)
    ls /sys/class/backlight/*/brightness &>/dev/null
}

has_external() {
    # Check if any DDC/CI monitors are connected
    ddcutil detect --brief 2>/dev/null | grep -q "^Display"
}

# --- Main ---

case "$1" in
    dim)
        has_backlight && dim_backlight
        has_external  && dim_external
        ;;
    undim)
        has_backlight && undim_backlight
        has_external  && undim_external
        ;;
    *)
        echo "Usage: $(basename "$0") dim|undim" >&2
        exit 1
        ;;
esac