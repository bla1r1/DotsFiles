#!/usr/bin/env bash
# install-void.sh — Void Linux installer for the sway dotfiles setup
# Requires: xbps, runit (default on Void), run as regular user with sudo access
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

log()  { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --skip-packages  Skip package installation
  --skip-dotfiles  Skip deploying dotfiles, fonts, wallpapers, and SDDM config
  --skip-services  Skip enabling system services
  --musl           Use musl packages where applicable (suffix check only, XBPS handles it)
  -h, --help       Show this help and exit

Requirements:
  - Void Linux (glibc or musl)
  - Regular user with sudo
  - xbps-install available
EOF
}

# ── Arg parsing ────────────────────────────────────────────────────────────────
SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-packages) SKIP_PACKAGES=1; shift ;;
            --skip-dotfiles) SKIP_DOTFILES=1; shift ;;
            --skip-services) SKIP_SERVICES=1; shift ;;
            --musl) shift ;;   # no-op: musl is auto on musl Void
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done
}

ensure_sudo() { sudo -v; }

# ── Sanity check ───────────────────────────────────────────────────────────────
check_void() {
    if [[ ! -f /etc/void-release ]]; then
        echo "ERROR: This script is for Void Linux only." >&2
        exit 1
    fi
    log "Detected Void Linux — OK"
}

# ── Package sync ───────────────────────────────────────────────────────────────
sync_repos() {
    log "Syncing xbps repositories..."
    sudo xbps-install -S
}

# ── Package install ────────────────────────────────────────────────────────────
pkg_install() {
    local missing=()
    for pkg in "$@"; do
        xbps-query -i "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    sudo xbps-install -y "${missing[@]}" || warn "Some packages failed: ${missing[*]}"
}

# ── Package list ───────────────────────────────────────────────────────────────
void_packages() {
    # Notes on naming differences vs Arch:
    #   base-devel          → base-devel (same)
    #   rofi-wayland        → rofi-wayland  (if not in repos, use rofi)
    #   swaync              → SwayNotificationCenter
    #   quickshell          → NOT in void repos, skip (build from source if needed)
    #   autotiling          → autotiling (python3 package, available via pip or void repos)
    #   gnome-power-manager → NOT in void repos (use xfce4-power-manager as alternative)
    #   nwg-look            → nwg-look
    #   nwg-displays        → nwg-displays
    #   ugrep               → ugrep
    #   find-the-command    → NOT in void repos (fish plugin)
    #   wofi                → wofi
    #   waypaper            → waypaper (may need pip or manual build)
    #   copyq               → CopyQ
    #   wlogout             → wlogout
    #   ddcutil             → ddcutil
    #   eza                 → eza
    #   bat                 → bat
    #   zoxide              → zoxide
    #   starship            → starship
    #   fastfetch           → fastfetch
    #   pavucontrol-qt      → pavucontrol-qt
    #   kvantum             → kvantum (Qt theme)
    #   qt6-virtualkeyboard → qt6-virtualkeyboard (available)
    #   yad                 → yad
    #   python-gobject      → python3-gobject
    #   papirus-icon-theme  → papirus-icon-theme
    #   gnome-keyring       → gnome-keyring
    #   libsecret           → libsecret
    #   virt-manager        → virt-manager
    #   trash-cli           → trash-cli
    #   cliphist            → cliphist
    #   swappy              → swappy
    #   slurp               → slurp
    #   grim                → grim
    #   pamixer             → pamixer
    #   playerctl           → playerctl
    #   socat               → socat
    #   inotify-tools       → inotify-tools
    #   brightnessctl       → brightnessctl
    #   network-manager-applet → network-manager-applet
    #   blueman             → blueman
    #   polkit-gnome        → polkit-gnome
    #   steam               → steam (void nonfree repo needed)
    #   discord             → discord (void nonfree repo needed)
    #   telegram-desktop    → telegram-desktop
    #   sddm                → sddm
    echo \
        base-devel git rsync curl unzip \
        \
        swaybg swayidle sway \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        \
        waybar rofi-wayland wlogout \
        SwayNotificationCenter \
        \
        kitty firefox nautilus Thunar geany fish fastfetch btop \
        \
        wl-clipboard cliphist grim slurp swappy CopyQ wofi \
        xorg-server-xwayland \
        autotiling \
        \
        starship eza bat ugrep zoxide \
        \
        python3-pywal waypaper \
        \
        pipewire wireplumber alsa-pipewire pipewire-pulse \
        pavucontrol pavucontrol-qt pamixer playerctl \
        \
        brightnessctl ddcutil jq inotify-tools socat \
        \
        flatpak libnotify trash-cli \
        \
        NetworkManager network-manager-applet blueman \
        polkit-gnome \
        \
        qt5ct qt6ct kvantum \
        qt6-svg qt6-virtualkeyboard \
        yad nwg-look nwg-displays \
        \
        python3 python3-gobject ImageMagick \
        \
        noto-fonts-ttf noto-fonts-emoji \
        font-jetbrains-mono-nerd \
        \
        papirus-icon-theme sddm \
        \
        gnome-keyring libsecret \
        \
        virt-manager \
        \
        telegram-desktop
}

