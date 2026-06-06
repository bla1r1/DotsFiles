#!/usr/bin/env bash

dotfiles_has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

dotfiles_normalize_distro() {
    local raw="${1:-}"
    raw="${raw,,}"

    case "$raw" in
        arch|artix)
            printf 'arch\n'
            ;;
        *)
            printf '%s\n' "$raw"
            ;;
    esac
}

dotfiles_detect_distro() {
    local id="" id_like=""

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
        id_like="${ID_LIKE:-}"
    fi

    if [[ -n "$id" ]]; then
        local normalized
        normalized="$(dotfiles_normalize_distro "$id")"
        if [[ "$normalized" == "arch" ]]; then
            printf '%s\n' "$normalized"
            return 0
        fi
    fi

    for candidate in $id_like; do
        local normalized
        normalized="$(dotfiles_normalize_distro "$candidate")"
        if [[ "$normalized" == "arch" ]]; then
            printf '%s\n' "$normalized"
            return 0
        fi
    done

    if [[ -f /etc/arch-release ]]; then
        printf 'arch\n'
    else
        printf 'unknown\n'
    fi
}

dotfiles_pretty_distro() {
    case "${1:-}" in
        arch)     printf 'Arch Linux\n' ;;
        *)        printf 'Unknown\n' ;;
    esac
}

dotfiles_detect_aur_helper() {
    if dotfiles_has_cmd yay; then
        printf 'yay\n'
    elif dotfiles_has_cmd paru; then
        printf 'paru\n'
    else
        return 1
    fi
}

dotfiles_detect_terminal() {
    local candidate
    for candidate in \
        "${TERMINAL:-}" \
        "${terminal:-}" \
        kitty \
        footclient \
        foot \
        wezterm \
        alacritty \
        gnome-terminal \
        konsole \
        xfce4-terminal \
        x-terminal-emulator \
        xterm
    do
        [[ -n "$candidate" ]] || continue
        if dotfiles_has_cmd "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}
