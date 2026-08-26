#!/usr/bin/env bash
# =============================================================================
# DotsFiles Installation & Setup Script (Arch Linux / Sway)
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

DISTRO=""
SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0
NO_AUR=0
DRY_RUN=0

# Colors
RESET="\e[0m"
BOLD="\e[1m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
MAGENTA="\e[35m"

log()  { printf "\n${CYAN}[INFO]${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}[OK]${RESET}   %s\n" "$*"; }
warn() { printf "\n${YELLOW}[WARN]${RESET} %s\n" "$*" >&2; }
err()  { printf "\n${RED}[ERR]${RESET}  %s\n" "$*" >&2; }

usage() {
    cat <<EOF
${BOLD}DotsFiles Automated Installer${RESET}

Usage: $0 [options]

Options:
  --skip-packages   Skip pacman package installation
  --skip-dotfiles   Skip deploying ~/.config, wallpapers, and SDDM theme
  --skip-services   Skip enabling system services (NetworkManager, bluetooth, SDDM)
  --no-aur          Skip AUR packages (use standard sway/swaylock)
  --dry-run         Simulate installation without making system changes
  -h, --help        Show this help message and exit
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
            --dry-run)       DRY_RUN=1; shift ;;
            -h|--help)       usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "$DISTRO" ]]; then
        if [[ -f /etc/arch-release ]]; then
            DISTRO="arch"
        else
            err "Unsupported system. DotsFiles is optimized for Arch Linux."
            exit 1
        fi
    fi
}

ensure_sudo() {
    if [[ "$DRY_RUN" -eq 1 ]]; then return 0; fi
    sudo -v
}

pkg_install() {
    local to_install=()
    for pkg in "$@"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log "Installing ${#to_install[@]} official package(s)..."
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would install: ${to_install[*]}"
        else
            sudo pacman -S --needed --noconfirm "${to_install[@]}" || warn "Some packages failed to install."
        fi
    fi
}

enable_multilib_repo() {
    local conf="/etc/pacman.conf"
    [[ -f "$conf" ]] || return 0

    if grep -Eq '^[[:space:]]*\[multilib\]' "$conf"; then
        return 0
    fi

    log "Enabling pacman [multilib] repository..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would enable [multilib] in $conf"
        return 0
    fi

    sudo cp -n "$conf" "$conf.dotfiles-bak" 2>/dev/null || true
    if grep -Eq '^[[:space:]]*#[[:space:]]*\[multilib\]' "$conf"; then
        sudo sed -i '/^[[:space:]]*#[[:space:]]*\[multilib\]/,+1 s/^[[:space:]]*#[[:space:]]*//' "$conf"
    else
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a "$conf" >/dev/null
    fi
    sudo pacman -Sy --noconfirm
}

arch_packages() {
    local pkgs=(
        # Core & Build
        base-devel git rsync curl unzip jq inotify-tools socat cmake ccache
        # Wayland Compositor & Shell
        swaybg swayidle swaylock xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        waybar layer-shell-qt xorg-xwayland autotiling
        # Modern CLI & Shell
        fish starship eza bat fzf zoxide fastfetch btop trash-cli
        # Terminal Emulators
        kitty foot
        # GUI Applications
        firefox thunar
        # Clipboard & Screenshots
        wl-clipboard grim slurp swappy
        # Audio & Media
        pipewire wireplumber pipewire-pulse pamixer playerctl libcanberra
        # System & Hardware
        upower brightnessctl ddcutil pacman-contrib libnotify
        # Network & Bluetooth
        networkmanager
        # Display Manager (SDDM) & Qt6 Components
        sddm qt6-5compat qt6-declarative qt6-wayland qt6-svg qt6-multimedia qt6-virtualkeyboard
        # Theming & Fonts
        qt5ct qt6ct kvantum nwg-look
        noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-jetbrains-mono-nerd ttf-fira-sans
        papirus-icon-theme adw-gtk-theme
        # Utilities & Tools
        imagemagick sqlite
    )

    [[ "$NO_AUR" -eq 1 ]] && pkgs+=(sway)
    echo "${pkgs[@]}"
}

aur_packages() {
    local pkgs=(
        swayfx
        swaylock-effects
        waypaper
        catppuccin-cursors-mocha
        catppuccin-gtk-theme-mocha
    )
    echo "${pkgs[@]}"
}

ensure_aur_helper() {
    command -v yay  >/dev/null 2>&1 && { echo "yay";  return; }
    command -v paru >/dev/null 2>&1 && { echo "paru"; return; }

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "yay"
        return
    fi

    log "Installing yay (AUR helper)..."
    local build_user="${SUDO_USER:-$USER}"
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

    command -v yay >/dev/null 2>&1 || { warn "yay build failed."; exit 1; }
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
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would install AUR: $pkg"
        else
            "$aur_helper" -S --needed --noconfirm "$pkg" || warn "Failed AUR: $pkg"
        fi
    done
}

