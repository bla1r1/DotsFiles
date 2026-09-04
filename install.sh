#!/usr/bin/env bash
# =============================================================================
# DotsFiles Installation & Setup Script (Arch Linux / Sway)
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# The daemon's dotfiles_sync/status/sys look for the repo by guessing among a
# few hardcoded paths, so a clone anywhere else silently made those features
# "repo not found" forever. Record the real path once, here, where the
# installer already knows it — no more guessing needed downstream.
REPO_PATH_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/b1air/dotfiles-repo"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

DISTRO=""
SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0
NO_AUR=0
DRY_RUN=0
RESTART=0

# Colors
RESET="\e[0m"
BOLD="\e[1m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
MAGENTA="\e[35m"

# ponytail: all chatter goes to stderr so $(...) captures only real return values
log()  { printf "\n${CYAN}[INFO]${RESET} %s\n" "$*" >&2; }
ok()   { printf "${GREEN}[OK]${RESET}   %s\n" "$*" >&2; }
warn() { printf "\n${YELLOW}[WARN]${RESET} %s\n" "$*" >&2; }
err()  { printf "\n${RED}[ERR]${RESET}  %s\n" "$*" >&2; }

# ponytail: flat list of finished step names; deleted on a fully successful run
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-install.state"

init_state() {
    if [[ "$RESTART" -eq 1 ]]; then
        rm -f "$STATE_FILE"
    elif [[ -s "$STATE_FILE" ]]; then
        log "Resuming: $(grep -c . "$STATE_FILE") step(s) already done. Use --restart to redo everything."
    fi
    mkdir -p "$(dirname "$STATE_FILE")"
}

# step <name> <command...> — runs the command unless it already succeeded before
step() {
    local name="$1"; shift
    if [[ -f "$STATE_FILE" ]] && grep -qxF "$name" "$STATE_FILE"; then
        ok "Skipping '${name}' (done in a previous run)."
        return 0
    fi
    [[ "$DRY_RUN" -eq 1 ]] && { log "Would run step: $name"; return 0; }
    "$@"
    printf '%s\n' "$name" >> "$STATE_FILE"
}

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
  --restart         Ignore saved progress and run every step from scratch
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
            --restart)       RESTART=1; shift ;;
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
            # ponytail: a swallowed failure here means a "successful" install with nothing installed
            sudo pacman -Sy --needed --noconfirm "${to_install[@]}" || {
                err "Package installation failed — fix the error above and re-run (progress is saved)."
                exit 1; }
        fi
    fi
}

enable_multilib_repo() {
    # ponytail: 32-bit repo, needed later for steam/wine; it only exists on x86_64
    [[ "$(uname -m)" == "x86_64" ]] || { log "Skipping [multilib]: not available on $(uname -m)."; return 0; }

    local conf="/etc/pacman.conf"
    [[ -f "$conf" ]] || return 0
    grep -Eq '^[[:space:]]*\[multilib\]' "$conf" && return 0

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
    # ponytail: no -Sy here; the packages step syncs databases anyway
}

arch_packages() {
    local pkgs=(
        # Core & Build
        base-devel git rsync curl unzip jq cmake ccache openssl polkit nlohmann-json
        # Wayland Compositor & Shell
        swaybg swayidle swaylock xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xorg-xwayland
        layer-shell-qt wayvnc
        # Every QML file imports Quickshell; without it b1air-shell starts and dies.
        quickshell
        # Modern CLI & Shell
        fish starship eza bat fzf zoxide fastfetch btop
        # Native b1air-term uses libvterm for terminal emulation.
        libvterm
        # GUI Applications
        # b1air-files and b1air-view replace the old Thunar/Imv entries.
        # Keep Firefox: there is no bundled browser replacement.
        firefox
        # Clipboard & Screenshots
        wl-clipboard grim slurp satty
        # Audio & Media
        pipewire wireplumber pipewire-pulse playerctl libcanberra sound-theme-freedesktop ffmpeg gifsicle noise-suppression-for-voice
        # System & Hardware
        upower brightnessctl ddcutil pacman-contrib libnotify
        # glxinfo: the session auto-tunes compositor effects off on a software
        # rasterizer, and without this the check silently never fires.
        mesa-utils
        # Network & Bluetooth
        networkmanager bluez bluez-utils
        # Display Manager (SDDM) & Qt6 Components
        sddm qt6-declarative qt6-wayland qt6-svg qt6-virtualkeyboard
        # Theming & Fonts
        kvantum
        noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-jetbrains-mono-nerd ttf-fira-sans
        ttf-liberation
        papirus-icon-theme
        # Utilities & Tools
        imagemagick sqlite tesseract tesseract-data-eng zbar qrencode
        # Tools the shell shells out to. Without these the button exists, the
        # command does not, and the action fails for no visible reason.
        power-profiles-daemon pamixer poppler gocryptfs easyeffects
        wlsunset snapper
        # Storage & archives: removable media, phones, NTFS volumes, 7z.
        udisks2 gvfs ntfs-3g 7zip
        # Desktop plumbing every DE ships: XDG user directories, Qt platform
        # theming (this repo already ships qt5ct/qt6ct configs), printing.
        xdg-user-dirs qt5ct qt6ct cups
        # Input method — the CJK fonts below are useless without a way to type.
        fcitx5 fcitx5-qt fcitx5-gtk fcitx5-configtool
    )

    [[ "$NO_AUR" -eq 1 ]] && pkgs+=(sway)
    echo "${pkgs[@]}"
}

