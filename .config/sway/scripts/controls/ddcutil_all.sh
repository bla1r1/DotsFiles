#!/usr/bin/env bash
# ddcutil_all.sh — universal brightness control
# Works with both external monitors (DDC/CI) and laptop built-in displays (backlight)
# Usage: ddcutil_all.sh dim|undim

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
DISPLAY_CACHE="$CACHE_DIR/ddc-displays"
LOCK_FILE="$CACHE_DIR/ddcutil_all.lock"
STATE_FILE="$CACHE_DIR/ddcutil_all.dimmed"
DETECT_TTL=600
EMPTY_DETECT_TTL=30
DDC_TIMEOUT=2s
mkdir -p "$CACHE_DIR"

# --- Helpers ---

have() {
    command -v "$1" >/dev/null 2>&1
}

dim_backlight() {
    have brightnessctl || return 0
    [[ -f "$STATE_FILE" ]] && {
        timeout "$DDC_TIMEOUT" brightnessctl -c backlight set 10% >/dev/null 2>&1 || true
        return 0
    }

    local current tmp
    tmp="$CACHE_DIR/brightness.tmp"

    # Save current raw brightness only after a successful read, then dim to 10%.
    if current="$(timeout "$DDC_TIMEOUT" brightnessctl -c backlight get 2>/dev/null)" && [[ -n "$current" ]]; then
        printf '%s\n' "$current" > "$tmp"
        mv "$tmp" "$CACHE_DIR/brightness"
    else
        rm -f "$tmp"
    fi
    timeout "$DDC_TIMEOUT" brightnessctl -c backlight set 10% >/dev/null 2>&1 || true
}

undim_backlight() {
    have brightnessctl || return 0
    # Restore previously saved brightness, fall back to 100% if cache missing
    local saved
    saved=$(cat "$CACHE_DIR/brightness" 2>/dev/null)
    if [[ -n "$saved" ]]; then
        timeout "$DDC_TIMEOUT" brightnessctl -c backlight set "$saved" >/dev/null 2>&1 || true
    else
        timeout "$DDC_TIMEOUT" brightnessctl -c backlight set 100% >/dev/null 2>&1 || true
    fi
}

cache_is_fresh() {
    [[ -f "$DISPLAY_CACHE" ]] || return 1
    local ttl mtime
    if [[ -s "$DISPLAY_CACHE" ]]; then
        ttl="$DETECT_TTL"
    else
        ttl="$EMPTY_DETECT_TTL"
    fi
    mtime="$(stat -c %Y "$DISPLAY_CACHE" 2>/dev/null || stat -f %m "$DISPLAY_CACHE")"
    [[ $(( $(date +%s) - mtime )) -lt "$ttl" ]]
}

detect_external_displays() {
    have ddcutil || return 0
    cache_is_fresh && return 0

    timeout "$DDC_TIMEOUT" ddcutil detect --brief 2>/dev/null \
        | awk '
            /I2C bus:/ {
                if (match($0, /\/dev\/i2c-[0-9]+/)) {
                    print "bus:" substr($0, RSTART + 9, RLENGTH - 9)
                    found = 1
                }
            }
            /^Display/ && !found { print "display:" $2 }
        ' > "$DISPLAY_CACHE.tmp" || true

    if [[ -s "$DISPLAY_CACHE.tmp" ]]; then
        mv "$DISPLAY_CACHE.tmp" "$DISPLAY_CACHE"
    else
        rm -f "$DISPLAY_CACHE.tmp"
        : > "$DISPLAY_CACHE"
    fi
}

for_each_external() {
    local action="$1" display
    detect_external_displays
    [[ -s "$DISPLAY_CACHE" ]] || return 0

    while read -r display; do
        [[ -n "$display" ]] || continue
        (
            ddc_target=()
            if [[ "$display" == bus:* ]]; then
                ddc_target=(--bus "${display#bus:}")
            elif [[ "$display" == display:* ]]; then
                ddc_target=(--display "${display#display:}")
            else
                ddc_target=(--display "$display")
            fi

            if [[ "$action" == "dim" ]]; then
                if [[ -f "$STATE_FILE" ]]; then
                    timeout "$DDC_TIMEOUT" ddcutil setvcp 10 10 "${ddc_target[@]}" --noverify >/dev/null 2>&1 || true
                    exit 0
                fi

                current=$(timeout "$DDC_TIMEOUT" ddcutil getvcp 10 "${ddc_target[@]}" --noverify 2>/dev/null \
                    | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -n1)
                if [[ -n "$current" ]]; then
                    printf '%s\n' "$current" > "$CACHE_DIR/brightness_display_$display"
                fi
                timeout "$DDC_TIMEOUT" ddcutil setvcp 10 10 "${ddc_target[@]}" --noverify >/dev/null 2>&1 || true
            else
                val=$(cat "$CACHE_DIR/brightness_display_$display" 2>/dev/null)
                timeout "$DDC_TIMEOUT" ddcutil setvcp 10 "${val:-100}" "${ddc_target[@]}" --noverify >/dev/null 2>&1 || true
            fi
        ) &
    done < "$DISPLAY_CACHE"
    wait
}

has_backlight() {
    have brightnessctl || return 1
    # Check if kernel backlight interface exists (laptop internal display)
    ls /sys/class/backlight/*/brightness &>/dev/null
}

has_external() {
    have ddcutil || return 1
    # Check if any DDC/CI monitors are connected
    detect_external_displays
    [[ -s "$DISPLAY_CACHE" ]]
}

# --- Main ---

case "$1" in
    dim)
        exec 9>"$LOCK_FILE"
        flock -n 9 || exit 0
        has_backlight && dim_backlight
        has_external  && for_each_external dim
        : > "$STATE_FILE"
        ;;
    undim)
        exec 9>"$LOCK_FILE"
        flock -w 5 9 || exit 0
        has_backlight && undim_backlight
        has_external  && for_each_external undim
        rm -f "$STATE_FILE"
        ;;
    *)
        echo "Usage: $(basename "$0") dim|undim" >&2
        exit 1
        ;;
esac
