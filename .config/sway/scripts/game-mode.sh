#!/usr/bin/env bash

used=$(swaymsg -t get_workspaces | jq '[.[].num]')
num=1
while echo "$used" | jq -e "contains([$num])" > /dev/null; do
    ((num++))
done

swaymsg move to workspace number $num
swaymsg workspace number $num
swaymsg fullscreen toggle
