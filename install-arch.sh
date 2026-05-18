#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0
NO_AUR=0

log() { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --skip-packages  Skip pacman/AUR package installation
  --skip-dotfiles  Skip deploying dotfiles, fonts, wallpapers, and SDDM config/theme
  --skip-services  Skip enabling system services
  --no-aur         Skip AUR helper/bootstrap and AUR package installation
  -h, --help       Show this help and exit
EOF
}

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --skip-packages) SKIP_PACKAGES=1 ;;
            --skip-dotfiles) SKIP_DOTFILES=1 ;;
            --skip-services) SKIP_SERVICES=1 ;;
            --no-aur) NO_AUR=1 ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $arg" >&2
                usage
                exit 1
                ;;
        esac
    done
}

require_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        echo "This installer supports Arch Linux only."
        exit 1
    fi
}

ensure_sudo() {
    sudo -v
}

sync_repos() {
    log "Syncing pacman repositories..."
    sudo pacman -Sy --noconfirm
}

install_pacman_packages() {
    local pkgs=(
        base-devel git rsync curl unzip
        swaybg swayidle xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        waybar rofi-wayland swaync wlogout
        kitty alacritty firefox nautilus geany fish fastfetch btop
        wl-clipboard cliphist grim slurp swappy
        xorg-xwayland
        autotiling
        gnome-power-manager
        starship eza bat ugrep zoxide find-the-command
        wofi python-pywal
        copyq
        waypaper
        pipewire wireplumber pipewire-pulse pavucontrol pavucontrol-qt pamixer playerctl
        brightnessctl ddcutil jq
        pacman-contrib flatpak
        libnotify
        networkmanager network-manager-applet networkmanager-dmenu blueman
        polkit-gnome
        qt5ct qt6ct kvantum qt6-svg qt6-virtualkeyboard
        yad
        nwg-look nwg-displays
        python python-gobject
        imagemagick
        noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-fira-sans
        papirus-icon-theme
        sddm
        gnome-keyring libsecret
        snapd
        virt-manager steam discord
    )

    if [[ "$NO_AUR" -eq 1 ]]; then
        pkgs+=(sway swaylock)
    fi

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

    local build_user="${SUDO_USER:-$USER}"
    if [[ "$EUID" -eq 0 && -z "$SUDO_USER" ]]; then
        echo "ERROR: Run this script as a regular user (not root), or via sudo from a regular user."
        exit 1
    fi

    local tmpdir
    tmpdir="$(mktemp -d)"
    chown "$build_user" "$tmpdir"

    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    chown -R "$build_user" "$tmpdir/yay"

    if [[ "$EUID" -eq 0 ]]; then
        sudo -u "$build_user" bash -c "cd '$tmpdir/yay' && makepkg -si --noconfirm"
    else
        (
            cd "$tmpdir/yay"
            makepkg -si --noconfirm
        )
    fi

    rm -rf "$tmpdir"

    if ! command -v yay >/dev/null 2>&1; then
        warn "yay was not found after build. Check logs above."
        exit 1
    fi

    echo "yay"
}

