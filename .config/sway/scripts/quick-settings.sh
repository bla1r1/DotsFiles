#!/usr/bin/env bash
# /* ---- 💫 Hyprland Quick Settings 💫 ---- */
# Rofi menu for Hyprland Quick Settings
# Bind: bind = $mainMod SHIFT, E, exec, bash ~/.config/hypr/scripts/quick-settings.sh

# ── Config paths ─────────────────────────────────────────────────
hyprDir="$HOME/.config/hypr"
rofi_theme="$HOME/.config/rofi/config.rasi"
msg=' ⁉️ Choose what to do ⁉️'

# Terminal and editor — reads from your hyprland env
# Override here if needed:
TERM="${terminal:-kitty}"
EDIT="${editor:-nano}"

# ── Notification helper ───────────────────────────────────────────
show_info() {
    notify-send "Info" "$1"
}

show_error() {
    notify-send "ERROR" "$1"
}

# ── Game Mode toggle ──────────────────────────────────────────────
toggle_gamemode() {
    # Disables blur and animations for better performance
    local current
    current=$(hyprctl getoption decoration:blur:enabled | awk 'NR==1{print $2}')

    if [[ "$current" == "1" ]]; then
        hyprctl --batch "keyword decoration:blur:enabled 0 ; keyword animations:enabled 0"
        show_info "Game Mode enabled (blur & animations off)"
    else
        hyprctl --batch "keyword decoration:blur:enabled 1 ; keyword animations:enabled 1"
        show_info "Game Mode disabled (blur & animations on)"
    fi
}

# ── Reload config ─────────────────────────────────────────────────
reload_hyprland() {
    hyprctl reload
    show_info "Hyprland config reloaded ✓"
}

# ── Menu ─────────────────────────────────────────────────────────
menu() {
    cat <<EOF
--- CONFIGS ---
Edit hyprland.conf
Edit keybinds.conf
Edit windowrules.conf
Edit look-and-feel.conf
Edit autostart.conf
Edit input.conf
Edit env.conf
Edit monitors.conf
--- APPEARANCE ---
GTK Settings (nwg-look)
QT Apps Settings (qt6ct)
QT Apps Settings (qt5ct)
--- SYSTEM ---
Network Settings
Audio Settings (pavucontrol)
Bluetooth (blueman)
Configure Monitors (nwg-displays)
--- HYPRLAND ---
Reload Config
Toggle Game Mode
Exit Hyprland
EOF
}

# ── Main ─────────────────────────────────────────────────────────
main() {
    if ! command -v rofi &>/dev/null; then
        show_error "rofi is not installed!"
        exit 1
    fi

    if [[ -f "$rofi_theme" ]]; then
        choice=$(menu | rofi -i -dmenu -config "$rofi_theme" -mesg "$msg")
    else
        choice=$(menu | rofi -i -dmenu -mesg "$msg")
    fi

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        # ── Configs ──
        "Edit hyprland.conf")      file="$hyprDir/hyprland.conf" ;;
        "Edit keybinds.conf")      file="$hyprDir/keybinds.conf" ;;
        "Edit windowrules.conf")   file="$hyprDir/windowrules.conf" ;;
        "Edit look-and-feel.conf") file="$hyprDir/look-and-feel.conf" ;;
        "Edit autostart.conf")     file="$hyprDir/autostart.conf" ;;
        "Edit input.conf")         file="$hyprDir/input.conf" ;;
        "Edit env.conf")           file="$hyprDir/env.conf" ;;
        "Edit monitors.conf")      file="$hyprDir/monitors.conf" ;;

        # ── Appearance ──
        "GTK Settings (nwg-look)")
            if ! command -v nwg-look &>/dev/null; then
                show_error "Install nwg-look first"; exit 1
            fi
            nwg-look ;;
        "QT Apps Settings (qt6ct)")
            if ! command -v qt6ct &>/dev/null; then
                show_error "Install qt6ct first"; exit 1
            fi
            qt6ct ;;
        "QT Apps Settings (qt5ct)")
            if ! command -v qt5ct &>/dev/null; then
                show_error "Install qt5ct first"; exit 1
            fi
            qt5ct ;;

        # ── System ──
        "Network Settings")
            if ! command -v nm-connection-editor &>/dev/null; then
                show_error "Install nm-connection-editor first"; exit 1
            fi
            nm-connection-editor ;;
        "Audio Settings (pavucontrol)")
            if ! command -v pavucontrol &>/dev/null; then
                show_error "Install pavucontrol first"; exit 1
            fi
            pavucontrol ;;
        "Bluetooth (blueman)")
            if ! command -v blueman-manager &>/dev/null; then
                show_error "Install blueman first"; exit 1
            fi
            blueman-manager ;;
        "Configure Monitors (nwg-displays)")
            if ! command -v nwg-displays &>/dev/null; then
                show_error "Install nwg-displays first"; exit 1
            fi
            nwg-displays ;;

        # ── Hyprland ──
        "Reload Config")    reload_hyprland ;;
        "Toggle Game Mode") toggle_gamemode ;;
        "Exit Hyprland")    hyprctl dispatch exit ;;

        *) return ;;
    esac

    # Open the selected file in terminal with editor
    if [[ -n "$file" ]]; then
        if [[ -f "$file" ]]; then
            $TERM -e $EDIT "$file"
        else
            show_error "File not found: $file"
        fi
    fi
}

# If rofi is already running — close it
if pidof rofi > /dev/null; then
    pkill rofi
    exit 0
fi

main
