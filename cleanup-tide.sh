#!/bin/bash
# Remove unused Tide item functions
cd /workspaces/DotsFiles/.config/fish/functions

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

echo "✅ Cleaned up 21 unused Tide items"
echo "Remaining: character, cmd_duration, context, git, go, jobs, os, python, pwd, status, time"
