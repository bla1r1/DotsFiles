#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
PLATFORM_LIB="$REPO_DIR/.config/sway/scripts/lib/platform.sh"

if [[ -f "$PLATFORM_LIB" ]]; then
    # shellcheck disable=SC1090
    source "$PLATFORM_LIB"
fi

DISTRO=""
SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0
NO_AUR=0

log()  { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $0 [--distro arch] [options]

Options:
  --distro arch     Target distro. Only Arch Linux is supported.
  --skip-packages   Skip package installation
  --skip-dotfiles   Skip deploying dotfiles, fonts, wallpapers, and SDDM config
  --skip-services   Skip enabling system services
  --no-aur          Skip AUR helper/packages
  -h, --help        Show this help and exit
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --distro)        DISTRO="$2"; shift 2 ;;
            --distro=*)      DISTRO="${1#--distro=}"; shift ;;
            --skip-packages) SKIP_PACKAGES=1; shift ;;
            --skip-dotfiles) SKIP_DOTFILES=1; shift ;;
            --skip-services) SKIP_SERVICES=1; shift ;;
            --no-aur)        NO_AUR=1; shift ;;
            -h|--help)       usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if [[ -n "$DISTRO" ]] && declare -F dotfiles_normalize_distro >/dev/null 2>&1; then
        DISTRO="$(dotfiles_normalize_distro "$DISTRO")"
    fi

    if [[ -z "$DISTRO" ]]; then
        if declare -F dotfiles_detect_distro >/dev/null 2>&1; then
            DISTRO="$(dotfiles_detect_distro)"
        elif [[ -f /etc/arch-release ]]; then
            DISTRO="arch"
        else
            echo "Cannot detect distro. Only Arch Linux is supported." >&2
            exit 1
        fi
    fi
}

require_supported_distro() {
    if [[ "$DISTRO" != "arch" ]]; then
        echo "Unsupported distro: $DISTRO. Only Arch Linux is supported." >&2
        exit 1
    fi

    echo "[INFO] Operating as distro: $DISTRO"
}

ensure_sudo() { sudo -v; }

pkg_install() {
    for pkg in "$@"; do
        pacman -Qi "$pkg" >/dev/null 2>&1 && continue
        sudo pacman -S --needed --noconfirm "$pkg" || warn "Failed: $pkg"
    done
}

sync_repos() {
    log "Syncing package repositories..."
    sudo pacman -Sy --noconfirm
}

arch_packages() {
    local pkgs=(
        base-devel git rsync curl unzip
        swaybg swayidle xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        waybar rofi-wayland swaync wlogout quickshell
        kitty firefox nautilus geany fish fastfetch btop telegram-desktop
        wl-clipboard cliphist grim slurp swappy
        xorg-xwayland autotiling
        gnome-power-manager
        starship eza bat ugrep zoxide find-the-command
        wofi python-pywal copyq
        pipewire wireplumber pipewire-pulse pavucontrol pavucontrol-qt pamixer playerctl
        brightnessctl ddcutil jq inotify-tools socat
        pacman-contrib flatpak libnotify trash-cli
        networkmanager network-manager-applet networkmanager-dmenu blueman
        polkit-gnome
        qt5ct qt6ct kvantum qt6-svg qt6-virtualkeyboard
        yad nwg-look nwg-displays
        python python-gobject imagemagick
        noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-fira-sans
        papirus-icon-theme sddm
        gnome-keyring libsecret
        virt-manager steam discord
    )

    [[ "$NO_AUR" -eq 1 ]] && pkgs+=(sway swaylock)
    echo "${pkgs[@]}"
}

aur_packages() {
    local pkgs=(
        swayfx swaylock-effects
        waypaper
        catppuccin-cursors-mocha catppuccin-gtk-theme-mocha
    )

    echo "${pkgs[@]}"
}

install_aur_package_with_fallbacks() {
    local aur_helper="$1"
    shift

    local pkg
    for pkg in "$@"; do
        pacman -Qi "$pkg" >/dev/null 2>&1 && return 0
    done

    for pkg in "$@"; do
        if "$aur_helper" -S --needed --noconfirm "$pkg"; then
            return 0
        fi
        warn "Failed AUR: $pkg"
    done

    return 1
}

install_packages() {
    log "Installing packages (arch)..."
    # shellcheck disable=SC2046
    pkg_install $(arch_packages)
}

