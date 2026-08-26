#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — One-line Bootstrap for DotsFiles Setup
# =============================================================================
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/bla1r1/DotsFiles.git"
REPO_URL="${DOTFILES_REPO_URL:-${1:-$DEFAULT_REPO_URL}}"

if [[ -n "${1:-}" && "$1" =~ ^https?://|^git@ ]]; then
    shift || true
fi

BRANCH="${DOTFILES_BRANCH:-main}"
TARGET_DIR="${DOTFILES_TARGET_DIR:-$HOME/.local/src/dotfiles}"
INSTALLER="ui"

EXTRA_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --ui)  INSTALLER="ui"  ;;
        --cli) INSTALLER="cli" ;;
        *)     EXTRA_ARGS+=("$arg") ;;
    esac
done

if [[ ! -f /etc/arch-release ]]; then
    echo "[ERROR] Unsupported distribution. DotsFiles is crafted for Arch Linux."
    exit 1
fi

echo "[INFO] Installing base bootstrap dependencies (git, rsync)..."
sudo pacman -S --needed --noconfirm git rsync

if [[ -d "$TARGET_DIR/.git" ]]; then
    echo "[INFO] Updating existing repository in $TARGET_DIR..."
    git -C "$TARGET_DIR" fetch --all --prune
    git -C "$TARGET_DIR" checkout "$BRANCH"
    git -C "$TARGET_DIR" pull --ff-only
else
    echo "[INFO] Cloning DotsFiles repository into $TARGET_DIR..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

if [[ "$INSTALLER" == "ui" ]]; then
    SCRIPT="$TARGET_DIR/install-ui.sh"
    chmod +x "$SCRIPT"
    "$SCRIPT"
else
    SCRIPT="$TARGET_DIR/install.sh"
    chmod +x "$SCRIPT"
    "$SCRIPT" "${EXTRA_ARGS[@]}"
fi
