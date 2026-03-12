#!/usr/bin/env bash
set -euo pipefail

# Online bootstrap installer for Arch Linux.
# Intended usage:
#   curl -fsSL <raw_url_to_this_file> | bash -s -- <repo_url> [install-arch args...]
#
# You can also provide repo URL via env:
#   DOTFILES_REPO_URL=https://github.com/bla1r1/DotsFiles.git

DEFAULT_REPO_URL="https://github.com/bla1r1/DotsFiles.git"
REPO_URL="${DOTFILES_REPO_URL:-${1:-$DEFAULT_REPO_URL}}"
if [[ -n "${1:-}" && "$1" =~ ^https?://|^git@ ]]; then
    shift || true
fi

BRANCH="${DOTFILES_BRANCH:-main}"
TARGET_DIR="${DOTFILES_TARGET_DIR:-$HOME/.local/src/dotfiles}"

if [[ -z "$REPO_URL" ]]; then
    echo "Missing repository URL."
    echo "Usage: bash bootstrap-arch.sh <repo_url> [install-arch args...]"
    echo "Or set DOTFILES_REPO_URL env var (default: $DEFAULT_REPO_URL)."
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    echo "This bootstrap script supports Arch Linux only."
    exit 1
fi

echo "[INFO] Installing base tools (git, rsync)..."
sudo pacman -S --needed --noconfirm git rsync

if [[ -d "$TARGET_DIR/.git" ]]; then
    echo "[INFO] Updating existing repo in $TARGET_DIR"
    git -C "$TARGET_DIR" fetch --all --prune
    git -C "$TARGET_DIR" checkout "$BRANCH"
    git -C "$TARGET_DIR" pull --ff-only
else
    echo "[INFO] Cloning repo into $TARGET_DIR"
    mkdir -p "$(dirname "$TARGET_DIR")"
    git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

if [[ ! -x "$TARGET_DIR/install-arch.sh" ]]; then
    chmod +x "$TARGET_DIR/install-arch.sh" || true
fi

echo "[INFO] Running install-arch.sh $*"
"$TARGET_DIR/install-arch.sh" "$@"
