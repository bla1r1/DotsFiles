#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/bla1r1/DotsFiles.git"
REPO_URL="${DOTFILES_REPO_URL:-${1:-$DEFAULT_REPO_URL}}"

if [[ -n "${1:-}" && "$1" =~ ^https?://|^git@ ]]; then
    shift || true
fi

BRANCH="${DOTFILES_BRANCH:-main}"
TARGET_DIR="${DOTFILES_TARGET_DIR:-$HOME/.local/src/dotfiles}"
INSTALLER="${DOTFILES_INSTALLER:-cli}"

EXTRA_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --ui) INSTALLER="ui" ;;
        --cli) INSTALLER="cli" ;;
        *) EXTRA_ARGS+=("$arg") ;;
    esac
done

if [[ -z "$REPO_URL" ]]; then
    echo "Missing repository URL."
    echo "Usage: bash bootstrap-arch.sh <repo_url> [install args]"
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

if [[ "$INSTALLER" == "ui" ]]; then
    if [[ ! -x "$TARGET_DIR/install-arch-ui.sh" ]]; then
        chmod +x "$TARGET_DIR/install-arch-ui.sh" || true
    fi
    echo "[INFO] Running install-arch-ui.sh"
    "$TARGET_DIR/install-arch-ui.sh"
else
    if [[ ! -x "$TARGET_DIR/install-arch.sh" ]]; then
        chmod +x "$TARGET_DIR/install-arch.sh" || true
    fi
    echo "[INFO] Running install-arch.sh ${EXTRA_ARGS[*]:-}"
    "$TARGET_DIR/install-arch.sh" "${EXTRA_ARGS[@]}"
fi