deploy_sddm_theme() {
    local sddm_src="$REPO_DIR/usr/share/sddm/themes/b1air"
    local sddm_dst="/usr/share/sddm/themes/b1air"
    local wallpaper_group="wallpaper"
    local installer_user="${SUDO_USER:-$USER}"
    local cache_dir="/var/cache/wallpaper"
    local cache_wall="$cache_dir/current.jpg"

    if [[ -d "$sddm_src" ]]; then
        log "Deploying b1air SDDM theme to $sddm_dst..."
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would install $sddm_src -> $sddm_dst"
        else
            sudo install -d -m 755 "$sddm_dst"
            sudo rsync -a --delete "$sddm_src/" "$sddm_dst/"
        fi
    fi

    if [[ -f "$REPO_DIR/etc/sddm.conf" ]]; then
        log "Installing /etc/sddm.conf..."
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would install $REPO_DIR/etc/sddm.conf -> /etc/sddm.conf"
        else
            sudo install -Dm644 "$REPO_DIR/etc/sddm.conf" "/etc/sddm.conf"
        fi
    fi

    # Shared wallpaper cache for SDDM background
    log "Configuring shared SDDM wallpaper cache in $cache_dir..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would setup wallpaper group and permissions for $cache_dir"
    else
        sudo groupadd -f "$wallpaper_group"
        sudo install -d -o root -g "$wallpaper_group" -m 2775 "$cache_dir"
        id "$installer_user" >/dev/null 2>&1 && sudo usermod -aG "$wallpaper_group" "$installer_user" || true
        id sddm >/dev/null 2>&1 && sudo usermod -aG "$wallpaper_group" sddm || true

        local seed_wall=""
        if [[ -d "$REPO_DIR/.wallpapers" ]]; then
            seed_wall="$(find "$REPO_DIR/.wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' \) | head -n 1 || true)"
        fi
        if [[ -n "$seed_wall" && -f "$seed_wall" ]]; then
            sudo install -o root -g "$wallpaper_group" -m 664 "$seed_wall" "$cache_wall"
        fi
    fi
}

deploy_session_files() {
    log "Deploying b1air FreeDesktop Wayland session files & portals..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would install b1air.desktop, b1air-session, and b1air-portals.conf"
        return 0
    fi

    # 1. Wayland session entry for SDDM/GDM
    if [[ -f "$REPO_DIR/usr/share/wayland-sessions/b1air.desktop" ]]; then
        sudo install -d -m 755 /usr/share/wayland-sessions
        sudo install -m 644 "$REPO_DIR/usr/share/wayland-sessions/b1air.desktop" /usr/share/wayland-sessions/b1air.desktop
        ok "Installed /usr/share/wayland-sessions/b1air.desktop"
    fi

    # 2. b1air-session binary
    if [[ -f "$REPO_DIR/usr/bin/b1air-session" ]]; then
        sudo install -d -m 755 /usr/bin
        sudo install -m 755 "$REPO_DIR/usr/bin/b1air-session" /usr/bin/b1air-session
        ok "Installed /usr/bin/b1air-session"
    fi

    # 3. XDG Desktop Portals config
    if [[ -f "$REPO_DIR/usr/share/xdg-desktop-portal/b1air-portals.conf" ]]; then
        sudo install -d -m 755 /usr/share/xdg-desktop-portal
        sudo install -m 644 "$REPO_DIR/usr/share/xdg-desktop-portal/b1air-portals.conf" /usr/share/xdg-desktop-portal/b1air-portals.conf
        ok "Installed /usr/share/xdg-desktop-portal/b1air-portals.conf"
    fi
}

deploy_dotfiles() {
    log "Deploying user dotfiles..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would deploy .config and .wallpapers to $HOME"
        deploy_sddm_theme
        deploy_session_files
        return 0
    fi

    mkdir -p "$BACKUP_DIR" "$HOME/.config"

    # Backup and sync .config
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

    # Sync wallpapers
    if [[ -d "$REPO_DIR/.wallpapers" ]]; then
        [[ -e "$HOME/.wallpapers" || -L "$HOME/.wallpapers" ]] \
            && mv "$HOME/.wallpapers" "$BACKUP_DIR/.wallpapers"
        rsync -a --delete "$REPO_DIR/.wallpapers/" "$HOME/.wallpapers/"
    fi

    # Build and install b1air-daemon C++ suite
    build_b1air_daemon

    # Deploy Wayland session files & portals
    deploy_session_files

    # Refresh user font cache
    fc-cache -f >/dev/null 2>&1 || true

    ok "Dotfiles deployed. Previous configs backed up in: $BACKUP_DIR"
}