ensure_aur_helper() {
    command -v yay  >/dev/null 2>&1 && { echo "yay";  return; }
    command -v paru >/dev/null 2>&1 && { echo "paru"; return; }

    log "Installing yay (AUR helper)..."
    local build_user="${SUDO_USER:-$USER}"
    if [[ "$EUID" -eq 0 && -z "$SUDO_USER" ]]; then
        echo "ERROR: Run as a regular user (not root)." >&2
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
        (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    fi
    rm -rf "$tmpdir"

    command -v yay >/dev/null 2>&1 || { warn "yay not found after build."; exit 1; }
    echo "yay"
}

install_aur_packages() {
    local aur_helper="$1"
    local pkgs=()

    # shellcheck disable=SC2207
    pkgs=($(aur_packages))

    log "Installing AUR packages with ${aur_helper}..."
    for pkg in "${pkgs[@]}"; do
        pacman -Qi "$pkg" >/dev/null 2>&1 && continue
        "$aur_helper" -S --needed --noconfirm "$pkg" || warn "Failed AUR: $pkg"
    done

    install_aur_package_with_fallbacks "$aur_helper" github-desktop-bin github-desktop \
        || warn "Failed to install GitHub Desktop from AUR fallbacks"
}

deploy_sddm_theme() {
    if [[ -d "$REPO_DIR/usr/share/sddm/themes/blair" ]]; then
        log "Installing SDDM theme..."
        sudo install -d -m 755 "/usr/share/sddm/themes/blair"
        sudo rsync -a --delete "$REPO_DIR/usr/share/sddm/themes/blair/" "/usr/share/sddm/themes/blair/"
    else
        warn "SDDM theme dir not found: $REPO_DIR/usr/share/sddm/themes/blair"
    fi

    if [[ -f "$REPO_DIR/etc/sddm.conf" ]]; then
        log "Installing /etc/sddm.conf..."
        sudo install -Dm644 "$REPO_DIR/etc/sddm.conf" "/etc/sddm.conf"
    else
        warn "SDDM config not found: $REPO_DIR/etc/sddm.conf"
    fi
}

setup_sddm_wallpaper_permissions() {
    local wallpaper_group="wallpaper"
    local installer_user="${SUDO_USER:-$USER}"
    local cache_dir="/var/cache/wallpaper"
    local cache_wall="$cache_dir/current.jpg"
    local seed_wall=""

    log "Setting up shared SDDM wallpaper cache in $cache_dir..."
    sudo groupadd -f "$wallpaper_group"
    sudo install -d -o root -g "$wallpaper_group" -m 2775 "$cache_dir"
    id "$installer_user" >/dev/null 2>&1 \
        && sudo usermod -aG "$wallpaper_group" "$installer_user" \
        || warn "Failed to add $installer_user to $wallpaper_group"
    id sddm >/dev/null 2>&1 \
        && sudo usermod -aG "$wallpaper_group" sddm \
        || warn "User 'sddm' not yet created — re-run after first SDDM start."

    if [[ -f "$REPO_DIR/.wallpapers/fallback_bg.jpg" ]]; then
        seed_wall="$REPO_DIR/.wallpapers/fallback_bg.jpg"
    elif [[ -d "$REPO_DIR/.wallpapers" ]]; then
        seed_wall="$(find "$REPO_DIR/.wallpapers" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            | head -n 1 || true)"
    fi

    if [[ -n "$seed_wall" && -f "$seed_wall" ]]; then
        sudo install -o root -g "$wallpaper_group" -m 664 "$seed_wall" "$cache_wall"
    else
        warn "No wallpaper found in $REPO_DIR/.wallpapers to seed $cache_wall"
    fi
}

deploy_dotfiles() {
    log "Deploying dotfiles..."
    mkdir -p "$BACKUP_DIR" "$HOME/.config"

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
        [[ -e "$HOME/.wallpapers" || -L "$HOME/.wallpapers" ]] \
            && mv "$HOME/.wallpapers" "$BACKUP_DIR/.wallpapers"
        rsync -a --delete "$REPO_DIR/.wallpapers/" "$HOME/.wallpapers/"
    fi

    if [[ -d "$REPO_DIR/etc/fonts" ]]; then
        log "Installing fontconfig snippets to /etc/fonts..."
        sudo rsync -a "$REPO_DIR/etc/fonts/" "/etc/fonts/"
    fi

    if [[ -d "$REPO_DIR/usr/share/fontconfig" ]]; then
        log "Installing fontconfig data to /usr/share/fontconfig..."
        sudo rsync -a "$REPO_DIR/usr/share/fontconfig/" "/usr/share/fontconfig/"
    fi

    if [[ -d "$REPO_DIR/etc/fonts" || -d "$REPO_DIR/usr/share/fontconfig" ]]; then
        log "Updating font cache..."
        sudo fc-cache -f || warn "Failed to update font cache"
    fi

    log "Installing Nerd Fonts..."
    if ! command -v git >/dev/null 2>&1; then
        warn "Git not found, skipping Nerd Fonts installation"
    else
        local tmpdir
        tmpdir="$(mktemp -d)"
        git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$tmpdir/nerd-fonts" || warn "Failed to clone Nerd Fonts repo"
        if [[ -f "$tmpdir/nerd-fonts/install.sh" ]]; then
            chmod +x "$tmpdir/nerd-fonts/install.sh"
            "$tmpdir/nerd-fonts/install.sh" || warn "Failed to install Nerd Fonts"
        fi
        rm -rf "$tmpdir"
        log "Nerd Fonts installation completed. Updating font cache again..."
        sudo fc-cache -f || warn "Failed to update font cache after Nerd Fonts"
    fi

    deploy_sddm_theme
    setup_sddm_wallpaper_permissions

    if [[ -d "$HOME/.config/sway/scripts" ]]; then
        find "$HOME/.config/sway/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
    fi

    log "Dotfiles installed. Backup saved to: $BACKUP_DIR"
}

enable_services() {
    log "Enabling system services..."

    svc_enable() {
        sudo systemctl enable --now "$1" || warn "Failed to enable: $1"
    }

    svc_enable NetworkManager
    svc_enable bluetooth

    log "Disabling conflicting display managers..."
    for dm in lightdm gdm gdm3; do
        if systemctl is-enabled "$dm" 2>/dev/null; then
            sudo systemctl disable "$dm" || warn "Failed to disable $dm"
        fi
    done

    svc_enable sddm
}

verify_packages() {
    log "Verifying installed packages..."

    local failed=()
    local all_pkgs=()

    # shellcheck disable=SC2207
    all_pkgs=($(arch_packages))
    if [[ "$NO_AUR" -eq 0 ]]; then
        # shellcheck disable=SC2207
        all_pkgs+=($(aur_packages))
    fi

    for pkg in "${all_pkgs[@]}"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            failed+=("$pkg")
        fi
    done

    if [[ "$NO_AUR" -eq 0 ]]; then
        if ! pacman -Qi github-desktop-bin >/dev/null 2>&1 && ! pacman -Qi github-desktop >/dev/null 2>&1; then
            failed+=("github-desktop-bin|github-desktop")
        fi
    fi

    if [[ ${#failed[@]} -eq 0 ]]; then
        log "All packages verified successfully."
    else
        warn "The following packages failed verification: ${failed[*]}"
    fi
}

post_install_checks() {
    log "Running post-install checks..."

    local issues=()

    if [[ "$SKIP_SERVICES" -eq 0 ]]; then
        for svc in NetworkManager bluetooth sddm; do
            if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
                issues+=("Service $svc is not active")
            fi
        done
    fi

    if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
        [[ -d "$HOME/.config/sway" ]] || issues+=("Sway config not found")
        [[ -d "$HOME/.config/sway/scripts/quickshell" ]] || issues+=("Quickshell Sway config not found")
        [[ -d "$HOME/.wallpapers" ]] || issues+=("Wallpapers not found")
        [[ -d "/usr/share/fontconfig/conf.avail" ]] || issues+=("fontconfig conf.avail not found")
        [[ -d "/usr/share/sddm/themes/blair" ]] || issues+=("SDDM theme not installed")
        [[ -f "/etc/sddm.conf" ]] || issues+=("SDDM config not found")
        [[ -d "/var/cache/wallpaper" ]] || issues+=("Wallpaper cache dir not created")
    fi

    for cmd in sway swaylock quickshell kitty firefox; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            issues+=("Command $cmd not found")
        fi
    done

    if ! fc-list | grep -q "JetBrains"; then
        issues+=("JetBrains fonts not loaded (run fc-cache -f)")
    fi

    if [[ ${#issues[@]} -eq 0 ]]; then
        log "All post-install checks passed."
    else
        warn "Post-install issues found:"
        for issue in "${issues[@]}"; do
            warn "  - $issue"
        done
    fi
}

main() {
    parse_args "$@"
    require_supported_distro
    ensure_sudo
    sync_repos

    if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
        install_packages

        if [[ "$NO_AUR" -eq 0 ]]; then
            local aur_helper
            aur_helper="$(ensure_aur_helper)"
            install_aur_packages "$aur_helper"
        else
            warn "Skipping AUR (--no-aur). Fallback: sway + swaylock installed via pacman."
        fi
    else
        warn "Skipping package install (--skip-packages)."
    fi

    [[ "$SKIP_DOTFILES" -eq 0 ]] && deploy_dotfiles \
        || warn "Skipping dotfiles (--skip-dotfiles)."

    [[ "$SKIP_SERVICES" -eq 0 ]] && enable_services \
        || warn "Skipping services (--skip-services)."

    [[ "$SKIP_PACKAGES" -eq 0 ]] && verify_packages

    post_install_checks

    log "Done."
    echo "Log out/in or reboot after installation."
    echo "Note: group membership changes (wallpaper) require a new login session."
}

main "$@"
