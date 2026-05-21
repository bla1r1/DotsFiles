#!/usr/bin/env bash
# install-ui.sh — interactive TUI installer (JaKooLit-style)
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$REPO_DIR/install.sh"
LOG="$HOME/.dotfiles-install-$(date +%Y%m%d-%H%M%S).log"

# ── Colours ───────────────────────────────────────────────────────────────────
RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
OK="${GREEN}[OK]${RESET}"
INFO="${CYAN}[INFO]${RESET}"
WARN="${YELLOW}[WARN]${RESET}"
ERR="${RED}[ERROR]${RESET}"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo -e "${INFO} $*" | tee -a "$LOG"; }
warn() { echo -e "${WARN} $*" | tee -a "$LOG"; }
ok()   { echo -e "${OK}   $*" | tee -a "$LOG"; }
err()  { echo -e "${ERR}  $*" | tee -a "$LOG"; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    err "install.sh not found at: $INSTALL_SCRIPT"
    exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}Do NOT run this script as root or with sudo.${RESET}"
    exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${WARN} whiptail not found — installing..."
    case "$(detect_distro)" in
        arch)     sudo pacman -S --needed --noconfirm libnewt ;;
        debian)   sudo apt-get install -y whiptail ;;
        fedora)   sudo dnf install -y newt ;;
        opensuse) sudo zypper --non-interactive install whiptail ;;
        gentoo)   sudo emerge --ask=n dev-libs/newt ;;
    esac
fi

mkdir -p "$(dirname "$LOG")"
echo "Install log: $LOG" | tee "$LOG"

# ── Distro detection ──────────────────────────────────────────────────────────
detect_distro() {
    if   [[ -f /etc/arch-release ]];   then echo "arch"
    elif [[ -f /etc/debian_version ]]; then echo "debian"
    elif [[ -f /etc/fedora-release ]]; then echo "fedora"
    elif [[ -f /etc/gentoo-release ]]; then echo "gentoo"
    elif [[ -f /etc/SuSE-release ]] || grep -qi opensuse /etc/os-release 2>/dev/null; then
        echo "opensuse"
    else echo "unknown"
    fi
}

DISTRO=""
# Accept --distro flag passed from bootstrap.sh
while [[ $# -gt 0 ]]; do
    case "$1" in
        --distro)   DISTRO="$2"; shift 2 ;;
        --distro=*) DISTRO="${1#--distro=}"; shift ;;
        *)          shift ;;
    esac
done
[[ -z "$DISTRO" ]] && DISTRO="$(detect_distro)"

if [[ "$DISTRO" == "unknown" ]]; then
    whiptail --title "Error" --msgbox \
        "Could not detect your distro.\nSupported: arch, debian, fedora, gentoo, opensuse." \
        10 60
    exit 1
fi

log "Detected distro: ${BOLD}$DISTRO${RESET}"

# ── GPU detection ─────────────────────────────────────────────────────────────
HAS_NVIDIA=false
if command -v lspci >/dev/null 2>&1 && lspci | grep -qi nvidia; then
    HAS_NVIDIA=true
fi

if $HAS_NVIDIA; then
    whiptail --title "NVIDIA GPU Detected" --msgbox \
"An NVIDIA GPU was detected in your system.

If you select the NVIDIA option below, proprietary drivers will be
installed (exact package depends on your distro).

For RTX 5000+ GPUs: install open drivers MANUALLY before running this
script — do NOT rely on the automatic option." \
        14 72
fi

# ── Welcome banner ────────────────────────────────────────────────────────────
whiptail --title "DotsFiles Installer" --msgbox \
"Welcome to the DotsFiles interactive installer!

Distro detected : $DISTRO
Log file        : $LOG

NOTES:
• SPACEBAR to toggle options, TAB to switch buttons
• Packages / services that fail will be warned, not fatal
• A timestamped backup of existing configs will be created
• If installing on a VM, enable 3D acceleration for Wayland

Press OK to continue." \
    20 72

# ── Check input group ─────────────────────────────────────────────────────────
if ! groups "$USER" | grep -q '\binput\b'; then
    whiptail --title "Input Group" --msgbox \
"You are not in the 'input' group.

