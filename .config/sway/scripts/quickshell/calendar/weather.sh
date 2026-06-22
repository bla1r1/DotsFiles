#!/usr/bin/env bash
set -euo pipefail

export LC_NUMERIC=C

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/weather"
if ! mkdir -p "$cache_dir" 2>/dev/null; then
    cache_dir="${TMPDIR:-/tmp}/quickshell-weather-${UID:-$(id -u)}"
    mkdir -p "$cache_dir"
fi

json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
daily_cache_file="${cache_dir}/daily_weather_cache.json"
next_day_cache_file="${cache_dir}/next_day_precache.json"
env_tracker_file="${cache_dir}/.env_tracker"
ENV_FILE="$(dirname "$0")/.env"

OPENWEATHER_KEY="${OPENWEATHER_KEY:-}"
OPENWEATHER_CITY_ID="${OPENWEATHER_CITY_ID:-}"
OPENWEATHER_UNIT="${OPENWEATHER_UNIT:-metric}"

load_env() {
    [[ -f "$ENV_FILE" ]] || return 0

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# || "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key="${key//[[:space:]]/}"
        value="${value%$'\r'}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        case "$key" in
            OPENWEATHER_KEY) OPENWEATHER_KEY="$value" ;;
            OPENWEATHER_CITY_ID) OPENWEATHER_CITY_ID="$value" ;;
            OPENWEATHER_UNIT) OPENWEATHER_UNIT="${value:-metric}" ;;
        esac
    done < "$ENV_FILE"
}

write_dummy_data() {
    jq -n '
        def icon: "";
        { forecast: [
            range(0; 5) as $i
            | (now + ($i * 86400)) as $ts
            | {
                id: ($i | tostring),
                day: ($ts | strftime("%a")),
                day_full: ($ts | strftime("%A")),
                date: ($ts | strftime("%d %b")),
                max: "0.0",
                min: "0.0",
                feels_like: "0.0",
                wind: "0",
                humidity: "0",
                pop: "0",
                icon: icon,
                hex: "#cdd6f4",
                desc: "No API Key",
                hourly: [{time: "00:00", temp: "0.0", icon: icon, hex: "#cdd6f4"}]
            }
        ] }
    ' > "$json_file"
}

json_transform='
def weather_icon($code):
    if ($code == "50d" or $code == "50n") then ""
    elif $code == "01d" then ""
    elif $code == "01n" then ""
    elif ($code | test("^(02|03|04)[dn]$")) then ""
    elif ($code | test("^(09|10)[dn]$")) then ""
    elif ($code == "11d" or $code == "11n") then ""
    elif ($code == "13d" or $code == "13n") then ""
    else ""
    end;

def weather_hex($code):
    if ($code == "50d" or $code == "50n") then "#84afdb"
    elif $code == "01d" then "#f9e2af"
    elif $code == "01n" then "#cba6f7"
    elif ($code | test("^(02|03|04)[dn]$")) then "#bac2de"
    elif ($code | test("^(09|10)[dn]$")) then "#74c7ec"
    elif $code == "11d" then "#f9e2af"
    elif ($code == "13d" or $code == "13n") then "#cdd6f4"
    else "#cdd6f4"
    end;

def one_decimal: ((. * 10 | round) / 10 | tostring);
def titlecase: split(" ") | map(if length > 0 then (.[0:1] | ascii_upcase) + .[1:] else . end) | join(" ");