install_aur_packages() {
    local aur_helper="$1"
    local pkgs=(
        swayfx
        swaylock-effects
        catppuccin-cursors-mocha
        catppuccin-gtk-theme-mocha
        github-desktop-bin
        snap-store
        telegram-desktop
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

deploy_sddm_theme() {
    if [[ -d "$REPO_DIR/usr/share/sddm/themes/blair" ]]; then
        log "Installing SDDM theme to /usr/share/sddm/themes/blair (sudo)..."
        sudo install -d -m 755 "/usr/share/sddm/themes/blair"
        sudo rsync -a --delete "$REPO_DIR/usr/share/sddm/themes/blair/" "/usr/share/sddm/themes/blair/"
    else
        warn "SDDM theme directory not found in repo: $REPO_DIR/usr/share/sddm/themes/blair"
    fi

    if [[ -f "$REPO_DIR/etc/sddm.conf" ]]; then
        log "Installing /etc/sddm.conf (sudo)..."
        sudo install -Dm644 "$REPO_DIR/etc/sddm.conf" "/etc/sddm.conf"
    else
        warn "SDDM config not found in repo: $REPO_DIR/etc/sddm.conf"
    fi
}

setup_sddm_wallpaper_permissions() {
    local wallpaper_group="wallpaper"
    local installer_user="${SUDO_USER:-$USER}"
    local cache_dir="/var/cache/wallpaper"
    local cache_wall="$cache_dir/current.jpg"
    local seed_wall=""

    log "Setting up shared SDDM wallpaper cache in $cache_dir (sudo)..."
    sudo groupadd -f "$wallpaper_group"
    sudo install -d -o root -g "$wallpaper_group" -m 2775 "$cache_dir"

    if id "$installer_user" >/dev/null 2>&1; then
        sudo usermod -aG "$wallpaper_group" "$installer_user" || warn "Failed to add $installer_user to $wallpaper_group"
    fi

    if id sddm >/dev/null 2>&1; then
        sudo usermod -aG "$wallpaper_group" sddm || warn "Failed to add sddm user to $wallpaper_group"
    else
        warn "User 'sddm' does not exist yet. Install/start SDDM and re-run to grant group access."
    fi

    if [[ -f "$REPO_DIR/.wallpapers/fallback_bg.jpg" ]]; then
        seed_wall="$REPO_DIR/.wallpapers/fallback_bg.jpg"
    elif [[ -d "$REPO_DIR/.wallpapers" ]]; then
        seed_wall="$(find "$REPO_DIR/.wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | head -n 1 || true)"
    fi

    if [[ -n "$seed_wall" && -f "$seed_wall" ]]; then
        sudo install -o root -g "$wallpaper_group" -m 664 "$seed_wall" "$cache_wall"
    else
        warn "No wallpaper found in $REPO_DIR/.wallpapers to seed $cache_wall"
    fi
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

    if [[ -d "$REPO_DIR/.wallpapers" ]]; then
        if [[ -e "$HOME/.wallpapers" || -L "$HOME/.wallpapers" ]]; then
            mv "$HOME/.wallpapers" "$BACKUP_DIR/.wallpapers"
        fi
        rsync -a --delete "$REPO_DIR/.wallpapers/" "$HOME/.wallpapers/"
    fi

    if [[ -d "$REPO_DIR/etc/fonts" ]]; then
        log "Installing fontconfig snippets to /etc/fonts (sudo)..."
        sudo rsync -a "$REPO_DIR/etc/fonts/" "/etc/fonts/"
    fi

    deploy_sddm_theme
    setup_sddm_wallpaper_permissions

    if [[ -d "$HOME/.config/sway/scripts" ]]; then
        find "$HOME/.config/sway/scripts" -type f -name "*.sh" -exec chmod +x {} +
    fi

    log "Dotfiles installed. Backup saved to: $BACKUP_DIR"
}

enable_services() {
    log "Enabling system services..."
    sudo systemctl enable --now NetworkManager   || warn "Failed to enable NetworkManager"
    sudo systemctl enable --now bluetooth        || warn "Failed to enable bluetooth"
    sudo systemctl enable --now sddm             || warn "Failed to enable/start sddm"

    sudo systemctl enable --now snapd            || warn "Failed to enable snapd"
    sudo systemctl enable --now snapd.apparmor   || warn "Failed to enable snapd.apparmor"
    if [[ ! -L /snap ]]; then
        sudo ln -s /var/lib/snapd/snap /snap     || warn "Failed to create /snap symlink"
    fi
}

main() {
    parse_args "$@"

    require_arch
    ensure_sudo

    sync_repos

    if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
        install_pacman_packages
        if [[ "$NO_AUR" -eq 0 ]]; then
            local aur_helper
            aur_helper="$(ensure_aur_helper)"
            install_aur_packages "$aur_helper"
        else
            warn "Skipping AUR package install (--no-aur)."
            warn "Installed fallback compositor: sway + swaylock (without swayfx effects)."
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
    echo "Note: group membership changes (wallpaper group) require a new login session."
    echo "Note: for snap classic confinement the /snap symlink requires a reboot or new shell."
}

main "$@"

