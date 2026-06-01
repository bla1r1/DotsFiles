#!/usr/bin/env bash
layout=$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[] | select(.type == "keyboard") | .xkb_active_layout_name? // empty][0] // empty')
[[ -z "$layout" || "$layout" == "null" ]] && layout="US"
echo "${layout:0:2}" | tr '[:lower:]' '[:upper:]'
