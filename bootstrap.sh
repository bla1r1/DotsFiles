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
        --ui)  INSTALLER="ui"  ;;
        --cli) INSTALLER="cli" ;;
        *)     EXTRA_ARGS+=("$arg") ;;
    esac
done

# ── Distro detection ──────────────────────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/fedora-release ]]; then
        echo "fedora"
    elif [[ -f /etc/gentoo-release ]]; then
        echo "gentoo"
    elif [[ -f /etc/SuSE-release ]] || grep -qi opensuse /etc/os-release 2>/dev/null; then
        echo "opensuse"
    else
        echo "unknown"
    fi
}

DISTRO="$(detect_distro)"

if [[ "$DISTRO" == "unknown" ]]; then
    echo "Unsupported distribution. Supported: Arch, Debian/Ubuntu, Fedora, Gentoo, openSUSE."
    exit 1
fi

echo "[INFO] Detected distro: $DISTRO"

# ── Install base tools ────────────────────────────────────────────────────────
echo "[INFO] Installing base tools (git, rsync)..."
case "$DISTRO" in
    arch)
        sudo pacman -S --needed --noconfirm git rsync
        ;;
    debian)
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends git rsync
        ;;
    fedora)
        sudo dnf install -y git rsync
        ;;
    gentoo)
        # On Gentoo git is almost always present; emerge if not
        command -v git   >/dev/null 2>&1 || sudo emerge --ask=n dev-vcs/git
        command -v rsync >/dev/null 2>&1 || sudo emerge --ask=n net-misc/rsync
        ;;
    opensuse)
        sudo zypper --non-interactive install git rsync
        ;;
esac

# ── Clone / update repo ───────────────────────────────────────────────────────
if [[ -z "$REPO_URL" ]]; then
    echo "Missing repository URL."
    echo "Usage: bash bootstrap.sh <repo_url> [install args]"
    echo "Or set DOTFILES_REPO_URL env var (default: $DEFAULT_REPO_URL)."
    exit 1
fi

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

# ── Launch installer ──────────────────────────────────────────────────────────
if [[ "$INSTALLER" == "ui" ]]; then
    SCRIPT="$TARGET_DIR/install-ui.sh"
    [[ ! -x "$SCRIPT" ]] && chmod +x "$SCRIPT" || true
    echo "[INFO] Running install-ui.sh"
    "$SCRIPT" --distro "$DISTRO"
else
    SCRIPT="$TARGET_DIR/install.sh"
    [[ ! -x "$SCRIPT" ]] && chmod +x "$SCRIPT" || true
    echo "[INFO] Running install.sh --distro $DISTRO ${EXTRA_ARGS[*]:-}"
    "$SCRIPT" --distro "$DISTRO" "${EXTRA_ARGS[@]}"
fi