Adding you now is recommended for Waybar keyboard-state and
libinput to work correctly. The installer will add you automatically.

You will need to log out and back in after installation." \
        12 65
fi

# ── Main selection loop ───────────────────────────────────────────────────────
# We loop so the user can go back and adjust choices if confirm fails.

SKIP_PACKAGES=0
SKIP_DOTFILES=0
SKIP_SERVICES=0
NO_AUR=0
INSTALL_NVIDIA=0

while true; do
    # Build checklist items — AUR row only shown on Arch
    CHECKLIST_ARGS=(
        "packages"  "Install base packages"                                        ON
        "dotfiles"  "Deploy .config, wallpapers, fonts, and SDDM theme/config"    ON
        "services"  "Enable system services (NetworkManager, bluetooth, SDDM)"    ON
    )

    [[ "$DISTRO" == "arch" ]] && \
        CHECKLIST_ARGS+=("aur" "Install AUR packages (swayfx, catppuccin, themes…)" ON)

    $HAS_NVIDIA && \
        CHECKLIST_ARGS+=("nvidia" "Install NVIDIA proprietary drivers" OFF)

    CHOICES=$(whiptail --title "Select Installation Steps" \
        --checklist \
        "Choose what to install or configure.\n\nNOTE: SPACEBAR to toggle  |  TAB to switch buttons" \
        22 80 10 \
        "${CHECKLIST_ARGS[@]}" \
        3>&1 1>&2 2>&3) || {
            echo -e "❌ ${INFO} You cancelled the selection. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
            exit 0
        }

    # Require at least one selection
    if [[ -z "$CHOICES" ]]; then
        whiptail --title "Warning" --msgbox \
            "No options were selected.\nPlease select at least one option." \
            8 55
        continue
    fi

    # Parse choices
    SKIP_PACKAGES=1; SKIP_DOTFILES=1; SKIP_SERVICES=1; NO_AUR=1; INSTALL_NVIDIA=0
    [[ "$CHOICES" == *"packages"* ]] && SKIP_PACKAGES=0
    [[ "$CHOICES" == *"dotfiles"* ]] && SKIP_DOTFILES=0
    [[ "$CHOICES" == *"services"* ]] && SKIP_SERVICES=0
    [[ "$CHOICES" == *"aur"*      ]] && NO_AUR=0
    [[ "$CHOICES" == *"nvidia"*   ]] && INSTALL_NVIDIA=1

    # Warn if dotfiles chosen without packages
    if [[ "$SKIP_DOTFILES" -eq 0 && "$SKIP_PACKAGES" -eq 1 ]]; then
        if ! whiptail --title "Warning" --yesno \
"You selected dotfiles but NOT packages.

Some dotfile scripts depend on installed packages to function
correctly. Continue anyway?" \
            10 62; then
            continue
        fi
    fi

    # No-dots warning (matching JaKooLit style)
    if [[ "$SKIP_DOTFILES" -eq 1 ]]; then
        if ! whiptail --title "No Dotfiles Selected" --yesno \
"You have NOT selected dotfiles.

Without dotfiles, Sway/Hyprland will start with a bare default
configuration and some features may not work out of the box.

Would you like to continue without dotfiles, or return to options?" \
            --yes-button "Continue" --no-button "Return" \
            13 72; then
            continue
        fi
    fi

    # ── Build confirm message ─────────────────────────────────────────────────
    confirm_msg="Your selected installation steps:\n\n"
    [[ "$SKIP_PACKAGES"  -eq 0 ]] && confirm_msg+="  ✔ Install packages\n"      || confirm_msg+="  ✘ Skip packages\n"
    [[ "$SKIP_DOTFILES"  -eq 0 ]] && confirm_msg+="  ✔ Deploy dotfiles\n"       || confirm_msg+="  ✘ Skip dotfiles\n"
    [[ "$SKIP_SERVICES"  -eq 0 ]] && confirm_msg+="  ✔ Enable services\n"       || confirm_msg+="  ✘ Skip services\n"
    if [[ "$DISTRO" == "arch" ]]; then
        [[ "$NO_AUR" -eq 0 ]] && confirm_msg+="  ✔ Install AUR packages\n" || confirm_msg+="  ✘ Skip AUR\n"
    fi
    $HAS_NVIDIA && {
        [[ "$INSTALL_NVIDIA" -eq 1 ]] && confirm_msg+="  ✔ Install NVIDIA drivers\n" || confirm_msg+="  ✘ Skip NVIDIA\n"
    }
    confirm_msg+="\nDistro : $DISTRO\nLog    : $LOG\n\nProceed?"

    if ! whiptail --title "Confirm Your Choices" \
        --yesno "$(printf "%s" "$confirm_msg")" \
        22 72; then
        echo -e "❌ ${CYAN}Returning to options...${RESET}" | tee -a "$LOG"
        continue
    fi

    break  # User confirmed — exit loop
