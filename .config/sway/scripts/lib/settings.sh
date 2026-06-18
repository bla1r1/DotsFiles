#!/usr/bin/env bash

SETTINGS_FILE="${SWAY_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/settings.json}"

settings_get() {
    local key="$1"
    local fallback="${2:-}"

    if command -v jq >/dev/null 2>&1 && [[ -f "$SETTINGS_FILE" ]]; then
        local value
        value="$(jq -er --arg key "$key" 'getpath($key | split(".")) // empty' "$SETTINGS_FILE" 2>/dev/null || true)"
        if [[ -n "$value" && "$value" != "null" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

    printf '%s\n' "$fallback"
}

settings_get_int() {
    local key="$1"
    local fallback="$2"
    local min="${3:-}"
    local max="${4:-}"
    local value

    value="$(settings_get "$key" "$fallback")"
    [[ "$value" =~ ^[0-9]+$ ]] || value="$fallback"

    if [[ -n "$min" && "$value" -lt "$min" ]]; then
        value="$min"
    fi

    if [[ -n "$max" && "$value" -gt "$max" ]]; then
        value="$max"
    fi

    printf '%s\n' "$value"
}

settings_get_bool() {
    local key="$1"
    local fallback="${2:-true}"
    local value

    value="$(settings_get "$key" "$fallback")"
    value="$(printf '%s\n' "$value" | tr '[:upper:]' '[:lower:]')"
    case "$value" in
        true|1|yes|on) printf 'true\n' ;;
        false|0|no|off) printf 'false\n' ;;
        *) printf '%s\n' "$fallback" ;;
    esac
}