# ── Nonfree repo (Steam, Discord) ──────────────────────────────────────────────
enable_nonfree_repo() {
    if ! xbps-query -i void-repo-nonfree >/dev/null 2>&1; then
        log "Enabling void-repo-nonfree (needed for Steam, Discord)..."
        sudo xbps-install -y void-repo-nonfree || warn "Failed to enable nonfree repo"
        sudo xbps-install -S || true
    fi
}

install_nonfree_packages() {
    log "Installing nonfree packages (Steam, Discord)..."
    pkg_install steam discord || warn "Steam/Discord failed — verify nonfree repo"
}

# ── swaylock-effects (not in void repos — build from source) ──────────────────
install_swaylock_effects() {
    if command -v swaylock-effects >/dev/null 2>&1; then
        log "swaylock-effects already installed — skipping"
        return
    fi
    log "Building swaylock-effects from source..."
    local deps=(meson ninja wayland-devel wayland-protocols pam-devel cairo-devel \
                 gdk-pixbuf-devel libxkbcommon-devel scdoc)
    pkg_install "${deps[@]}"

    local tmpdir; tmpdir="$(mktemp -d)"
    git clone https://github.com/mortie/swaylock-effects.git "$tmpdir/swaylock-effects"
    (
        cd "$tmpdir/swaylock-effects"
        meson setup build --prefix=/usr
        ninja -C build
        sudo ninja -C build install
    )
    rm -rf "$tmpdir"
    log "swaylock-effects installed."
}

# ── swayfx (not in void repos — build from source) ────────────────────────────
install_swayfx() {
    if command -v swayfx >/dev/null 2>&1; then
        log "swayfx already installed — skipping"
        return
    fi
    log "Building swayfx from source..."
    local deps=(meson ninja wlroots-devel wayland-devel wayland-protocols \
                 libxkbcommon-devel pcre2-devel json-c-devel libevdev-devel \
                 libinput-devel cairo-devel pango-devel gdk-pixbuf-devel \
                 xcb-util-wm-devel xcb-util-image-devel xcb-util-keysyms-devel \
                 scdoc seatd-devel)
    pkg_install "${deps[@]}"

    local tmpdir; tmpdir="$(mktemp -d)"
    git clone https://github.com/WillPower3309/swayfx.git "$tmpdir/swayfx"
    (
        cd "$tmpdir/swayfx"
        meson setup build --prefix=/usr -Dman-pages=enabled
        ninja -C build
        sudo ninja -C build install
    )
    rm -rf "$tmpdir"
    log "swayfx installed."
}

