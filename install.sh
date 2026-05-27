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

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $0 --distro <arch|debian|fedora|gentoo|opensuse> [options]

Options:
  --distro <n>     Target distro: arch, debian, fedora, gentoo, opensuse  (required)
  --skip-packages  Skip package installation
  --skip-dotfiles  Skip deploying dotfiles, fonts, wallpapers, and SDDM config
  --skip-services  Skip enabling system services
  --no-aur         Skip AUR helper/packages (Arch only)
  -h, --help       Show this help and exit
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
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

    # Auto-detect if not given
    if [[ -z "$DISTRO" ]]; then
        if declare -F dotfiles_detect_distro >/dev/null 2>&1; then
            DISTRO="$(dotfiles_detect_distro)"
        else
            if   [[ -f /etc/arch-release ]];   then DISTRO="arch"
            elif [[ -f /etc/debian_version ]]; then DISTRO="debian"
            elif [[ -f /etc/fedora-release ]]; then DISTRO="fedora"
            elif [[ -f /etc/gentoo-release ]]; then DISTRO="gentoo"
            elif [[ -f /etc/SuSE-release ]] || grep -qi opensuse /etc/os-release 2>/dev/null; then
                DISTRO="opensuse"
            else
                echo "Cannot detect distro. Pass --distro arch|debian|fedora|gentoo|opensuse" >&2
                exit 1
            fi
        fi
    fi
}

# ── Distro validation ─────────────────────────────────────────────────────────
require_supported_distro() {
    case "$DISTRO" in
        arch|debian|fedora|gentoo|opensuse) ;;
        *)
            echo "Unsupported distro: $DISTRO. Choose arch, debian, fedora, gentoo, or opensuse." >&2
            exit 1
            ;;
    esac
    echo "[INFO] Operating as distro: $DISTRO"
}

ensure_sudo() { sudo -v; }

# ── Package manager helpers ───────────────────────────────────────────────────
pkg_install() {
    # Installs only packages not already present, per distro.
    case "$DISTRO" in
        arch)
            for pkg in "$@"; do
                pacman -Qi "$pkg" >/dev/null 2>&1 && continue
                sudo pacman -S --needed --noconfirm "$pkg" || warn "Failed: $pkg"
            done
            ;;
        debian)
            local missing=()
            for pkg in "$@"; do
                dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
            done
            [[ ${#missing[@]} -eq 0 ]] && return 0
            sudo apt-get install -y --no-install-recommends "${missing[@]}" \
                || warn "Some Debian packages failed: ${missing[*]}"
            ;;
        fedora)
            for pkg in "$@"; do
                rpm -q "$pkg" >/dev/null 2>&1 && continue
                sudo dnf install -y "$pkg" || warn "Failed: $pkg"
            done
            ;;
        gentoo)
            for pkg in "$@"; do
                sudo emerge --ask=n --noreplace "$pkg" || warn "Failed: $pkg"
            done
            ;;
        opensuse)
            for pkg in "$@"; do
                rpm -q "$pkg" >/dev/null 2>&1 && continue
                sudo zypper --non-interactive install "$pkg" || warn "Failed: $pkg"
            done
            ;;
    esac
}

sync_repos() {
    log "Syncing package repositories..."
    case "$DISTRO" in
        arch)     sudo pacman -Sy --noconfirm ;;
        debian)   sudo apt-get update -qq ;;
        fedora)   sudo dnf check-update -q || true ;;
        gentoo)   sudo emerge --sync --quiet ;;
        opensuse) sudo zypper --non-interactive refresh ;;
    esac
}

# ── Package lists ─────────────────────────────────────────────────────────────

