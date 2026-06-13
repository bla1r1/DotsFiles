#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET="$REPO_DIR/.config/fish/functions"
TARGET_DIR="${1:-${TIDE_FUNCTIONS_DIR:-$DEFAULT_TARGET}}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Tide functions directory not found: $TARGET_DIR" >&2
    exit 1
fi

cd "$TARGET_DIR"

rm -f _tide_item_aws.fish
rm -f _tide_item_crystal.fish
rm -f _tide_item_direnv.fish
rm -f _tide_item_distrobox.fish
rm -f _tide_item_docker.fish
rm -f _tide_item_elixir.fish
rm -f _tide_item_gcloud.fish
rm -f _tide_item_java.fish
rm -f _tide_item_kubectl.fish
rm -f _tide_item_nix_shell.fish
rm -f _tide_item_node.fish
rm -f _tide_item_php.fish
rm -f _tide_item_private_mode.fish
rm -f _tide_item_pulumi.fish
rm -f _tide_item_ruby.fish
rm -f _tide_item_rustc.fish
rm -f _tide_item_shlvl.fish
rm -f _tide_item_terraform.fish
rm -f _tide_item_toolbox.fish
rm -f _tide_item_vi_mode.fish
rm -f _tide_item_zig.fish

echo "Cleaned up 21 unused Tide items in $TARGET_DIR"
echo "Remaining: character, cmd_duration, context, git, go, jobs, os, python, pwd, status, time"
