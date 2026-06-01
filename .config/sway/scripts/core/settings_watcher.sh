#!/usr/bin/env bash

SETTINGS_FILE="$HOME/.config/sway/settings.json"
SWAY_INPUT_CONF="$HOME/.config/sway/conf.d/input.conf"
SWAY_AUTOSTART_CONF="$HOME/.config/sway/conf.d/autostart.conf"
SWAY_ENV_CONF="$HOME/.config/sway/conf.d/env.conf"
ZSH_RC="$HOME/.zshrc"

# Ensure the settings file exists before we try to watch it
mkdir -p "$(dirname "$SETTINGS_FILE")"
[ ! -f "$SETTINGS_FILE" ] && echo "{}" > "$SETTINGS_FILE"
if ! jq empty "$SETTINGS_FILE" >/dev/null 2>&1; then
    cat > "$SETTINGS_FILE" <<'EOF'
{
  "uiScale": 1,
  "openGuideAtStartup": false,
  "topbarHelpIcon": false,
  "wallpaperDir": "~/Pictures/Wallpapers",
  "language": "de,ua",
  "kbOptions": "grp:alt_shift_toggle",
  "workspaceCount": 8
}
EOF
fi

echo "Started watching $SETTINGS_FILE for changes..."

# Loop endlessly, triggering only when the file is saved (closed after writing)
while inotifywait -q -e close_write "$SETTINGS_FILE"; do
    echo "Settings updated! Applying changes..."

    # Extract values using jq 
    # Removed '// empty' from the boolean to prevent 'false' from evaluating to empty
    LANG=$(jq -r '.language // empty' "$SETTINGS_FILE")
    KB_OPT=$(jq -r '.kbOptions // empty' "$SETTINGS_FILE")
    GUIDE_STARTUP=$(jq -r '.openGuideAtStartup' "$SETTINGS_FILE")
    WP_DIR=$(jq -r '.wallpaperDir // empty' "$SETTINGS_FILE")

    # 1. Update Keyboard Layout & Options
    if [ -n "$LANG" ] && [ "$LANG" != "null" ]; then
        swaymsg input "type:keyboard" xkb_layout "$LANG" >/dev/null 2>&1 || true
        sed -i "s/^ *xkb_layout .*/    xkb_layout  $LANG/" "$SWAY_INPUT_CONF"
    fi
    
    if [ -n "$KB_OPT" ] && [ "$KB_OPT" != "null" ]; then
        swaymsg input "type:keyboard" xkb_options "$KB_OPT" >/dev/null 2>&1 || true
        sed -i "s/^ *xkb_options .*/    xkb_options $KB_OPT/" "$SWAY_INPUT_CONF"
    else
        # If it's explicitly empty/null (No Toggle), clear the value entirely
        swaymsg input "type:keyboard" xkb_options "" >/dev/null 2>&1 || true
        sed -i "s/^ *xkb_options .*/    xkb_options /" "$SWAY_INPUT_CONF"
    fi

    # 2. Update Guide Autostart (Comment / Uncomment)
    if [ "$GUIDE_STARTUP" == "true" ]; then
        # Remove any leading hash/spaces to enable the autostart
        sed -i 's|^#*[[:space:]]*exec bash \$HOME/.config/sway/scripts/core/qs_manager.sh toggle guide.*|exec bash $HOME/.config/sway/scripts/core/qs_manager.sh toggle guide|' "$SWAY_AUTOSTART_CONF"
    elif [ "$GUIDE_STARTUP" == "false" ]; then
        # Add a hash to comment it out if it isn't already
        sed -i 's|^exec bash \$HOME/.config/sway/scripts/core/qs_manager.sh toggle guide.*|# exec bash $HOME/.config/sway/scripts/core/qs_manager.sh toggle guide|' "$SWAY_AUTOSTART_CONF"
    fi

    # 3. Update Wallpaper Directory
    if [ -n "$WP_DIR" ] && [ "$WP_DIR" != "null" ]; then
        # We use '|' as the sed delimiter here to prevent path slashes from breaking the command
        if grep -q '^set \$wallpaperDir ' "$SWAY_ENV_CONF"; then
            sed -i "s|^set \\$wallpaperDir .*|set \\$wallpaperDir $WP_DIR|" "$SWAY_ENV_CONF"
        fi
        
        # Keep ZSH in sync if it exists
        if [ -f "$ZSH_RC" ]; then
            sed -i "s|^export WALLPAPER_DIR=.*|export WALLPAPER_DIR=\"$WP_DIR\"|" "$ZSH_RC"
        fi
    fi
done