# Display-controller vendors present on the PCI bus, read straight from sysfs:
# lspci would mean depending on pciutils, which is the same trap that left the
# software-rendering check silently disabled.
gpu_vendors() {
    local vendors=() dev class vendor
    for dev in /sys/bus/pci/devices/*; do
        [[ -r "$dev/class" && -r "$dev/vendor" ]] || continue
        class="$(< "$dev/class")"
        [[ "$class" == 0x03* ]] || continue     # 0x03xxxx = display controller
        vendor="$(< "$dev/vendor")"
        case "$vendor" in
            0x10de) vendors+=(nvidia) ;;
            0x1002) vendors+=(amd) ;;
            0x8086) vendors+=(intel) ;;
        esac
    done
    [[ ${#vendors[@]} -gt 0 ]] && printf '%s\n' "${vendors[@]}" | sort -u
    return 0
}

# The nvidia package is built against a specific kernel; the wrong variant
# leaves the module unbuilt and the session without a driver.
nvidia_package_for_kernel() {
    case "$(uname -r)" in
        *-lts)  echo "nvidia-lts" ;;
        *-arch*) echo "nvidia" ;;
        *)      echo "nvidia-dkms" ;;
    esac
}

install_gpu_drivers() {
    local virt
    virt="$(systemd-detect-virt 2>/dev/null || echo none)"
    if [[ "$virt" != "none" ]]; then
        log "Virtual machine ($virt) — skipping GPU drivers; mesa already covers it."
        return 0
    fi

    local vendors pkgs=()
    vendors="$(gpu_vendors)"
    if [[ -z "$vendors" ]]; then
        warn "No PCI display controller recognised; leaving graphics drivers alone."
        return 0
    fi

    local vendor nv
    while read -r vendor; do
        [[ -n "$vendor" ]] || continue
        case "$vendor" in
            nvidia)
                nv="$(nvidia_package_for_kernel)"
                log "NVIDIA GPU detected — installing ${nv} for kernel $(uname -r)."
                pkgs+=("$nv" nvidia-utils) ;;
            amd)
                log "AMD GPU detected — installing Vulkan and VA-API userspace."
                pkgs+=(vulkan-radeon libva-mesa-driver) ;;
            intel)
                log "Intel GPU detected — installing Vulkan and VA-API userspace."
                pkgs+=(vulkan-intel intel-media-driver) ;;
        esac
    done <<< "$vendors"

    pkg_install "${pkgs[@]}"
}

aur_packages() {
    local pkgs=(
        swayfx
        # Screen recording: the daemon calls wl-screenrec; AUR-only.
        wl-screenrec
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

    local build_user="${SUDO_USER:-$USER}"
    if [[ "$build_user" == "root" ]]; then
        err "makepkg refuses to run as root. Run the installer as a normal user, or pass --no-aur."
        exit 1
    fi

    log "Installing yay (AUR helper)..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    chown "$build_user" "$tmpdir"
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" >&2
    chown -R "$build_user" "$tmpdir/yay"

    if [[ "$EUID" -eq 0 ]]; then
        sudo -u "$build_user" bash -c "cd '$tmpdir/yay' && makepkg -si --noconfirm" >&2
    else
        (cd "$tmpdir/yay" && makepkg -si --noconfirm) >&2
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
            # ponytail: no fallback to upstream sway — a different compositor is not a fix
            "$aur_helper" -S --needed --noconfirm "$pkg" || {
                err "Failed to install AUR package '$pkg'. Fix the error above and re-run."
                exit 1; }
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

    # 4. udev rules (e.g. bluetoothd doesn't reliably notice its adapter
    # coming back after an rfkill unblock without a nudge)
    if [[ -d "$REPO_DIR/etc/udev/rules.d" ]]; then
        sudo install -d -m 755 /etc/udev/rules.d
        for rule in "$REPO_DIR"/etc/udev/rules.d/*.rules; do
            [[ -f "$rule" ]] || continue
            sudo install -m 644 "$rule" "/etc/udev/rules.d/$(basename "$rule")"
            ok "Installed /etc/udev/rules.d/$(basename "$rule")"
        done
        sudo udevadm control --reload-rules 2>/dev/null || true
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
    build_b1air_suite

    # deploy_sddm_theme was only ever called from the DRY_RUN branch above —
    # a real install never called it at all, so /usr/share/sddm/themes/b1air
    # and /etc/sddm.conf were never deployed on any machine that actually ran
    # this script for real. The dry-run preview lied about what would happen.
    deploy_sddm_theme

    # Deploy Wayland session files & portals
    deploy_session_files

    # Refresh user font cache
    fc-cache -f >/dev/null 2>&1 || true

    ok "Dotfiles deployed. Previous configs backed up in: $BACKUP_DIR"
}

configure_default_shell() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would set the login shell to /usr/bin/fish"
        return 0
    fi
    if [[ ! -x /usr/bin/fish ]]; then
        warn "Fish is not installed; keeping the current login shell."
        return 0
    fi
    if ! grep -Fxq /usr/bin/fish /etc/shells 2>/dev/null; then
        warn "/usr/bin/fish is not listed in /etc/shells; keeping the current login shell."
        return 0
    fi
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" != "/usr/bin/fish" ]]; then
        chsh -s /usr/bin/fish "$USER" || sudo usermod -s /usr/bin/fish "$USER" || warn "Could not set Fish as the login shell."
    fi
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
                    pkg_install open-vm-tools
                    if [[ "$DRY_RUN" -eq 0 ]]; then
                        sudo systemctl enable --now vmtoolsd 2>/dev/null || true
                    fi
                    ;;
            esac
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
    # Installed above, but inert until enabled: the shell's power-profile
    # switch talks to this daemon, and printing needs the cups socket.
    sudo systemctl enable power-profiles-daemon || warn "Failed to enable power-profiles-daemon"
    sudo systemctl enable cups.socket || warn "Failed to enable CUPS"
    # ponytail: SDDM last and strict — enabling it early boots the user into a broken session
    sudo systemctl enable sddm || { err "Failed to enable SDDM."; exit 1; }
}

build_b1air_suite() {
    log "Building and installing b1air-daemon & b1air-shell (Native C++20 Desktop Suite)..."
    if [[ -d "$REPO_DIR/src" ]]; then
        if command -v ccache >/dev/null 2>&1; then
            ccache -M 10G >/dev/null 2>&1 || true
        fi

        # 1. Daemon
        make -C "$REPO_DIR/src" clean >/dev/null 2>&1 || true
        make -C "$REPO_DIR/src" PREFIX="${HOME}/.local/bin" install || {
            err "Failed to build b1air-daemon — see the compiler output above."; exit 1; }
        if sudo install -m 755 "$REPO_DIR/src/b1air-daemon" /usr/local/bin/b1air-daemon 2>/dev/null; then
            ok "b1air-daemon installed to /usr/local/bin/b1air-daemon"
        else
            ok "b1air-daemon installed to ~/.local/bin/b1air-daemon"
        fi

        # 2. Native b1air-shell
        if [[ -d "$REPO_DIR/src/shell" ]]; then
            # ponytail: never silence configure — a missing Qt6 module dies here, not later
            cmake -B "$REPO_DIR/src/shell/build" "$REPO_DIR/src/shell" || {
                err "cmake configure failed — a build dependency is missing."; exit 1; }
            cmake --build "$REPO_DIR/src/shell/build" -j"$(nproc 2>/dev/null || echo 4)" || {
                err "Failed to build b1air-shell — see the compiler output above."; exit 1; }
            # The QML plugin has to sit on Qt's import path for quickshell to
            # find it; ~/.local is not on that path, so this one needs root.
            local qml_dest
            qml_dest="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || echo /usr/lib/qt6/qml)"
            if [[ -d "$REPO_DIR/src/shell/build/qml/B1air" ]]; then
                sudo cp -r "$REPO_DIR/src/shell/build/qml/B1air" "$qml_dest/" \
                    && ok "B1air.Daemon QML module installed to $qml_dest" \
                    || { err "Failed to install the B1air.Daemon QML module."; exit 1; }
            fi

            if sudo install -m 755 "$REPO_DIR/src/shell/build/b1air-shell" /usr/local/bin/b1air-shell 2>/dev/null; then
                ok "b1air-shell installed to /usr/local/bin/b1air-shell"
            elif [[ -f "$REPO_DIR/src/shell/build/b1air-shell" ]]; then
                install -m 755 "$REPO_DIR/src/shell/build/b1air-shell" "${HOME}/.local/bin/b1air-shell"
                ok "b1air-shell installed to ~/.local/bin/b1air-shell"
            fi
        fi
    fi
}

configure_remote_desktop_permissions() {
    log "Configuring uinput & screencast permissions for prompt-free remote desktop..."
    echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-uinput.rules >/dev/null 2>&1 || true
    sudo udevadm control --reload-rules >/dev/null 2>&1 || true
    sudo udevadm trigger --name-match=uinput >/dev/null 2>&1 || true
    sudo usermod -aG input "$USER" >/dev/null 2>&1 || true
}

post_install_checks() {
    log "Running environment verification..."
    # ponytail: every app must be present — this gate is what keeps SDDM off a broken system
    local commands=(sway swaylock fish starship eza bat fzf sddm
        b1air-daemon b1air-polkit-agent b1air-secret-service b1air-shell
        b1air-files b1air-settings b1air-monitor b1air-term b1air-text
        b1air-view b1air-notes b1air-git)
    local missing=()

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1 && ! [[ -x "$HOME/.local/bin/$cmd" ]]; then
            missing+=("$cmd")
        fi
    done

    # ponytail: an existing binary proves nothing if its QML module is absent
    [[ -d /usr/lib/qt6/qml/Quickshell ]] || missing+=("Quickshell QML module")

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "All essential commands verified."
    else
        err "Missing commands: ${missing[*]}"
        exit 1
    fi
}

aur_step() {
    local aur_helper
    aur_helper="$(ensure_aur_helper)"
    install_aur_packages "$aur_helper"
}

# xdg-user-dirs is in the package list, but the package alone does nothing:
# it ships its own XDG-autostart entry that would run xdg-user-dirs-update on
# first login, and sway (unlike GNOME/KDE/XFCE) never runs XDG autostart
# entries at all — nothing in this repo's autostart.conf does either. Every
# other DE creates ~/Downloads, ~/Documents etc. on first login; here that
# needs a direct, one-time call instead of a login hook that can never fire.
create_user_dirs() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would run xdg-user-dirs-update to create ~/Downloads, ~/Documents, etc."
        return 0
    fi
    command -v xdg-user-dirs-update >/dev/null 2>&1 || return 0
    xdg-user-dirs-update
}

record_repo_path() {
    [[ -d "$REPO_DIR/.git" ]] || return 0
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would record dotfiles repo path: $REPO_DIR"
        return 0
    fi
    mkdir -p "$(dirname "$REPO_PATH_FILE")"
    printf '%s\n' "$REPO_DIR" > "$REPO_PATH_FILE"
}

main() {
    parse_args "$@"
    log "Operating as distro: ${DISTRO}"
    ensure_sudo
    init_state
    record_repo_path

    if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
        step multilib   enable_multilib_repo
        step packages   pkg_install $(arch_packages)
        step gpu        install_gpu_drivers
        if [[ "$NO_AUR" -eq 0 ]]; then
            step aur    aur_step
        else
            warn "Skipping AUR packages (--no-aur)."
        fi
        step vm-tools   detect_and_install_vm_guest_tools
    else
        warn "Skipping packages installation (--skip-packages)."
    fi

    if [[ "$SKIP_DOTFILES" -eq 0 ]]; then
        # After deploy_dotfiles, not before: its rsync --delete on ~/.config
        # would otherwise wipe user-dirs.dirs right back out, since it is not
        # part of this repo's tracked .config tree.
        step dotfiles   deploy_dotfiles
        step user-dirs  create_user_dirs
        step suite      build_b1air_suite
        step remote-perms configure_remote_desktop_permissions
    else
        warn "Skipping dotfiles deployment."
    fi
    step default-shell  configure_default_shell

    # ponytail: verify BEFORE enabling the display manager — a graphical login on a
    # half-installed system locks the user out of the desktop they cannot yet run
    post_install_checks

    if [[ "$SKIP_SERVICES" -eq 0 ]]; then
        step services   enable_services
    else
        warn "Skipping services configuration."
    fi

    rm -f "$STATE_FILE"

    printf "\n${GREEN}${BOLD}✓ Installation finished successfully!${RESET}\n"
    echo "Log in to Sway session to enjoy your environment."
}

main "$@"
