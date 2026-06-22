#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_LIB="$SCRIPT_DIR/../lib/platform.sh"

if [[ -f "$PLATFORM_LIB" ]]; then
    # shellcheck disable=SC1090
    source "$PLATFORM_LIB"
fi

threshold_green=0
threshold_yellow=0
threshold_red=50
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway"
CACHE_FILE="$CACHE_DIR/updates-waybar.json"
CACHE_TTL="${UPDATES_CACHE_TTL:-600}"

if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="${TMPDIR:-/tmp}/sway-${UID:-$(id -u)}"
    mkdir -p "$CACHE_DIR"
    CACHE_FILE="$CACHE_DIR/updates-waybar.json"
fi

has_cmd() {
    if declare -F dotfiles_has_cmd >/dev/null 2>&1; then
        dotfiles_has_cmd "$1"
    else
        command -v "$1" >/dev/null 2>&1
    fi
}

detect_distro() {
    if declare -F dotfiles_detect_distro >/dev/null 2>&1; then
        dotfiles_detect_distro
    else
        printf 'unknown\n'
    fi
}

detect_terminal() {
    if declare -F dotfiles_detect_terminal >/dev/null 2>&1; then
        dotfiles_detect_terminal
    fi
}

detect_aur_helper() {
    if declare -F dotfiles_detect_aur_helper >/dev/null 2>&1; then
        dotfiles_detect_aur_helper || true
    elif has_cmd yay; then
        printf 'yay\n'
    elif has_cmd paru; then
        printf 'paru\n'
    fi
}

count_arch_updates() {
    local official=0 extra=0
    if has_cmd checkupdates; then
        official="$(checkupdates 2>/dev/null | wc -l | tr -d ' ')"
    elif has_cmd pacman; then
        official="$(pacman -Qu 2>/dev/null | wc -l | tr -d ' ')"
    fi

    local aur_helper
    aur_helper="$(detect_aur_helper)"
    if [[ -n "$aur_helper" ]]; then
        extra="$("$aur_helper" -Qua 2>/dev/null | wc -l | tr -d ' ')"
    fi

    printf '%s %s\n' "$official" "$extra"
}

count_flatpak_updates() {
    if has_cmd flatpak; then
        flatpak remote-ls --updates 2>/dev/null | wc -l | tr -d ' '
    else
        printf '0\n'
    fi
}

build_upgrade_command() {
    local aur_helper flatpak_cmd=""

    if has_cmd flatpak; then
        flatpak_cmd='; flatpak update -y'
    fi

    aur_helper="$(detect_aur_helper)"
    if [[ -n "$aur_helper" ]]; then
        printf '%s\n' "$aur_helper -Syu${flatpak_cmd}"
    else
        printf '%s\n' "sudo pacman -Syu${flatpak_cmd}"
    fi
}

launch_upgrade_terminal() {
    local update_cmd="$1"
    local terminal

    [[ -n "$update_cmd" ]] || exit 1

    terminal="$(detect_terminal || true)"
    case "$terminal" in
        kitty)
            kitty --title systemupdate sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        footclient)
            footclient sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        foot)
            foot sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        wezterm)
            wezterm start --always-new-process -- sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        alacritty)
            alacritty -e sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        gnome-terminal)
            gnome-terminal -- sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        konsole)
            konsole -p tabtitle=systemupdate -e sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        xfce4-terminal)
            xfce4-terminal --title=systemupdate --command="sh -lc '${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send \"Updates\" \"Upgrade finished successfully\"; else notify-send \"Updates\" \"Upgrade finished with errors\"; fi; fi; printf \"\\nPress Enter to close...\"; read -r _; exit \$status'" &
            ;;
        x-terminal-emulator)
            x-terminal-emulator -e sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        xterm)
            xterm -T systemupdate -e sh -lc "${update_cmd}; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'Updates' 'Upgrade finished successfully'; else notify-send 'Updates' 'Upgrade finished with errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status" &
            ;;
        *)
            if command -v notify-send >/dev/null 2>&1; then
                notify-send "Updates" "No supported terminal found to run the upgrade command"
            fi
            return 1
            ;;
    esac
}

DISTRO="$(detect_distro)"

if [[ "${1:-}" != "up" && -s "$CACHE_FILE" ]]; then
    cache_mtime="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || printf 0)"
    now="$(date +%s)"
    if [[ $((now - cache_mtime)) -lt "$CACHE_TTL" ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

if [[ "${1:-}" == "up" ]]; then
    [[ "$DISTRO" == "arch" ]] || exit 1
    launch_upgrade_terminal "$(build_upgrade_command)"
    exit 0
fi

update_counts="0 0"
[[ "$DISTRO" == "arch" ]] && update_counts="$(count_arch_updates)"

read -r updates_official updates_extra <<<"$update_counts"
updates_flatpak="$(count_flatpak_updates)"
updates_total=$((updates_official + updates_extra + updates_flatpak))

css_class="green"
if (( updates_total > threshold_yellow )); then
    css_class="yellow"
fi
if (( updates_total > threshold_red )); then
    css_class="red"
fi

extra_label="AUR"

if (( updates_total > threshold_green )); then
    output="$(printf '{"text":"%s","alt":"%s","tooltip":"%s System | %s %s | %s Flatpak","class":"%s"}' \
        "$updates_total" "$updates_total" "$updates_official" "$updates_extra" "$extra_label" "$updates_flatpak" "$css_class"
    )"
else
    output='{"text":"0","alt":"0","tooltip":"Packages are up to date","class":"green"}'
fi

printf '%s\n' "$output" > "$CACHE_FILE"
printf '%s' "$output"
