#!/usr/bin/env bash
# =============================================================================
# Terminal Theme Switcher
# =============================================================================
set -euo pipefail

KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
THEMES_DIR="$KITTY_DIR/themes"
CONF_FILE="$KITTY_DIR/kitty.conf"

list_themes() {
    echo "Available terminal themes:"
    if [ -d "$THEMES_DIR" ]; then
        for f in "$THEMES_DIR"/*.conf; do
            [ -e "$f" ] || continue
            basename "$f" .conf
        done
    fi
}

set_theme() {
    local target="$1"
    local theme_path="$THEMES_DIR/$target.conf"

    if [ ! -f "$theme_path" ]; then
        # Try case-insensitive or partial match
        local match
        match=$(find "$THEMES_DIR" -iname "*$target*.conf" 2>/dev/null | head -1 || true)
        if [ -n "$match" ] && [ -f "$match" ]; then
            theme_path="$match"
            target=$(basename "$match" .conf)
        else
            echo "Error: Theme '$target' not found in $THEMES_DIR"
            list_themes
            exit 1
        fi
    fi

    if [ -f "$CONF_FILE" ]; then
        # Update include line
        sed -i -E "s|^include themes/.*|include themes/$target.conf|" "$CONF_FILE"
        echo "✓ Kitty theme updated to '$target'"
        
        # Live reload all running kitty instances
        if pgrep -x kitty >/dev/null 2>&1; then
            killall -SIGUSR1 kitty 2>/dev/null || true
            echo "✓ Reloaded running Kitty instances"
        fi
    fi
}

case "${1:-}" in
    ""|list)
        list_themes
        ;;
    set)
        if [ -z "${2:-}" ]; then
            echo "Usage: term-theme.sh set <theme-name>"
            list_themes
            exit 1
        fi
        set_theme "$2"
        ;;
    *)
        set_theme "$1"
        ;;
esac
