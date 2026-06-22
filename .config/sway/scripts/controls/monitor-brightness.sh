#!/usr/bin/env bash
set -euo pipefail

DDC_TIMEOUT="${DDC_TIMEOUT:-2s}"
STEP="${BRIGHTNESS_STEP:-5}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
DISPLAY_CACHE="$CACHE_DIR/monitor-brightness-displays"
MISS_CACHE="$CACHE_DIR/monitor-brightness-misses"
VALUE_CACHE_DIR="$CACHE_DIR/monitor-brightness-values"
DETECT_TTL="${BRIGHTNESS_DETECT_TTL:-45}"
EMPTY_DETECT_TTL="${BRIGHTNESS_EMPTY_DETECT_TTL:-10}"
MAX_EMPTY_DETECTS="${BRIGHTNESS_MAX_EMPTY_DETECTS:-3}"

if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="${TMPDIR:-/tmp}/sway-${UID:-$(id -u)}"
    mkdir -p "$CACHE_DIR"
    DISPLAY_CACHE="$CACHE_DIR/monitor-brightness-displays"
    MISS_CACHE="$CACHE_DIR/monitor-brightness-misses"
    VALUE_CACHE_DIR="$CACHE_DIR/monitor-brightness-values"
fi
mkdir -p "$VALUE_CACHE_DIR"

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

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}
cache_key() { local s="$1"; printf '%s' "${s//[^[:alnum:]_.-]/_}"; }

cached_percent() {
    local file="$VALUE_CACHE_DIR/$(cache_key "$1")"
    [[ -r "$file" ]] && sed -n '1p' "$file"
}

remember_percent() {
    local id="$1" value="$2"
    [[ "$value" =~ ^[0-9]+$ ]] || return 0
    printf '%s\n' "$value" > "$VALUE_CACHE_DIR/$(cache_key "$id")"
}

empty_detect_misses() {
    [[ -r "$MISS_CACHE" ]] && sed -n '1p' "$MISS_CACHE" || printf 0
}

set_empty_detect_misses() {
    printf '%s\n' "$1" > "$MISS_CACHE"
}

ddc_displays() {
    command -v ddcutil >/dev/null 2>&1 || return 0

    if [[ "${FORCE_DDC_DETECT:-0}" != "1" ]] && cache_is_fresh; then
        cat "$DISPLAY_CACHE"
        return 0
    fi

    for attempt in 1 2; do
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

        [[ -s "$DISPLAY_CACHE.tmp" ]] && break
        [[ "$attempt" -eq 1 ]] && sleep 0.2
    done

    if [[ -s "$DISPLAY_CACHE.tmp" ]]; then
        rm -f "$MISS_CACHE"
        mv "$DISPLAY_CACHE.tmp" "$DISPLAY_CACHE"
    elif [[ -s "$DISPLAY_CACHE" ]]; then
        local misses
        misses="$(empty_detect_misses)"
        [[ "$misses" =~ ^[0-9]+$ ]] || misses=0
        misses=$((misses + 1))
        set_empty_detect_misses "$misses"
        rm -f "$DISPLAY_CACHE.tmp"

        if (( misses >= MAX_EMPTY_DETECTS )); then
            : > "$DISPLAY_CACHE"
        fi
    else
        rm -f "$DISPLAY_CACHE.tmp" "$MISS_CACHE"
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
    local id="$1" pct
    mapfile -t args < <(ddc_args "$id")
    pct="$(timeout "$DDC_TIMEOUT" ddcutil getvcp 10 "${args[@]}" --noverify 2>/dev/null \
        | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -n1 || true)"

    if [[ "$pct" =~ ^[0-9]+$ ]]; then
        remember_percent "$id" "$pct"
        printf '%s\n' "$pct"
        return 0
    fi

    cached_percent "$id"
}

set_ddc_percent() {
    local id="$1" value="$2"
    mapfile -t args < <(ddc_args "$id")
    timeout "$DDC_TIMEOUT" ddcutil setvcp 10 "$value" "${args[@]}" --noverify >/dev/null 2>&1 || true
    remember_percent "$id" "$value"
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
        [[ "$pct" =~ ^[0-9]+$ ]] || pct=50
        [[ "$first" -eq 0 ]] && printf ','
        printf '{"id":"%s","name":"%s","type":"ddc","brightness":%s}' "$(json_escape "$id")" "$(json_escape "$label")" "$pct"
        first=0
    done < <(ddc_displays)

    printf ']\n'
}

print_waybar_json() {
    local id label pct count=0 sum=0 tooltip=""

    while IFS=$'\t' read -r id label; do
        [[ -n "$id" ]] || continue
        pct="$(get_ddc_percent "$id" 2>/dev/null || true)"
        [[ "$pct" =~ ^[0-9]+$ ]] || pct=50
        count=$((count + 1))
        sum=$((sum + pct))
        tooltip+="${label}  ${pct}%"$'\n'
    done < <(ddc_displays)

    if (( count == 0 )); then
        printf '{"text":"","tooltip":"No DDC brightness controls found","class":"empty"}\n'
        return 0
    fi

    local avg=$((sum / count))
    tooltip="${tooltip%$'\n'}"
    printf '{"text":"󰃠  %s%%","tooltip":"%s","class":"active"}\n' "${avg:-0}" "$(json_escape "${tooltip:-Brightness}")"
}

case "${1:-list}" in
    has|has-ddc)
        devices="$("$0" list 2>/dev/null || printf '[]')"
        [[ "$devices" != "[]" ]]
        ;;
    refresh|refresh-ddc)
        rm -f "$DISPLAY_CACHE.tmp"
        FORCE_DDC_DETECT=1 "$0" list
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