arch_packages() {
    local pkgs=(
        base-devel git rsync curl unzip
        swaybg swayidle xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        waybar rofi-wayland swaync wlogout
        kitty firefox nautilus geany fish fastfetch btop
        wl-clipboard cliphist grim slurp swappy
        xorg-xwayland autotiling
        gnome-power-manager
        starship eza bat ugrep zoxide find-the-command
        wofi python-pywal copyq waypaper
        pipewire wireplumber pipewire-pulse pavucontrol pavucontrol-qt pamixer playerctl
        brightnessctl ddcutil jq
        pacman-contrib flatpak libnotify
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

debian_packages() {
    echo \
        build-essential git rsync curl unzip \
        swaybg swayidle xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        waybar rofi sway-notification-center swaylock \
        kitty firefox nautilus geany fish btop \
        wl-clipboard grim slurp swappy xwayland copyq \
        pipewire wireplumber pipewire-pulse pavucontrol pamixer playerctl \
        brightnessctl jq flatpak libnotify-bin \
        network-manager network-manager-gnome blueman \
        policykit-1-gnome qt5ct qt6ct yad \
        python3 python3-gi imagemagick \
        fonts-noto fonts-noto-color-emoji fonts-firacode \
        papirus-icon-theme sddm gnome-keyring libsecret-1-0 virt-manager \
        starship eza bat zoxide
}

fedora_packages() {
    echo \
        git rsync curl unzip \
        swaybg swayidle \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        waybar rofi swaync wlogout \
        kitty firefox nautilus geany fish fastfetch btop \
        wl-clipboard grim slurp swappy xwayland swaylock \
        copyq ddcutil ugrep \
        pipewire wireplumber pipewire-pulse pavucontrol pamixer playerctl \
        brightnessctl jq flatpak libnotify \
        NetworkManager NetworkManager-applet blueman polkit-gnome \
        qt5ct qt6ct kvantum-manager \
        qt6-qtsvg qt6-qtvirtualkeyboard qt6-qtmultimedia \
        yad python3 python3-gobject ImageMagick \
        google-noto-fonts-common google-noto-emoji-fonts fira-code-fonts \
        papirus-icon-theme \
        sddm gnome-keyring libsecret \
        virt-manager \
        eza bat zoxide
}

declare -A FEDORA_COPR_REPOS
FEDORA_COPR_REPOS=(
    ["swayfx/swayfx"]="swayfx"
    ["solopasha/hyprland"]="waypaper cliphist swaylock-effects"
    ["tofik/nwg-shell"]="nwg-look nwg-displays"
    ["tofik/sway-tools"]="autotiling"
)

enable_fedora_copr_repos() {
    log "Ensuring dnf-plugins-core is installed (needed for copr)..."
    sudo dnf install -y dnf-plugins-core || warn "dnf-plugins-core install failed"

    for repo in "${!FEDORA_COPR_REPOS[@]}"; do
        # Check if repo is already enabled
        local repo_id="copr:copr.fedorainfracloud.org:${repo//\//:}"
        if dnf repolist --enabled 2>/dev/null | grep -q "$repo_id"; then
            log "COPR $repo already enabled — skipping"
            continue
        fi
        log "Enabling COPR: $repo"
        sudo dnf copr enable -y "$repo" \
            || warn "Failed to enable COPR: $repo"
    done
}

install_fedora_copr_packages() {
    for repo in "${!FEDORA_COPR_REPOS[@]}"; do
        local pkgs="${FEDORA_COPR_REPOS[$repo]}"
        for pkg in $pkgs; do
            if rpm -q "$pkg" >/dev/null 2>&1; then
                log "COPR pkg already installed: $pkg"
                continue
            fi
            log "Installing COPR package: $pkg (from $repo)"
            sudo dnf install -y "$pkg" || warn "Failed to install COPR pkg: $pkg"
        done
    done
}

gentoo_packages() {
    echo \
        dev-vcs/git net-misc/rsync net-misc/curl app-arch/unzip \
        gui-apps/swaybg gui-apps/swayidle \
        xdg-base/xdg-desktop-portal xdg-base/xdg-desktop-portal-wlr xdg-base/xdg-desktop-portal-gtk \
        gui-apps/waybar gui-apps/rofi-wayland gui-apps/grim gui-apps/slurp \
        x11-base/xwayland \
        x11-terms/kitty gui-apps/swaylock \
        www-client/firefox app-editors/geany app-shells/fish sys-process/btop \
        gui-apps/wl-clipboard gui-apps/swappy gui-apps/copyq \
        media-sound/pipewire media-sound/wireplumber media-sound/pavucontrol \
        media-sound/pamixer media-sound/playerctl \
        sys-power/brightnessctl app-misc/jq \
        sys-apps/flatpak x11-libs/libnotify \
        net-misc/networkmanager gnome-extra/nm-applet net-wireless/blueman \
        sys-auth/polkit-gnome \
        x11-misc/qt5ct x11-misc/yad \
        dev-lang/python dev-python/pygobject \
        media-gfx/imagemagick \
        media-fonts/noto media-fonts/noto-emoji media-fonts/jetbrains-mono \
        x11-themes/papirus-icon-theme \
        x11-misc/sddm \
        gnome-base/gnome-keyring app-crypt/libsecret \
        app-emulation/virt-manager
}

# openSUSE package names — tested on Tumbleweed; most work on Leap too.
opensuse_packages() {
    echo \
        git rsync curl unzip \
        swaybg swayidle xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        waybar rofi swaylock \
        kitty MozillaFirefox nautilus geany fish fastfetch btop \
        wl-clipboard grim slurp xwayland copyq \
        pipewire wireplumber pipewire-pulse pavucontrol pamixer playerctl \
        brightnessctl jq flatpak libnotify-tools \
        NetworkManager NetworkManager-applet blueman polkit-gnome \
        qt5ct qt6ct yad python3 python3-gobject ImageMagick \
        noto-fonts noto-coloremoji-fonts \
        papirus-icon-theme sddm \
        gnome-keyring libsecret-1-0 \
        virt-manager
}

# ── Per-distro install functions ──────────────────────────────────────────────
install_pacman_packages() {
    log "Installing packages (arch)..."
    # shellcheck disable=SC2046
    pkg_install $(arch_packages)
}

install_debian_packages() {
    log "Installing packages (debian/ubuntu)..."
    # shellcheck disable=SC2046
    pkg_install $(debian_packages)

    if ! command -v starship >/dev/null 2>&1; then
        log "Installing starship via official installer..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes || warn "starship install failed"
    fi
    if ! command -v zoxide >/dev/null 2>&1; then
        log "Installing zoxide via official installer..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash \
            || warn "zoxide install failed"
    fi
}

install_fedora_packages() {
    log "Installing packages (fedora)..."

    # ── RPM Fusion (Steam, Discord, multimedia codecs) ────────────────────────
    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        log "Enabling RPM Fusion (free + nonfree)..."
        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
            || warn "RPM Fusion install failed"
    fi

    # ── COPR repos ────────────────────────────────────────────────────────────
    enable_fedora_copr_repos

    # ── Official packages ─────────────────────────────────────────────────────
    # shellcheck disable=SC2046
    pkg_install $(fedora_packages)

    # ── COPR packages (swayfx, waypaper, cliphist, swaylock-effects) ─────────
    install_fedora_copr_packages

    # ── Steam & Discord via RPM Fusion ────────────────────────────────────────
    pkg_install steam discord || warn "Steam/Discord install failed — check RPM Fusion"

    # ── starship (not in Fedora repos, use official installer) ──────────────
    if ! command -v starship >/dev/null 2>&1; then
        log "Installing starship via official installer..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes || warn "starship install failed"
    fi

    # ── python-pywal (not packaged for Fedora, use pip) ───────────────────────
    if ! python3 -c "import pywal" 2>/dev/null; then
        log "Installing pywal via pip3..."
        pip3 install --user pywal || warn "pywal pip install failed"
    fi

    # ── networkmanager-dmenu (not in repos, use pip) ──────────────────────────
    if ! command -v networkmanager-dmenu >/dev/null 2>&1; then
        log "Installing networkmanager-dmenu via pip3..."
        pip3 install --user networkmanager-dmenu || warn "networkmanager-dmenu pip install failed"
    fi

    # ── zoxide (may not be in older Fedora releases, fallback to installer) ───
    if ! command -v zoxide >/dev/null 2>&1; then
        log "Installing zoxide via official installer..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash             || warn "zoxide install failed"
    fi
}

install_gentoo_packages() {
    log "Installing packages (gentoo)..."

    # GURU overlay for community packages (autotiling, nwg-*, waypaper)
    if ! eselect repository list 2>/dev/null | grep -q guru; then
        log "Enabling GURU overlay..."
        if ! command -v eselect >/dev/null 2>&1 || ! eselect repository list &>/dev/null; then
            sudo emerge --ask=n app-eselect/eselect-repository || warn "eselect-repository install failed"
        fi
        sudo eselect repository enable guru || warn "Could not enable GURU — some packages may be missing"
        sudo emerge --sync --quiet
    fi

    # shellcheck disable=SC2046
    pkg_install $(gentoo_packages)

    # GURU-only extras
    for pkg in gui-apps/autotiling gui-apps/waypaper gui-apps/nwg-look gui-apps/nwg-displays; do
        sudo emerge --ask=n --noreplace "$pkg" \
            || warn "GURU package not found: $pkg (try: emerge --sync && re-run)"
    done

    if ! command -v starship >/dev/null 2>&1; then
        log "Installing starship via official installer..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes || warn "starship install failed"
    fi
    if ! command -v zoxide >/dev/null 2>&1; then
        log "Installing zoxide via official installer..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash \
            || warn "zoxide install failed"
    fi
}

install_opensuse_packages() {
    log "Installing packages (opensuse)..."

    # Packman — needed for Steam, Discord, and multimedia codecs
    if ! zypper repos 2>/dev/null | grep -qi packman; then
        log "Adding Packman repository..."
        if grep -qi tumbleweed /etc/os-release; then
            sudo zypper --non-interactive addrepo --refresh \
                https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
        else
            local ver; ver="$(. /etc/os-release && echo "$VERSION_ID")"
            sudo zypper --non-interactive addrepo --refresh \
                "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${ver}/" packman || true
        fi
        sudo zypper --non-interactive --gpg-auto-import-keys refresh || true
    fi

    # shellcheck disable=SC2046
    pkg_install $(opensuse_packages)
    pkg_install steam discord || warn "Steam/Discord may need Packman — check repo config"

    if ! command -v starship >/dev/null 2>&1; then
        curl -sS https://starship.rs/install.sh | sh -s -- --yes || warn "starship install failed"
    fi
    if ! command -v zoxide >/dev/null 2>&1; then
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash \
            || warn "zoxide install failed"
    fi
}

install_packages_for_distro() {
    case "$DISTRO" in
        arch)     install_pacman_packages ;;
        debian)   install_debian_packages ;;
        fedora)   install_fedora_packages ;;
        gentoo)   install_gentoo_packages ;;
        opensuse) install_opensuse_packages ;;
    esac
}

