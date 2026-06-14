#!/usr/bin/env bash
set -euo pipefail

DDC_TIMEOUT="${DDC_TIMEOUT:-2s}"
STEP="${BRIGHTNESS_STEP:-5}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
DISPLAY_CACHE="$CACHE_DIR/monitor-brightness-displays"
DETECT_TTL="${BRIGHTNESS_DETECT_TTL:-600}"
EMPTY_DETECT_TTL="${BRIGHTNESS_EMPTY_DETECT_TTL:-30}"

if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="${TMPDIR:-/tmp}/sway-${UID:-$(id -u)}"
    mkdir -p "$CACHE_DIR"
    DISPLAY_CACHE="$CACHE_DIR/monitor-brightness-displays"
fi

cache_is_fresh() {
    [[ -f "$DISPLAY_CACHE" ]] || return 1

    local ttl mtime now
    if [[ -s "$DISPLAY_CACHE" ]]; then
        ttl="$DETECT_TTL"
    else
        ttl="$EMPTY_DETECT_TTL"
    fi

    mtime="$(stat -c %Y "$DISPLAY_CACHE" 2>/dev/null || stat -f %m "$DISPLAY_CACHE" 2>/dev/null || printf 0)"
    now="$(date +%s)"
    [[ $((now - mtime)) -lt "$ttl" ]]
}

json_escape() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }

ddc_displays() {
    command -v ddcutil >/dev/null 2>&1 || return 0

    if cache_is_fresh; then
        cat "$DISPLAY_CACHE"
        return 0
    fi

    timeout "$DDC_TIMEOUT" ddcutil detect --brief 2>/dev/null | awk '
        function emit() {
            if (display == "") return
            id = bus != "" ? "bus:" bus : "display:" display
            label = model != "" ? model : "Display " display
            print id "\t" label
        }
        /^Display/ {
            display = $2
            bus = ""
            model = ""
        }
        /I2C bus:/ {
            if (match($0, /\/dev\/i2c-[0-9]+/)) {
                bus = substr($0, RSTART + 9, RLENGTH - 9)
            }
        }
        /Monitor:/ {
            sub(/^[[:space:]]*Monitor:[[:space:]]*/, "")
            model = $0
        }
        /^$/ { emit(); display = "" }
        END { emit() }
    ' > "$DISPLAY_CACHE.tmp" || true

    if [[ -s "$DISPLAY_CACHE.tmp" ]]; then
        mv "$DISPLAY_CACHE.tmp" "$DISPLAY_CACHE"
    else
        rm -f "$DISPLAY_CACHE.tmp"
        : > "$DISPLAY_CACHE"
    fi

    cat "$DISPLAY_CACHE"
}

ddc_args() {
    local id="$1"
    case "$id" in
        bus:*) printf '%s\n' --bus "${id#bus:}" ;;
        display:*) printf '%s\n' --display "${id#display:}" ;;
        *) printf '%s\n' --display "$id" ;;
    esac
}

get_ddc_percent() {
    local id="$1"
    mapfile -t args < <(ddc_args "$id")
    timeout "$DDC_TIMEOUT" ddcutil getvcp 10 "${args[@]}" --noverify 2>/dev/null \
        | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -n1
}

set_ddc_percent() {
    local id="$1" value="$2"
    mapfile -t args < <(ddc_args "$id")
    timeout "$DDC_TIMEOUT" ddcutil setvcp 10 "$value" "${args[@]}" --noverify >/dev/null 2>&1 || true
}

adjust_ddc_all() {
    local direction="$1" id label pct next

    while IFS=$'\t' read -r id label; do
        [[ -n "$id" ]] || continue
        pct="$(get_ddc_percent "$id" 2>/dev/null || true)"
        [[ "$pct" =~ ^[0-9]+$ ]] || continue

        if [[ "$direction" == "up" ]]; then
            next=$((pct + STEP))
        else
            next=$((pct - STEP))
        fi

        (( next < 1 )) && next=1
        (( next > 100 )) && next=100
        set_ddc_percent "$id" "$next"
    done < <(ddc_displays)
}

print_json() {
    local first=1 id label pct
    printf '['

    while IFS=$'\t' read -r id label; do
        [[ -n "$id" ]] || continue
        pct="$(get_ddc_percent "$id" 2>/dev/null || true)"
        [[ -n "$pct" ]] || continue
        [[ "$first" -eq 0 ]] && printf ','
        printf '{"id":"%s","name":"%s","type":"ddc","brightness":%s}' "$(json_escape "$id")" "$(json_escape "$label")" "$pct"
        first=0
    done < <(ddc_displays)

    printf ']\n'
}

print_waybar_json() {
    local devices avg tooltip
    devices="$("$0" list 2>/dev/null || printf '[]')"
    if [[ "$devices" == "[]" ]]; then
        printf '{"text":"󰃠","tooltip":"No DDC brightness controls found","class":"empty"}\n'
        return 0
    fi

    avg="$(jq '[.[].brightness] | add / length | floor' <<<"$devices")"
    tooltip="$(jq -r '[.[] | "\(.name)  \(.brightness)%"] | join("\\n")' <<<"$devices")"
    printf '{"text":"󰃠  %s%%","tooltip":"%s","class":"active"}\n' "${avg:-0}" "$(json_escape "${tooltip:-Brightness}")"
}

case "${1:-list}" in
    has|has-ddc)
        devices="$("$0" list 2>/dev/null || printf '[]')"
        [[ "$devices" != "[]" ]]
        ;;
    refresh|refresh-ddc)
        rm -f "$DISPLAY_CACHE" "$DISPLAY_CACHE.tmp"
        "$0" list
        ;;
    waybar)
        print_waybar_json
        ;;
    up|down)
        adjust_ddc_all "$1"
        ;;
    list|list-ddc)
        print_json
        ;;
    set)
        id="${2:-}"
        value="${3:-}"
        [[ -n "$id" && "$value" =~ ^[0-9]+$ ]] || exit 1
        (( value < 1 )) && value=1
        (( value > 100 )) && value=100

        set_ddc_percent "$id" "$value"
        ;;
    *)
        printf 'Usage: %s [has|has-ddc|waybar|list|list-ddc|refresh|refresh-ddc|up|down|set id percent]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac
