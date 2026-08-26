#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_LIB="$SCRIPT_DIR/../lib/platform.sh"

if [[ -f "$PLATFORM_LIB" ]]; then
    # shellcheck disable=SC1090
    source "$PLATFORM_LIB"
fi

has_cmd() {
    if declare -F dotfiles_has_cmd >/dev/null 2>&1; then
        dotfiles_has_cmd "$1"
    else
        command -v "$1" >/dev/null 2>&1
    fi
}

detect_terminal() {
    if declare -F dotfiles_detect_terminal >/dev/null 2>&1; then
        dotfiles_detect_terminal || true
    fi
}

find_repo_dir() {
    local candidates=(
        "${DOTFILES_REPO_DIR:-}"
        "$HOME/GitHub/DotsFiles"
        "$HOME/.local/src/dotfiles"
        "$HOME/DotsFiles"
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        [[ -n "$candidate" ]] || continue
        if [[ -d "$candidate/.git" && -f "$candidate/update-dotfiles.sh" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

get_remote_ref() {
    local repo_dir="$1"
    local upstream=""
    upstream="$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -n "$upstream" ]]; then
        printf '%s\n' "$upstream"
    elif git -C "$repo_dir" show-ref --verify --quiet refs/remotes/origin/main; then
        printf 'origin/main\n'
    else
        printf 'origin/master\n'
    fi
}

print_status_json() {
    local repo_dir remote_ref branch local_hash remote_hash update_available
    if ! repo_dir="$(find_repo_dir)"; then
        printf '{"ok":false,"error":"repo_not_found"}\n'
        return 0
    fi

    git -C "$repo_dir" fetch --quiet origin >/dev/null 2>&1 || true

    branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'local')"
    local_hash="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
    remote_ref="$(get_remote_ref "$repo_dir")"
    remote_hash="$(git -C "$repo_dir" rev-parse --short "$remote_ref" 2>/dev/null || printf '')"
    update_available=false

    if [[ -n "$remote_hash" && "$local_hash" != "$remote_hash" ]]; then
        update_available=true
    fi

    jq -cn \
        --arg repo_dir "$repo_dir" \
        --arg branch "$branch" \
        --arg local_hash "$local_hash" \
        --arg remote_hash "$remote_hash" \
        --arg remote_ref "$remote_ref" \
        --argjson update_available "$update_available" \
        '{
            ok: true,
            repo_dir: $repo_dir,
            branch: $branch,
            local_hash: $local_hash,
            remote_hash: $remote_hash,
            remote_ref: $remote_ref,
            update_available: $update_available
        }'
}

launch_terminal() {
    local cmd="$1"
    local terminal
    terminal="$(detect_terminal)"

    case "$terminal" in
        kitty)
            kitty --title dotfiles-update sh -lc "$cmd" &
            ;;
        footclient)
            footclient sh -lc "$cmd" &
            ;;
        foot)
            foot sh -lc "$cmd" &
            ;;
        wezterm)
            wezterm start --always-new-process -- sh -lc "$cmd" &
            ;;
        alacritty)
            alacritty -e sh -lc "$cmd" &
            ;;
        gnome-terminal)
            gnome-terminal -- sh -lc "$cmd" &
            ;;
        konsole)
            konsole -p tabtitle=dotfiles-update -e sh -lc "$cmd" &
            ;;
        xfce4-terminal)
            xfce4-terminal --title=dotfiles-update --command="sh -lc '$cmd'" &
            ;;
        x-terminal-emulator)
            x-terminal-emulator -e sh -lc "$cmd" &
            ;;
        xterm)
            xterm -T dotfiles-update -e sh -lc "$cmd" &
            ;;
        *)
            if has_cmd notify-send; then
                notify-send "DotsFiles Update" "No supported terminal found"
            fi
            return 1
            ;;
    esac
}

run_update() {
    local repo_dir pull_cmd update_cmd full_cmd
    if ! repo_dir="$(find_repo_dir)"; then
        if has_cmd notify-send; then
            notify-send "DotsFiles Update" "Repo not found"
        fi
        return 1
    fi

    pull_cmd="git -C $(printf '%q' "$repo_dir") pull --ff-only"
    update_cmd="bash $(printf '%q' "$repo_dir/update-dotfiles.sh") --repo-dir $(printf '%q' "$repo_dir")"
    launch_terminal "$full_cmd"
}

run_system_update() {
    local cmd="if command -v yay >/dev/null 2>&1; then yay -Syu; elif command -v paru >/dev/null 2>&1; then paru -Syu; else sudo pacman -Syu; fi; status=\$?; if command -v notify-send >/dev/null 2>&1; then if [ \$status -eq 0 ]; then notify-send 'System Update' 'System packages updated successfully'; else notify-send 'System Update' 'System update encountered errors'; fi; fi; printf '\nPress Enter to close...'; read -r _; exit \$status"
    launch_terminal "$cmd"
}

case "${1:-status}" in
    status)
        print_status_json
        ;;
    run|env)
        run_update
        ;;
    sys|system)
        run_system_update
        ;;
    *)
        printf 'Usage: %s [status|env|sys]\n' "$0" >&2
        exit 1
        ;;
esac
