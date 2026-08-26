#!/usr/bin/env bash
# =============================================================================
# fullscreen-toggle.sh — Seamless Fullscreen <-> Windowed Switcher
#
# Solves the issue where exiting fullscreen in Sway/Wayland breaks window geometry,
# messes up floating coordinates, or traps pointer constraints.
# =============================================================================

set -euo pipefail

# Query focused window properties via Sway IPC
focused_json="$(swaymsg -t get_tree 2>/dev/null | jq -r '
    .. | objects | select(.focused? == true) | {
        id: .id,
        app_id: (.app_id // .window_properties.class // "unknown"),
        fullscreen: (.fullscreen_mode // 0),
        type: .type,
        floating: (.floating == "auto_on" or .floating == "user_on"),
        rect: .rect
    }
' 2>/dev/null || true)"

if [ -z "$focused_json" ] || [ "$focused_json" = "null" ]; then
    # Fallback to standard sway fullscreen toggle if tree parsing fails
    swaymsg fullscreen toggle
    exit 0
fi

is_fullscreen="$(echo "$focused_json" | jq -r '.fullscreen // 0')"
is_floating="$(echo "$focused_json" | jq -r '.floating // false')"
app_id="$(echo "$focused_json" | jq -r '.app_id // ""')"

if [ "$is_fullscreen" != "0" ]; then
    # ── Exit Fullscreen ──────────────────────────────────────────────────────
    swaymsg fullscreen disable

    # If the window is floating (games, media players, dialogs, wine/steam)
    if [ "$is_floating" = "true" ]; then
        # Reset geometry to a safe 16:9 box and center it so it never gets stuck offscreen
        swaymsg resize set width 1280 px height 720 px 2>/dev/null || true
        swaymsg move position center 2>/dev/null || true
    fi
else
    # ── Enter Fullscreen ─────────────────────────────────────────────────────
    swaymsg fullscreen enable
fi
