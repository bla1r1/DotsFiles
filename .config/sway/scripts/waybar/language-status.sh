#!/usr/bin/env bash
# language-status.sh — outputs active keyboard layout shorthand (ABC, UA, DE...) for Waybar

SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/sway/settings.json"
DEFAULT_LANG="us"

if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null 2>&1; then
    DEFAULT_LANG=$(jq -r '.language // "us"' "$SETTINGS" | cut -d',' -f1)
fi

SWAY_LANG=""
if command -v swaymsg >/dev/null 2>&1; then
    SWAY_LANG=$(swaymsg -t get_inputs 2>/dev/null | jq -r '.[] | select(.type=="keyboard") | .xkb_active_layout_name // empty' 2>/dev/null | head -1)
fi

if [[ -z "$SWAY_LANG" ]]; then
    SWAY_LANG="$DEFAULT_LANG"
fi

case "$SWAY_LANG" in
    *[Gg]erman*|*[Dd]eutsch*|"de")
        echo "DE"
        ;;
    *[Uu]krainian*|*Українська*|"ua"|"uk")
        echo "UA"
        ;;
    *[Ff]rench*|*[Ff]rançais*|"fr")
        echo "FR"
        ;;
    *[Ss]panish*|*[Ee]spañol*|"es")
        echo "ES"
        ;;
    *[Pp]olish*|*[Pp]olski*|"pl")
        echo "PL"
        ;;
    *[Ii]talian*|*[Ii]taliano*|"it")
        echo "IT"
        ;;
    *[Rr]ussian*|*Русский*|"ru")
        echo "RU"
        ;;
    *[Ee]nglish*|"us"|"en"|*)
        if [[ "$SWAY_LANG" =~ ^[a-zA-Z]{2,3}$ ]]; then
            echo "${SWAY_LANG^^}"
        else
            echo "ABC"
        fi
        ;;
esac