done

echo -e "👌 ${OK} ${MAGENTA}Confirmed.${RESET} ${CYAN}Starting installation...${RESET}" | tee -a "$LOG"

# ── Input group ───────────────────────────────────────────────────────────────
if ! groups "$USER" | grep -q '\binput\b'; then
    log "Adding $USER to input group..."
    sudo usermod -aG input "$USER" && ok "Added to input group." \
        || warn "Failed to add to input group — do it manually: sudo usermod -aG input $USER"
fi

# ── Build argument list for install.sh ───────────────────────────────────────
ARGS=(--distro "$DISTRO")
[[ "$SKIP_PACKAGES" -eq 1 ]] && ARGS+=(--skip-packages)
[[ "$SKIP_DOTFILES" -eq 1 ]] && ARGS+=(--skip-dotfiles)
[[ "$SKIP_SERVICES" -eq 1 ]] && ARGS+=(--skip-services)
[[ "$NO_AUR"        -eq 1 ]] && ARGS+=(--no-aur)
[[ "$INSTALL_NVIDIA" -eq 1 ]] && ARGS+=(--nvidia)

log "Running: bash $INSTALL_SCRIPT ${ARGS[*]}"
echo ""

# ── NVIDIA handling ───────────────────────────────────────────────────────────
# install.sh handles --nvidia per-distro; we just pass the flag.
# But if SDDM selection conflicts we warn here.
if [[ "$INSTALL_NVIDIA" -eq 1 ]] && [[ "$SKIP_SERVICES" -eq 0 ]]; then
    # Check for conflicting active display managers
    active_dm=()
    for dm in gdm lightdm xdm lxdm; do
        systemctl is-active --quiet "$dm" 2>/dev/null && active_dm+=("$dm")
    done
    if [[ ${#active_dm[@]} -gt 0 ]]; then
        active_list="$(printf '  • %s\n' "${active_dm[@]}")"
        whiptail --title "Active Display Manager Detected" --msgbox \
"The following login manager(s) are active:

$active_list

If you want SDDM to be enabled, stop and disable the above
services and reboot before re-running this script.

The service-enable step will still run but SDDM may not start." \
            16 70
    fi
fi

# ── Run installer ─────────────────────────────────────────────────────────────
bash "$INSTALL_SCRIPT" "${ARGS[@]}" 2>&1 | tee -a "$LOG"
exit_code="${PIPESTATUS[0]}"

echo "" | tee -a "$LOG"
if [[ "$exit_code" -eq 0 ]]; then
    whiptail --title "Installation Complete" --msgbox \
"✅  Installation finished successfully!

Log saved to: $LOG

Next steps:
  • Log out and back in (or reboot) to apply group changes
  • A backup of your old config was saved to ~/.dotfiles-backup-*
  • On first Sway/Hyprland launch press SUPER+H for a hints menu
  • Check the README for post-install tips

Goodbye and enjoy your setup! 🎉" \
        18 66
else
    whiptail --title "Installation Finished with Errors" --msgbox \
"⚠️  Installation completed with some errors (exit code: $exit_code).

Warnings are usually non-fatal — check the log for details:
  $LOG

You can re-run individual steps with flags, e.g.:
  bash install.sh --distro $DISTRO --skip-packages

Feel free to open an issue if something is badly broken." \
        16 70
fi

echo -e "${OK} Done. Log: ${CYAN}$LOG${RESET}"
