#!/usr/bin/env bash

set -euo pipefail

num="$(
    swaymsg -t get_workspaces \
        | jq -r '[.[].num] as $used | first(range(1; 100) | select($used | index(.) | not))'
)"

swaymsg move to workspace number "$num"
swaymsg workspace number "$num"
swaymsg fullscreen toggle
