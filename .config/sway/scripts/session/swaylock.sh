#!/usr/bin/env bash
# =============================================================================
# swaylock.sh — b1air Session Screen Lock (Tokyo Night / SDDM Aligned)
# =============================================================================
set -euo pipefail

# Avoid launching multiple lock instances
pgrep -x swaylock >/dev/null 2>&1 && exit 0

HELP_TEXT="$(swaylock --help 2>&1 || true)"

supports() {
    grep -q -- "$1" <<< "$HELP_TEXT"
}

WALLPAPER_CACHE="/var/cache/wallpaper/current.jpg"
USER_WALLPAPER="$HOME/.config/sway/wallpaper.jpg"

args=(
    --ignore-empty-password
    --color "1a1b26"
    --font "JetBrainsMono Nerd Font"
)

# Shared wallpaper fallback
if [[ -f "$WALLPAPER_CACHE" ]]; then
    args+=(--image "$WALLPAPER_CACHE" --scaling fill)
elif [[ -f "$USER_WALLPAPER" ]]; then
    args+=(--image "$USER_WALLPAPER" --scaling fill)
fi

# Tokyo Night Indicator Palette
supports '--indicator-idle-visible'   && args+=(--indicator-idle-visible)
supports '--indicator-radius'         && args+=(--indicator-radius 85)
supports '--indicator-thickness'      && args+=(--indicator-thickness 6)
supports '--ring-color'               && args+=(--ring-color "7aa2f7")
supports '--inside-color'             && args+=(--inside-color "16161ecc")
supports '--line-color'               && args+=(--line-color "00000000")
supports '--separator-color'          && args+=(--separator-color "00000000")
supports '--key-hl-color'             && args+=(--key-hl-color "7aa2f7")
supports '--bs-hl-color'              && args+=(--bs-hl-color "f7768e")
supports '--text-color'               && args+=(--text-color "c0caf5")
supports '--text-clear-color'         && args+=(--text-clear-color "e0af68")
supports '--ring-ver-color'           && args+=(--ring-ver-color "9ece6a")
supports '--inside-ver-color'         && args+=(--inside-ver-color "16161ecc")
supports '--text-ver-color'           && args+=(--text-ver-color "9ece6a")
supports '--ring-wrong-color'         && args+=(--ring-wrong-color "f7768e")
supports '--inside-wrong-color'       && args+=(--inside-wrong-color "16161ecc")
supports '--text-wrong-color'         && args+=(--text-wrong-color "f7768e")
supports '--show-keyboard-layout'     && args+=(--show-keyboard-layout)
supports '--layout-bg-color'          && args+=(--layout-bg-color "16161ecc")
supports '--layout-border-color'      && args+=(--layout-border-color "7aa2f7")
supports '--layout-text-color'        && args+=(--layout-text-color "c0caf5")

# swaylock-effects extensions (if available)
if supports '--screenshots'; then
    args+=(--screenshots)
fi

if supports '--clock'; then
    args+=(--clock)
    supports '--timestr' && args+=(--timestr "%H:%M")
    supports '--datestr' && args+=(--datestr "%A, %B %d, %Y")
fi

if supports '--effect-blur'; then
    args+=(--effect-blur 10x4)
fi

if supports '--effect-dim'; then
    args+=(--effect-dim 0.20)
fi

if supports '--effect-vignette'; then
    args+=(--effect-vignette 0.25:0.25)
fi

supports '--grace'   && args+=(--grace 1)
supports '--fade-in' && args+=(--fade-in 0.2)

cleanup() {
    b1air-daemon ddc undim >/dev/null 2>&1 || true
}

b1air-daemon ddc dim >/dev/null 2>&1 || true
trap cleanup EXIT INT TERM

exec swaylock "${args[@]}"
