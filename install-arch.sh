#!/usr/bin/env bash
set -euo pipefail

# Arch Linux installer for this dotfiles repo.
# Installs packages, deploys configs, and enables core services.

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0
NO_AUR=0

for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        --skip-dotfiles) SKIP_DOTFILES=1 ;;
        --skip-services) SKIP_SERVICES=1 ;;
        --no-aur) NO_AUR=1 ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--skip-packages] [--skip-dotfiles] [--skip-services] [--no-aur]"
            exit 1
            ;;
    esac
done

log() { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }

require_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        echo "This installer supports Arch Linux only."
        exit 1
    fi
}

ensure_sudo() {
    sudo -v
}

install_pacman_packages() {
    local pkgs=(
        base-devel git rsync curl unzip
        hyprland hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland
        waybar rofi-wayland swaync
        kitty alacritty firefox nautilus geany fish fastfetch
        wl-clipboard cliphist grim slurp swappy
        copyq
        pipewire wireplumber pipewire-pulse pavucontrol pavucontrol-qt pamixer playerctl
        brightnessctl ddcutil jq
        networkmanager network-manager-applet networkmanager-dmenu blueman
        polkit-kde-agent
        qt5ct qt6ct kvantum
        nwg-look
        python python-gobject
        imagemagick
        noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
    )

    log "Installing pacman packages..."
    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            continue
        fi
        if ! sudo pacman -S --needed --noconfirm "$pkg"; then
            warn "Failed to install pacman package: $pkg"
        fi
    done
}

ensure_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        echo "yay"
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        echo "paru"
        return 0
    fi

    log "Installing yay (AUR helper)..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (
        cd "$tmpdir/yay"
        makepkg -si --noconfirm
    )
    rm -rf "$tmpdir"
    echo "yay"
}

install_aur_packages() {
    local aur_helper="$1"
    local pkgs=(
        catppuccin-cursors-mocha
    )

    log "Installing AUR packages with ${aur_helper}..."
    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            continue
        fi
        if ! "$aur_helper" -S --needed --noconfirm "$pkg"; then
            warn "Failed to install AUR package: $pkg"
        fi
    done
}

deploy_dotfiles() {
    log "Deploying dotfiles from repo..."
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$HOME/.config"

    if [[ -d "$REPO_DIR/.config" ]]; then
        for item in "$REPO_DIR"/.config/*; do
            [[ -e "$item" ]] || continue
            local base
            base="$(basename "$item")"
            if [[ -e "$HOME/.config/$base" || -L "$HOME/.config/$base" ]]; then
                mv "$HOME/.config/$base" "$BACKUP_DIR/$base"
            fi
        done
        rsync -a --delete "$REPO_DIR/.config/" "$HOME/.config/"
    fi

    if [[ -d "$REPO_DIR/etc/fonts" ]]; then
        log "Installing fontconfig snippets to /etc/fonts (sudo)..."
        sudo rsync -a "$REPO_DIR/etc/fonts/" "/etc/fonts/"
    fi

    if [[ -d "$HOME/.config/hypr/scripts" ]]; then
        find "$HOME/.config/hypr/scripts" -type f -name "*.sh" -exec chmod +x {} +
    fi

    log "Dotfiles installed. Backup saved to: $BACKUP_DIR"
}

enable_services() {
    log "Enabling system services..."
    sudo systemctl enable --now NetworkManager || warn "Failed to enable NetworkManager"
    sudo systemctl enable --now bluetooth || warn "Failed to enable bluetooth"
}

main() {
    require_arch
    ensure_sudo

    if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
        install_pacman_packages
        if [[ "$NO_AUR" -eq 0 ]]; then
            local aur_helper
            aur_helper="$(ensure_aur_helper)"
            install_aur_packages "$aur_helper"
        else
            warn "Skipping AUR package install (--no-aur)."
        fi
    else
        warn "Skipping package install (--skip-packages)."
    fi

    if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
        deploy_dotfiles
    else
        warn "Skipping dotfiles deployment (--skip-dotfiles)."
    fi

    if [[ "$SKIP_SERVICES" -eq 0 ]]; then
        enable_services
    else
        warn "Skipping service setup (--skip-services)."
    fi

    log "Done."
    echo "Log out/in (or reboot) after installation."
}

main "$@"
