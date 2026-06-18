#!/usr/bin/env bash

# Не запускать второй экземпляр если уже заблокировано
pgrep -x swaylock > /dev/null && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DDCALL="$SCRIPT_DIR/controls/ddcutil_all.sh"
help_text="$(swaylock --help 2>&1 || true)"

supports() {
    grep -q -- "$1" <<< "$help_text"
}

args=(
    --ignore-empty-password
    --color 1a1b26
)

supports '--indicator'          && args+=(--indicator)
supports '--indicator-radius'   && args+=(--indicator-radius 100)
supports '--indicator-thickness' && args+=(--indicator-thickness 7)
supports '--ring-color'         && args+=(--ring-color 7aa2f7)
supports '--key-hl-color'       && args+=(--key-hl-color f7768e)
supports '--bs-hl-color'        && args+=(--bs-hl-color e0af68)
supports '--line-color'         && args+=(--line-color 00000000)
supports '--inside-color'       && args+=(--inside-color 1a1b26cc)
supports '--separator-color'    && args+=(--separator-color 00000000)
supports '--text-color'         && args+=(--text-color c0caf5)
supports '--ring-ver-color'     && args+=(--ring-ver-color 9ece6a)
supports '--inside-ver-color'   && args+=(--inside-ver-color 1a1b26cc)
supports '--text-ver-color'     && args+=(--text-ver-color c0caf5)
supports '--ring-wrong-color'   && args+=(--ring-wrong-color f7768e)
supports '--inside-wrong-color' && args+=(--inside-wrong-color 1a1b26cc)
supports '--text-wrong-color'   && args+=(--text-wrong-color c0caf5)
supports '--grace'              && args+=(--grace 2)
supports '--fade-in'            && args+=(--fade-in 0.2)

if supports '--screenshots'; then
    args+=(--screenshots)
fi

if supports '--clock'; then
    args+=(--clock)
fi

if supports '--effect-blur'; then
    args+=(--effect-blur 5x3)
fi

if supports '--effect-vignette'; then
    args+=(--effect-vignette 0.35:0.35)
fi

if supports '--effect-dim'; then
    args+=(--effect-dim 0.25)
fi

cleanup() {
    bash "$DDCALL" undim >/dev/null 2>&1 || true
}

bash "$DDCALL" dim >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

swaylock "${args[@]}"