# ── catppuccin cursors/gtk (AUR equiv — install from GitHub releases) ─────────
install_catppuccin_themes() {
    # Cursors
    if [[ ! -d /usr/share/icons/catppuccin-mocha-dark-cursors ]]; then
        log "Installing catppuccin mocha cursors..."
        local tmpdir; tmpdir="$(mktemp -d)"
        curl -sL "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-dark-cursors.zip" \
            -o "$tmpdir/cursors.zip" || warn "Failed to download catppuccin cursors"
        if [[ -f "$tmpdir/cursors.zip" ]]; then
            unzip -q "$tmpdir/cursors.zip" -d "$tmpdir/"
            sudo mv "$tmpdir/catppuccin-mocha-dark-cursors" /usr/share/icons/ || warn "Cursor install failed"
        fi
        rm -rf "$tmpdir"
    else
        log "Catppuccin cursors already installed."
    fi

    # GTK theme
    if [[ ! -d /usr/share/themes/catppuccin-mocha-standard-blue-Normal ]]; then
        log "Installing catppuccin mocha GTK theme..."
        local tmpdir; tmpdir="$(mktemp -d)"
        curl -sL "https://github.com/catppuccin/gtk/releases/latest/download/catppuccin-mocha-standard-blue-Normal.zip" \
            -o "$tmpdir/gtk.zip" || warn "Failed to download catppuccin GTK theme"
        if [[ -f "$tmpdir/gtk.zip" ]]; then
            unzip -q "$tmpdir/gtk.zip" -d "$tmpdir/"
            sudo mv "$tmpdir/catppuccin-mocha-standard-blue-Normal" /usr/share/themes/ || warn "GTK theme install failed"
        fi
        rm -rf "$tmpdir"
    else
        log "Catppuccin GTK theme already installed."
    fi
}

# ── Main package install ───────────────────────────────────────────────────────
install_packages() {
    log "Installing packages (Void Linux)..."
    # shellcheck disable=SC2046
    pkg_install $(void_packages)

    enable_nonfree_repo
    install_nonfree_packages

    install_swaylock_effects
    install_swayfx
    install_catppuccin_themes

    # github-desktop: no void package, skip with note
    warn "github-desktop: not available for Void Linux. Use web UI or install manually."

    # quickshell: not in repos, skip with note
    warn "quickshell: not in Void repos. Build from source if needed: https://git.outfoxxed.me/outfoxxed/quickshell"

    # swww: not confirmed in current official repos
    warn "swww: not confirmed in current Void repos. Install manually if your workflow needs it."

    # find-the-command: fish-specific, not a package
    warn "find-the-command: install as a fish plugin manually if needed."
}

# ── Pipewire / audio setup ─────────────────────────────────────────────────────
setup_pipewire() {
    log "Setting up PipeWire..."
    # On Void, PipeWire needs user-level runit services
    local svc_src="/usr/share/pipewire"
    local user_svc="$HOME/.config/service"
    mkdir -p "$user_svc"

    for svc in pipewire pipewire-pulse; do
        if [[ -d "$svc_src/$svc" ]]; then
            [[ -L "$user_svc/$svc" ]] || ln -sf "$svc_src/$svc" "$user_svc/$svc"
            log "Linked user service: $svc"
        fi
    done
    # wireplumber user service
    if [[ -d /usr/share/wireplumber ]]; then
        [[ -L "$user_svc/wireplumber" ]] \
            || ln -sf /usr/share/wireplumber/wireplumber.service "$user_svc/wireplumber" 2>/dev/null \
            || warn "wireplumber user service not found — check /usr/share/wireplumber"
    fi
    log "PipeWire user services linked. Start with: sv up ~/.config/service/pipewire"
}

# ── Services (runit) ──────────────────────────────────────────────────────────
enable_services() {
    log "Enabling system services (runit)..."

    svc_enable() {
        local svc="$1"
        if [[ -d /etc/sv/$svc ]]; then
            [[ -L /var/service/$svc ]] \
                || sudo ln -sf "/etc/sv/$svc" "/var/service/$svc" \
                && log "Enabled: $svc"
        else
            warn "Service not found in /etc/sv/: $svc"
        fi
    }

    svc_enable NetworkManager
    svc_enable bluetoothd
    svc_enable dbus           # required by many services
    svc_enable polkitd
    svc_enable sddm

    # Disable other DMs if they somehow got linked
    for dm in lightdm gdm; do
        if [[ -L /var/service/$dm ]]; then
            sudo rm /var/service/$dm && log "Disabled: $dm"
        fi
    done

    setup_pipewire

    log "Services enabled. Note: sddm starts on next boot or: sudo sv up /var/service/sddm"
}

# ── SDDM theme ────────────────────────────────────────────────────────────────
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

