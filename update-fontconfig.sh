#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKIP_CACHE=0
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
  --repo-dir <path>  Use a custom repo directory
  --skip-cache       Skip fc-cache refresh
  --dry-run          Show what would be copied without changing the system
  -h, --help         Show this help and exit
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
            --skip-cache)
                SKIP_CACHE=1
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

sync_dir() {
    local src="$1"
    local dst="$2"

    if [[ ! -d "$src" ]]; then
        warn "Directory not found, skipping: $src"
        return 0
    fi

    log "Syncing $src -> $dst"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        sudo rsync -avn "$src/" "$dst/"
    else
        sudo install -d -m 755 "$dst"
        sudo rsync -a "$src/" "$dst/"
    fi
}

main() {
    parse_args "$@"

    if [[ "$OSTYPE" != linux* ]]; then
        warn "This script is intended for Linux systems only."
        exit 1
    fi

    [[ -d "$REPO_DIR" ]] || { warn "Repo directory not found: $REPO_DIR"; exit 1; }

    local etc_fonts="$REPO_DIR/etc/fonts"
    local share_fontconfig="$REPO_DIR/usr/share/fontconfig"

    if [[ ! -d "$etc_fonts" && ! -d "$share_fontconfig" ]]; then
        warn "No fontconfig directories found in $REPO_DIR"
        exit 1
    fi

    sudo -v

    sync_dir "$etc_fonts" "/etc/fonts"
    sync_dir "$share_fontconfig" "/usr/share/fontconfig"

    if [[ "$SKIP_CACHE" -eq 0 ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would refresh font cache: fc-cache -f"
        else
            log "Refreshing font cache..."
            sudo fc-cache -f
        fi
    fi

    log "Done."
}

main "$@"
