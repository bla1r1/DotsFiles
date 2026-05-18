#!/usr/bin/env bash
set -euo pipefail

sway_dir="$HOME/.config/sway"
conf_dir="$sway_dir/conf.d"
rofi_theme="$HOME/.config/rofi/config.rasi"
msg='Choose an action'

term_cmd="${terminal:-kitty}"
edit_cmd="${editor:-nano}"

notify_info() {
    notify-send "Sway" "$1"
}

notify_error() {
    notify-send "Sway" "$1"
}

run_or_warn() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        notify_error "$hint"
        return 1
    fi
    "$cmd"
}

reload_sway() {
    swaymsg reload >/dev/null
    notify_info "Sway config reloaded"
}

exit_sway() {
    swaymsg exit
}

open_config_in_editor() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        notify_error "File not found: $file"
        return 1
    fi
    "$term_cmd" -e "$edit_cmd" "$file"
}

menu() {
    cat <<EOF
--- CONFIGS ---
Edit config
Edit variables.conf
Edit monitors.conf
Edit env.conf
Edit autostart.conf
Edit look-and-feel.conf
Edit input.conf
Edit keybinds.conf
Edit windowrules.conf
--- APPEARANCE ---
GTK Settings (nwg-look)
QT6 Settings (qt6ct)
QT5 Settings (qt5ct)
--- SYSTEM ---
Network Settings
Audio Settings (pavucontrol)
Bluetooth (blueman)
Display Settings (nwg-displays)
Lock Screen
--- SWAY ---
Reload Config
Exit Sway
EOF
}

main() {
    if ! command -v rofi >/dev/null 2>&1; then
        notify_error "rofi is not installed"
        exit 1
    fi

    local choice
    if [[ -f "$rofi_theme" ]]; then
        choice="$(menu | rofi -i -dmenu -config "$rofi_theme" -mesg "$msg")"
    else
        choice="$(menu | rofi -i -dmenu -mesg "$msg")"
    fi

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        "Edit config")           open_config_in_editor "$sway_dir/config" ;;
        "Edit variables.conf")   open_config_in_editor "$conf_dir/variables.conf" ;;
        "Edit monitors.conf")    open_config_in_editor "$conf_dir/monitors.conf" ;;
        "Edit env.conf")         open_config_in_editor "$conf_dir/env.conf" ;;
        "Edit autostart.conf")   open_config_in_editor "$conf_dir/autostart.conf" ;;
        "Edit look-and-feel.conf") open_config_in_editor "$conf_dir/look-and-feel.conf" ;;
        "Edit input.conf")       open_config_in_editor "$conf_dir/input.conf" ;;
        "Edit keybinds.conf")    open_config_in_editor "$conf_dir/keybinds.conf" ;;
        "Edit windowrules.conf") open_config_in_editor "$conf_dir/windowrules.conf" ;;

        "GTK Settings (nwg-look)") run_or_warn nwg-look "Install nwg-look first" ;;
        "QT6 Settings (qt6ct)")    run_or_warn qt6ct "Install qt6ct first" ;;
        "QT5 Settings (qt5ct)")    run_or_warn qt5ct "Install qt5ct first" ;;

        "Network Settings")
            if ! command -v nm-connection-editor >/dev/null 2>&1; then
                notify_error "Install network-manager-applet first"
                exit 1
            fi
            nm-connection-editor
            ;;
        "Audio Settings (pavucontrol)")
            if command -v pavucontrol >/dev/null 2>&1; then
                pavucontrol
            elif command -v pavucontrol-qt >/dev/null 2>&1; then
                pavucontrol-qt
            else
                notify_error "Install pavucontrol or pavucontrol-qt first"
                exit 1
            fi
            ;;
        "Bluetooth (blueman)")
            if ! command -v blueman-manager >/dev/null 2>&1; then
                notify_error "Install blueman first"
                exit 1
            fi
            blueman-manager
            ;;
        "Display Settings (nwg-displays)")
            if ! command -v nwg-displays >/dev/null 2>&1; then
                notify_error "Install nwg-displays first"
                exit 1
            fi
            nwg-displays
            ;;
        "Lock Screen")
            bash "$HOME/.config/sway/scripts/swaylock.sh"
            ;;

        "Reload Config") reload_sway ;;
        "Exit Sway")     exit_sway ;;
        *) exit 0 ;;
    esac
}

if pidof rofi >/dev/null; then
    pkill rofi
    exit 0
fi

main
