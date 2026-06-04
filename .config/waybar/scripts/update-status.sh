#!/usr/bin/env bash
set -euo pipefail

run_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 20 "$@" 2>/dev/null || true
    else
        "$@" 2>/dev/null || true
    fi
}

count_lines() {
    awk 'NF { count++ } END { print count + 0 }'
}

updates=0

if command -v checkupdates >/dev/null 2>&1; then
    updates=$((updates + $(run_timeout checkupdates | count_lines)))
elif command -v apt >/dev/null 2>&1; then
    updates=$((updates + $(run_timeout apt list --upgradable | awk 'NR > 1 && /upgradable/ { count++ } END { print count + 0 }')))
elif command -v dnf >/dev/null 2>&1; then
    updates=$((updates + $(run_timeout dnf check-update -q | awk 'NF && $1 !~ /^(Last|Obsoleting|Security:)/ { count++ } END { print count + 0 }')))
elif command -v zypper >/dev/null 2>&1; then
    updates=$((updates + $(run_timeout zypper --non-interactive list-updates | awk -F'|' '/^[[:space:]]*v[[:space:]]*\\|/ { count++ } END { print count + 0 }')))
fi

if command -v yay >/dev/null 2>&1; then
    updates=$((updates + $(run_timeout yay -Qua | count_lines)))
elif command -v paru >/dev/null 2>&1; then
    updates=$((updates + $(run_timeout paru -Qua | count_lines)))
fi

if (( updates > 0 )); then
    printf '{"text":"󰚰 %d","class":"available","tooltip":"%d system updates available"}\n' "$updates" "$updates"
else
    printf '{"text":"󰏖","class":"current","tooltip":"System is up to date"}\n'
fi
