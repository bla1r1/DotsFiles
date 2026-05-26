#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles-update-backup-$(date +%Y%m%d-%H%M%S)"
SKIP_FONTCONFIG=0
SKIP_WALLPAPERS=0
DRY_RUN=0

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --repo-dir <path>    Use a custom repo directory
  --backup-dir <path>  Store backups in a custom directory
  --skip-fontconfig    Do not update fontconfig files
  --skip-wallpapers    Do not update wallpapers
  --dry-run            Show planned actions without changing files
  -h, --help           Show this help and exit
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo-dir)
                REPO_DIR="$2"
                shift 2
                ;;
            --repo-dir=*)
                REPO_DIR="${1#--repo-dir=}"
                shift
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --backup-dir=*)
                BACKUP_DIR="${1#--backup-dir=}"
                shift
                ;;
            --skip-fontconfig)
                SKIP_FONTCONFIG=1
                shift
                ;;
            --skip-wallpapers)
                SKIP_WALLPAPERS=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

ensure_backup_dir() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would create backup directory: $BACKUP_DIR"
    else
        mkdir -p "$BACKUP_DIR"
    fi
}

backup_path() {
    local src="$1"
    local dst="$2"

    [[ -e "$src" || -L "$src" ]] || return 0

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would back up $src -> $dst"
    else
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
    fi
}

overlay_copy() {
    local src="$1"
    local dst="$2"

    [[ -d "$src" ]] || return 0

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would copy $src -> $dst"
        rsync -avn "$src/" "$dst/"
    else
        mkdir -p "$dst"
        rsync -a "$src/" "$dst/"
    fi
}

update_config_tree() {
    local src_root="$REPO_DIR/.config"
    local dst_root="$HOME/.config"

    [[ -d "$src_root" ]] || { warn "No .config directory found in $REPO_DIR"; return 0; }

    ensure_backup_dir

    local item base
    shopt -s nullglob
    for item in "$src_root"/*; do
        base="$(basename "$item")"
        backup_path "$dst_root/$base" "$BACKUP_DIR/.config/$base"
        overlay_copy "$item" "$dst_root/$base"
    done
    shopt -u nullglob
}

update_wallpapers() {
    local src="$REPO_DIR/.wallpapers"
    local dst="$HOME/.wallpapers"

    [[ "$SKIP_WALLPAPERS" -eq 0 ]] || return 0
    [[ -d "$src" ]] || return 0

    ensure_backup_dir
    backup_path "$dst" "$BACKUP_DIR/.wallpapers"
    overlay_copy "$src" "$dst"
}

update_fontconfig() {
    local script="$REPO_DIR/update-fontconfig.sh"

    [[ "$SKIP_FONTCONFIG" -eq 0 ]] || return 0

    if [[ ! -f "$script" ]]; then
        warn "Fontconfig updater not found: $script"
        return 0
    fi

    log "Updating fontconfig..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        bash "$script" --repo-dir "$REPO_DIR" --dry-run
    else
        bash "$script" --repo-dir "$REPO_DIR"
    fi
}

main() {
    parse_args "$@"

    [[ -d "$REPO_DIR" ]] || { warn "Repo directory not found: $REPO_DIR"; exit 1; }

    log "Backup directory: $BACKUP_DIR"
    update_config_tree
    update_wallpapers
    update_fontconfig
    log "Done."
}

main "$@"