detect_and_install_vm_guest_tools() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt
        virt="$(systemd-detect-virt 2>/dev/null || true)"
        if [[ -n "$virt" && "$virt" != "none" ]]; then
            log "Detected Virtual Machine environment: $virt"
            case "$virt" in
                kvm|qemu|bochs)
                    pkg_install qemu-guest-agent spice-vdagent
                    if [[ "$DRY_RUN" -eq 0 ]]; then
                        sudo systemctl enable --now qemu-guest-agent 2>/dev/null || true
                    fi
                    ;;
                oracle)
                    pkg_install virtualbox-guest-utils
                    if [[ "$DRY_RUN" -eq 0 ]]; then
                        sudo systemctl enable --now vboxservice 2>/dev/null || true
                    fi
                    ;;
                vmware)
        virt="$(systemd-detect-virt || true)"
        if [[ "$virt" == "oracle" || "$virt" == "kvm" || "$virt" == "qemu" || "$virt" == "vmware" ]]; then
            log "Virtual Machine detected ($virt). Installing guest integration..."
            pkg_install mesa
        fi
    fi
}

enable_services() {
    log "Enabling system services..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would enable: NetworkManager, bluetooth, sddm"
        return 0
    fi

    sudo systemctl enable NetworkManager || warn "Failed to enable NetworkManager"
    sudo systemctl enable bluetooth || warn "Failed to enable Bluetooth"
    sudo systemctl enable sddm || warn "Failed to enable SDDM"
}

build_b1air_suite() {
    log "Building and installing b1air-daemon & b1air-shell (Native C++20 Desktop Suite)..."
    if [[ -d "$REPO_DIR/src" ]]; then
        # 1. Daemon
        make -C "$REPO_DIR/src" clean >/dev/null 2>&1 || true
        make -C "$REPO_DIR/src" PREFIX="${HOME}/.local/bin" install || warn "Failed to build b1air-daemon"
        if sudo install -m 755 "$REPO_DIR/src/b1air-daemon" /usr/local/bin/b1air-daemon 2>/dev/null; then
            ok "b1air-daemon installed to /usr/local/bin/b1air-daemon"
        else
            ok "b1air-daemon installed to ~/.local/bin/b1air-daemon"
        fi

        # 2. Native b1air-shell
        if [[ -d "$REPO_DIR/src/shell" ]]; then
            cmake -B "$REPO_DIR/src/shell/build" "$REPO_DIR/src/shell" >/dev/null 2>&1 || true
            cmake --build "$REPO_DIR/src/shell/build" -j"$(nproc 2>/dev/null || echo 4)" || warn "Failed to build b1air-shell"
            if sudo install -m 755 "$REPO_DIR/src/shell/build/b1air-shell" /usr/local/bin/b1air-shell 2>/dev/null; then
                ok "b1air-shell installed to /usr/local/bin/b1air-shell"
            elif [[ -f "$REPO_DIR/src/shell/build/b1air-shell" ]]; then
                install -m 755 "$REPO_DIR/src/shell/build/b1air-shell" "${HOME}/.local/bin/b1air-shell"
                ok "b1air-shell installed to ~/.local/bin/b1air-shell"
            fi
        fi
    fi
}

post_install_checks() {
    log "Running environment verification..."
    local commands=(sway swaylock kitty fish starship eza bat fzf sddm b1air-daemon b1air-shell)
    local missing=()

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1 && ! [[ -x "$HOME/.local/bin/$cmd" ]]; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "All essential commands verified."
    else
        warn "Missing commands: ${missing[*]}"
    fi
}

main() {
    parse_args "$@"
    log "Operating as distro: ${DISTRO}"
    ensure_sudo

    if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
        enable_multilib_repo
        pkg_install $(arch_packages)

        if [[ "$NO_AUR" -eq 0 ]]; then
            local aur_helper
            aur_helper="$(ensure_aur_helper)"
            install_aur_packages "$aur_helper"
        else
            warn "Skipping AUR packages (--no-aur)."
        fi

        detect_and_install_vm_guest_tools
    else
        warn "Skipping packages installation (--skip-packages)."
    fi

    if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
        deploy_dotfiles
        build_b1air_daemon
    else
        warn "Skipping dotfiles deployment."
    fi
    [[ "$SKIP_SERVICES" -eq 0 ]] && enable_services || warn "Skipping services configuration."

    post_install_checks

    printf "\n${GREEN}${BOLD}✓ Installation finished successfully!${RESET}\n"
    echo "Log in to Sway session to enjoy your environment."
}

main "$@"
