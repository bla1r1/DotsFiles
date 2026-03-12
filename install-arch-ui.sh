#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$REPO_DIR/install-arch.sh"

if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    echo "install-arch.sh not found next to install-arch-ui.sh"
    exit 1
fi

install_packages=1
install_dotfiles=1
install_services=1
install_aur=1

confirm() {
    local prompt="$1"
    local default="${2:-Y}"
    local answer=""
    if [[ "$default" == "Y" ]]; then
        read -r -p "$prompt [Y/n]: " answer
        [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
    else
        read -r -p "$prompt [y/N]: " answer
        [[ "$answer" =~ ^[Yy]$ ]]
    fi
}

if command -v whiptail >/dev/null 2>&1; then
    CHOICES=$(whiptail --title "DotsFiles Arch Installer" \
        --checklist "Select installation steps:" 18 78 8 \
        "packages" "Install pacman/AUR packages" ON \
        "dotfiles" "Deploy dotfiles to ~/.config" ON \
        "services" "Enable services (NetworkManager, bluetooth)" ON \
        "aur" "Install AUR packages" ON \
        3>&1 1>&2 2>&3) || exit 1

    install_packages=0
    install_dotfiles=0
    install_services=0
    install_aur=0

    [[ "$CHOICES" == *"packages"* ]] && install_packages=1
    [[ "$CHOICES" == *"dotfiles"* ]] && install_dotfiles=1
    [[ "$CHOICES" == *"services"* ]] && install_services=1
    [[ "$CHOICES" == *"aur"* ]] && install_aur=1

    whiptail --title "Confirm" --yesno \
        "Proceed with selected installation steps?" 10 60 || exit 1
else
    echo "whiptail not found. Using simple interactive prompts."
    confirm "Install packages?" Y && install_packages=1 || install_packages=0
    confirm "Deploy dotfiles?" Y && install_dotfiles=1 || install_dotfiles=0
    confirm "Enable services?" Y && install_services=1 || install_services=0
    confirm "Install AUR packages?" Y && install_aur=1 || install_aur=0
    echo
    echo "Selected:"
    echo "  packages: $install_packages"
    echo "  dotfiles: $install_dotfiles"
    echo "  services: $install_services"
    echo "  aur:      $install_aur"
    confirm "Proceed?" Y || exit 1
fi

args=()
[[ "$install_packages" -eq 0 ]] && args+=(--skip-packages)
[[ "$install_dotfiles" -eq 0 ]] && args+=(--skip-dotfiles)
[[ "$install_services" -eq 0 ]] && args+=(--skip-services)
[[ "$install_aur" -eq 0 ]] && args+=(--no-aur)

echo
echo "[INFO] Running: $INSTALL_SCRIPT ${args[*]:-}"
bash "$INSTALL_SCRIPT" "${args[@]}"