# ── AUR (Arch only) ───────────────────────────────────────────────────────────
ensure_aur_helper() {
    command -v yay  >/dev/null 2>&1 && { echo "yay";  return; }
    command -v paru >/dev/null 2>&1 && { echo "paru"; return; }

    log "Installing yay (AUR helper)..."
    local build_user="${SUDO_USER:-$USER}"
    if [[ "$EUID" -eq 0 && -z "$SUDO_USER" ]]; then
        echo "ERROR: Run as a regular user (not root)." >&2; exit 1
    fi

    local tmpdir; tmpdir="$(mktemp -d)"
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
    local pkgs=(
        swayfx swaylock-effects
        catppuccin-cursors-mocha catppuccin-gtk-theme-mocha
        github-desktop-bin telegram-desktop
    )
    log "Installing AUR packages with ${aur_helper}..."
    for pkg in "${pkgs[@]}"; do
        pacman -Qi "$pkg" >/dev/null 2>&1 && continue
        "$aur_helper" -S --needed --noconfirm "$pkg" || warn "Failed AUR: $pkg"
    done
}

# ── SDDM ──────────────────────────────────────────────────────────────────────
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

# ── Dotfiles ──────────────────────────────────────────────────────────────────
deploy_dotfiles() {
    log "Deploying dotfiles..."
    mkdir -p "$BACKUP_DIR" "$HOME/.config"

    if [[ -d "$REPO_DIR/.config" ]]; then
        for item in "$REPO_DIR"/.config/*; do
            [[ -e "$item" ]] || continue
            local base; base="$(basename "$item")"
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
        local tmpdir; tmpdir="$(mktemp -d)"
        git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$tmpdir/nerd-fonts" || warn "Failed to clone Nerd Fonts repo"
        if [[ -f "$tmpdir/nerd-fonts/install.sh" ]]; then
            chmod +x "$tmpdir/nerd-fonts/install.sh"
            # Install JetBrainsMono and FiraCode as examples, or all if uncommented
            "$tmpdir/nerd-fonts/install.sh" || warn "Failed to install Nerd Fonts"
        fi
        rm -rf "$tmpdir"
        log "Nerd Fonts installation completed. Updating font cache again..."
        sudo fc-cache -f || warn "Failed to update font cache after Nerd Fonts"
    fi

    deploy_sddm_theme
    setup_sddm_wallpaper_permissions

    if [[ -d "$HOME/.config/sway/scripts" ]]; then
        find "$HOME/.config/sway/scripts" -type f -name "*.sh" -exec chmod +x {} +
    fi

    log "Dotfiles installed. Backup saved to: $BACKUP_DIR"
}

# ── Services ──────────────────────────────────────────────────────────────────
enable_services() {
    log "Enabling system services..."

    svc_enable() {
        sudo systemctl enable --now "$1" || warn "Failed to enable: $1"
    }

    svc_enable NetworkManager
    svc_enable bluetooth

    # Disable other display managers to avoid conflicts
    log "Disabling conflicting display managers..."
    for dm in lightdm gdm gdm3; do
        if systemctl is-enabled "$dm" 2>/dev/null; then
            sudo systemctl disable "$dm" || warn "Failed to disable $dm"
        fi
    done

    svc_enable sddm

}

# ── Verification ──────────────────────────────────────────────────────────────
verify_packages() {
    log "Verifying installed packages..."

    local failed=()
    local all_pkgs=()

    case "$DISTRO" in
        arch)
            all_pkgs=($(arch_packages))
            if [[ "$NO_AUR" -eq 0 ]]; then
                all_pkgs+=(swayfx swaylock-effects catppuccin-cursors-mocha catppuccin-gtk-theme-mocha github-desktop-bin telegram-desktop)
            fi
            for pkg in "${all_pkgs[@]}"; do
                if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
                    failed+=("$pkg")
                fi
            done
            ;;
        debian)
            all_pkgs=($(debian_packages))
            for pkg in "${all_pkgs[@]}"; do
                if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                    failed+=("$pkg")
                fi
            done
            # Check additional tools
            for tool in starship zoxide; do
                if ! command -v "$tool" >/dev/null 2>&1; then
                    failed+=("$tool")
                fi
            done
            ;;
        fedora)
            all_pkgs=($(fedora_packages))
            # Add COPR packages
            for repo in "${!FEDORA_COPR_REPOS[@]}"; do
                all_pkgs+=(${FEDORA_COPR_REPOS[$repo]})
            done
            all_pkgs+=(steam discord)
            for pkg in "${all_pkgs[@]}"; do
                if ! rpm -q "$pkg" >/dev/null 2>&1; then
                    failed+=("$pkg")
                fi
            done
            # Check additional tools
            for tool in starship zoxide; do
                if ! command -v "$tool" >/dev/null 2>&1; then
                    failed+=("$tool")
                fi
            done
            # Check pip installs
            if ! python3 -c "import pywal" 2>/dev/null; then
                failed+=(pywal)
            fi
            if ! command -v networkmanager-dmenu >/dev/null 2>&1; then
                failed+=(networkmanager-dmenu)
            fi
            ;;
        gentoo)
            all_pkgs=($(gentoo_packages))
            all_pkgs+=(gui-apps/autotiling gui-apps/waypaper gui-apps/nwg-look gui-apps/nwg-displays)
            for pkg in "${all_pkgs[@]}"; do
                if ! equery list "$pkg" >/dev/null 2>&1; then
                    failed+=("$pkg")
                fi
            done
            # Check additional tools
            for tool in starship zoxide; do
                if ! command -v "$tool" >/dev/null 2>&1; then
                    failed+=("$tool")
                fi
            done
            ;;
        opensuse)
            all_pkgs=($(opensuse_packages))
            all_pkgs+=(steam discord)
            for pkg in "${all_pkgs[@]}"; do
                if ! rpm -q "$pkg" >/dev/null 2>&1; then
                    failed+=("$pkg")
                fi
            done
            # Check additional tools
            for tool in starship zoxide; do
                if ! command -v "$tool" >/dev/null 2>&1; then
                    failed+=("$tool")
                fi
            done
            ;;
    esac

    if [[ ${#failed[@]} -eq 0 ]]; then
        log "All packages verified successfully."
    else
        warn "The following packages failed verification: ${failed[*]}"
    fi
}

# ── Post-install checks ───────────────────────────────────────────────────────
post_install_checks() {
    log "Running post-install checks..."

    local issues=()

    # Check services
    if [[ "$SKIP_SERVICES" -eq 0 ]]; then
        for svc in NetworkManager bluetooth sddm; do
            if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
                issues+=("Service $svc is not active")
            fi
        done
    fi

    # Check dotfiles
    if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
        [[ -d "$HOME/.config/sway" ]] || issues+=("Sway config not found")
        [[ -d "$HOME/.config/waybar" ]] || issues+=("Waybar config not found")
        [[ -d "$HOME/.wallpapers" ]] || issues+=("Wallpapers not found")
        [[ -d "/usr/share/fontconfig/conf.avail" ]] || issues+=("fontconfig conf.avail not found")
        [[ -d "/usr/share/sddm/themes/blair" ]] || issues+=("SDDM theme not installed")
        [[ -f "/etc/sddm.conf" ]] || issues+=("SDDM config not found")
        [[ -d "/var/cache/wallpaper" ]] || issues+=("Wallpaper cache dir not created")
    fi

    # Check key commands
    for cmd in sway swaylock waybar kitty firefox; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            issues+=("Command $cmd not found")
        fi
    done

    # Check font cache
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
        install_packages_for_distro

        if [[ "$DISTRO" == "arch" ]]; then
            if [[ "$NO_AUR" -eq 0 ]]; then
                local aur_helper; aur_helper="$(ensure_aur_helper)"
                install_aur_packages "$aur_helper"
            else
                warn "Skipping AUR (--no-aur). Fallback: sway + swaylock installed via pacman."
            fi
        else
            [[ "$NO_AUR" -eq 1 ]] && warn "--no-aur has no effect on $DISTRO (AUR is Arch-only)."
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

    if [[ "$DISTRO" == "gentoo" ]]; then
        echo ""
        echo "Gentoo notes:"
        echo "  - Review USE flags in /etc/portage/package.use before re-running."
        echo "  - If GURU packages failed, run 'sudo emerge --sync' and retry."
        echo "  - This script assumes a systemd profile. OpenRC users may need manual service setup."
    fi
    if [[ "$DISTRO" == "opensuse" ]]; then
        echo ""
        echo "openSUSE notes:"
        echo "  - If Steam/Discord failed, verify Packman repo is active: 'zypper repos'"
        echo "  - On Leap, some packages may be newer on Tumbleweed only."
    fi
}

main "$@"