def day_forecast($idx; $items):
    ($items[(($items | length) / 2 | floor)].weather[0].icon // "04d") as $code
    | {
        id: ($idx | tostring),
        day: ($items[0].dt | strftime("%a")),
        day_full: ($items[0].dt | strftime("%A")),
        date: ($items[0].dt | strftime("%d %b")),
        max: ([$items[].main.temp_max] | max | one_decimal),
        min: ([$items[].main.temp_min] | min | one_decimal),
        feels_like: ([$items[].main.feels_like] | max | one_decimal),
        wind: ([$items[].wind.speed] | max | round | tostring),
        humidity: (([$items[].main.humidity] | add / length) | round | tostring),
        pop: (([$items[].pop] | max // 0) * 100 | floor | tostring),
        icon: weather_icon($code),
        hex: weather_hex($code),
        desc: (($items[(($items | length) / 2 | floor)].weather[0].description // "Unknown") | titlecase),
        hourly: [
            $items[]
            | (.weather[0].icon // "04d") as $hour_code
            | {
                time: (.dt | strftime("%H:%M")),
                temp: (.main.temp | one_decimal),
                icon: weather_icon($hour_code),
                hex: weather_hex($hour_code)
            }
        ]
    };

.list as $items
| ($items | map(.dt_txt[0:10]) | unique | .[:5]) as $dates
| { forecast: [
    range(0; ($dates | length)) as $idx
    | $dates[$idx] as $date
    | day_forecast($idx; [$items[] | select(.dt_txt | startswith($date))])
] }
'

get_data() {
    load_env

    local key="$OPENWEATHER_KEY"
    local city_id="$OPENWEATHER_CITY_ID"
    local unit="${OPENWEATHER_UNIT:-metric}"

    if [[ -z "$key" || "$key" == "Skipped" || "$key" == "OPENWEATHER_KEY" || -z "$city_id" ]]; then
        write_dummy_data
        return
    fi

    local forecast_url raw_api api_cod current_date tomorrow_date
    forecast_url="http://api.openweathermap.org/data/2.5/forecast?APPID=${key}&id=${city_id}&units=${unit}"
    raw_api="$(curl -fsS --max-time 8 "$forecast_url" 2>/dev/null || true)"
    api_cod="$(jq -r '.cod // empty' <<< "$raw_api" 2>/dev/null || true)"

    if [[ -z "$raw_api" || "$api_cod" != "200" ]]; then
        write_dummy_data
        return
    fi

    current_date="$(date +%Y-%m-%d)"
    tomorrow_date="$(date -d "tomorrow" +%Y-%m-%d)"

    if [[ -s "$next_day_cache_file" ]]; then
        precache_date="$(jq -r '.[0].dt_txt[0:10] // empty' "$next_day_cache_file" 2>/dev/null || true)"
        [[ "$precache_date" == "$current_date" ]] && mv "$next_day_cache_file" "$daily_cache_file"
    fi

    api_today_items="$(jq -c --arg date "$current_date" '[.list[] | select(.dt_txt | startswith($date))]' <<< "$raw_api")"
    if [[ -s "$daily_cache_file" ]]; then
        cached_date="$(jq -r '.[0].dt_txt[0:10] // empty' "$daily_cache_file" 2>/dev/null || true)"
        if [[ "$cached_date" == "$current_date" ]]; then
            merged_today="$(jq -c --argjson today "$api_today_items" '(. + $today) | unique_by(.dt) | sort_by(.dt)' "$daily_cache_file")"
        else
            merged_today="$api_today_items"
        fi
    else
        merged_today="$api_today_items"
    fi
    printf '%s\n' "$merged_today" > "$daily_cache_file"

    jq -c --arg date "$tomorrow_date" '[.list[] | select(.dt_txt | startswith($date))]' <<< "$raw_api" > "$next_day_cache_file"

    jq --argjson today "$merged_today" --arg date "$current_date" \
        '.list = ($today + [.list[] | select(.dt_txt | startswith($date) | not)])' \
        <<< "$raw_api" | jq "$json_transform" > "$json_file"
}

json_is_pending() {
    [[ -f "$json_file" ]] && jq -e '.forecast[0].desc == "No API Key"' "$json_file" >/dev/null 2>&1
}

refresh_json_if_needed() {
    local cache_limit=900
    local pending_retry_limit=3600
    local env_changed=0

    if [[ -f "$ENV_FILE" ]]; then
        env_mtime="$(stat -c %Y "$ENV_FILE" 2>/dev/null || stat -f %m "$ENV_FILE" 2>/dev/null || printf 0)"
        last_env_mtime="$(sed -n '1p' "$env_tracker_file" 2>/dev/null || printf 0)"
        if [[ "$env_mtime" -gt "$last_env_mtime" ]]; then
            env_changed=1
            printf '%s\n' "$env_mtime" > "$env_tracker_file"
        fi
    fi

    if [[ -f "$json_file" ]]; then
        file_time="$(stat -c %Y "$json_file" 2>/dev/null || stat -f %m "$json_file" 2>/dev/null || printf 0)"
        current_time="$(date +%s)"
        diff=$((current_time - file_time))

        if [[ "$env_changed" -eq 1 ]]; then
            touch "$json_file"
            get_data &
        elif json_is_pending; then
            if [[ "$diff" -gt "$pending_retry_limit" ]]; then
                touch "$json_file"
                get_data &
            fi
        elif [[ "$diff" -gt "$cache_limit" ]]; then
            touch "$json_file"
            get_data &
        fi
    else
        get_data
    fi
}

current_hourly_jq='(.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0]'

case "${1:---json}" in
    --getdata)
        get_data
        ;;
    --json)
        refresh_json_if_needed
        cat "$json_file"
        ;;
    --view-listener)
        [[ -f "$view_file" ]] || printf '0\n' > "$view_file"
        tail -F "$view_file"
        ;;
    --nav)
        [[ -f "$view_file" ]] || printf '0\n' > "$view_file"
        current="$(sed -n '1p' "$view_file")"
        direction="${2:-}"
        max_idx=4
        if [[ "$direction" == "next" && "$current" -lt "$max_idx" ]]; then
            printf '%s\n' "$((current + 1))" > "$view_file"
        elif [[ "$direction" == "prev" && "$current" -gt 0 ]]; then
            printf '%s\n' "$((current - 1))" > "$view_file"
        fi
        ;;
    --icon)
        jq -r '.forecast[0].icon' "$json_file"
        ;;
    --temp)
        jq -r '.forecast[0].max + "°C"' "$json_file"
        ;;
    --hex)
        jq -r '.forecast[0].hex' "$json_file"
        ;;
    --current-icon)
        curr_time="$(date +%H:%M)"
        jq -r --arg ct "$curr_time" "$current_hourly_jq | .icon" "$json_file"
        ;;
    --current-temp)
        curr_time="$(date +%H:%M)"
        jq -r --arg ct "$curr_time" "$current_hourly_jq | .temp + \"°C\"" "$json_file"
        ;;
    --current-hex)
        curr_time="$(date +%H:%M)"
        jq -r --arg ct "$curr_time" "$current_hourly_jq | .hex" "$json_file"
        ;;
esac
