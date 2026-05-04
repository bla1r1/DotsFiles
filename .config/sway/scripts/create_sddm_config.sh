#!/usr/bin/env bash
# Updates SilentSDDM default.conf with the current wallpaper
# Called automatically by wallpaper.sh after each wallpaper change

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CURRENT_WALL="$CACHE_DIR/current_wallpaper.jpg"

OUTPUT_CONFIG="$HOME/.config/hypr/sddm-config"
TEMPLATE_CONFIG="$HOME/.config/hypr/sddm-config/sddm-config.template"

# ── Sanity checks ────────────────────────────────────────────────────────────

if [[ ! -f "$CURRENT_WALL" ]]; then
    echo "[sddm-config] No cached wallpaper found at $CURRENT_WALL" >&2
    exit 1
fi

if [[ ! -f "$TEMPLATE_CONFIG" ]]; then
    echo "[sddm-config] Template not found at $TEMPLATE_CONFIG" >&2
    exit 1
fi

# ── Generate config from template ───────────────────────────────────────────

awk -v newbg="\"$CURRENT_WALL\"" '
    /^\[LockScreen\]$/  { in_lock=1; in_login=0 }
    /^\[LoginScreen\]$/ { in_login=1; in_lock=0 }
    /^\[/               { if (!/^\[LockScreen\]$/ && !/^\[LoginScreen\]$/) { in_lock=0; in_login=0 } }
    (in_lock || in_login) && /^background\s*=/ { print "background = " newbg; next }
    { print }
' "$TEMPLATE_CONFIG" > "$OUTPUT_CONFIG"

echo "[sddm-config] Written → $OUTPUT_CONFIG"