# ── Wallpaper cache ────────────────────────────────────────────────────────────
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
        warn "No wallpaper found to seed $cache_wall"
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
    if command -v git >/dev/null 2>&1; then
        local tmpdir; tmpdir="$(mktemp -d)"
        git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$tmpdir/nerd-fonts" \
            || warn "Failed to clone Nerd Fonts repo"
        if [[ -f "$tmpdir/nerd-fonts/install.sh" ]]; then
            chmod +x "$tmpdir/nerd-fonts/install.sh"
            "$tmpdir/nerd-fonts/install.sh" || warn "Nerd Fonts install failed"
        fi
        rm -rf "$tmpdir"
        sudo fc-cache -f || warn "fc-cache failed"
    else
        warn "git not found — skipping Nerd Fonts"
    fi

    deploy_sddm_theme
    setup_sddm_wallpaper_permissions

    if [[ -d "$HOME/.config/sway/scripts" ]]; then
        find "$HOME/.config/sway/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
    fi

    log "Dotfiles deployed. Backup saved to: $BACKUP_DIR"
}

# ── Verification ───────────────────────────────────────────────────────────────
verify_packages() {
    log "Verifying installed packages..."
    local failed=()

    # xbps packages
    for pkg in $(void_packages); do
        xbps-query -i "$pkg" >/dev/null 2>&1 || failed+=("$pkg")
    done

    # nonfree
    for pkg in steam discord; do
        xbps-query -i "$pkg" >/dev/null 2>&1 || failed+=("$pkg")
    done

    # binaries built from source
    command -v swayfx       >/dev/null 2>&1 || failed+=("swayfx (from source)")
    command -v swaylock-effects >/dev/null 2>&1 || failed+=("swaylock-effects (from source)")

    # catppuccin themes
    [[ -d /usr/share/icons/catppuccin-mocha-dark-cursors ]] \
        || failed+=("catppuccin-cursors (manual)")
    [[ -d /usr/share/themes/catppuccin-mocha-standard-blue-Normal ]] \
        || failed+=("catppuccin-gtk-theme (manual)")

    # commands that should exist
    for cmd in starship zoxide eza bat ugrep; do
        command -v "$cmd" >/dev/null 2>&1 || failed+=("$cmd (command)")
    done

    # pywal
    python3 -c "import pywal" 2>/dev/null || failed+=("python3-pywal")

    if [[ ${#failed[@]} -eq 0 ]]; then
        log "All packages verified successfully."
    else
        warn "Failed verification: ${failed[*]}"
    fi
}

# ── Post-install checks ────────────────────────────────────────────────────────
post_install_checks() {
    log "Running post-install checks..."
    local issues=()

    # Services via runit
    if [[ "$SKIP_SERVICES" -eq 0 ]]; then
        for svc in NetworkManager bluetoothd sddm; do
            [[ -L /var/service/$svc ]] || issues+=("runit service not linked: $svc")
        done
    fi

    # Dotfiles
    if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
        [[ -d "$HOME/.config/sway" ]]       || issues+=("Sway config not found")
        [[ -d "$HOME/.wallpapers" ]]         || issues+=("Wallpapers not found")
        [[ -d "/usr/share/sddm/themes/blair" ]] || issues+=("SDDM theme not installed")
        [[ -f "/etc/sddm.conf" ]]            || issues+=("SDDM config not found")
        [[ -d "/var/cache/wallpaper" ]]      || issues+=("Wallpaper cache dir not created")
    fi

    # Key commands
    for cmd in sway kitty firefox; do
        command -v "$cmd" >/dev/null 2>&1 || issues+=("Command not found: $cmd")
    done

    if ! command -v swaylock-effects >/dev/null 2>&1 && ! command -v swaylock >/dev/null 2>&1; then
        issues+=("Command not found: swaylock or swaylock-effects")
    fi

    # Fonts
    fc-list | grep -q "JetBrains" || issues+=("JetBrains fonts not loaded (run: fc-cache -f)")

    if [[ ${#issues[@]} -eq 0 ]]; then
        log "All post-install checks passed."
    else
        warn "Post-install issues:"
        for issue in "${issues[@]}"; do
            warn "  - $issue"
        done
    fi
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    check_void
    ensure_sudo
    sync_repos

    if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
        install_packages
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
    echo ""
    echo "Void Linux notes:"
    echo "  - PipeWire user services are in ~/.config/service/ — start them manually or via your session"
    echo "  - swayfx and swaylock-effects were built from source"
    echo "  - quickshell and github-desktop are NOT available for Void — install manually if needed"
    echo "  - Log out/in or reboot after installation"
    echo "  - Group membership changes (wallpaper) require a new login session"
}

main "$@"
