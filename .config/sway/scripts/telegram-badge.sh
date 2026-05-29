#!/usr/bin/env bash
set -euo pipefail

title="$(
    swaymsg -t get_tree 2>/dev/null \
        | jq -r '
            first(
                .. | objects
                | select(.app_id? == "org.telegram.desktop")
                | (.name // "")
                | capture("\\((?<count>[0-9]+)\\)")?
                | .count
            ) // empty
        ' 2>/dev/null
)"

if [ -n "$title" ]; then
    echo "{\"text\": \"$title\", \"class\": \"unread\", \"tooltip\": \"Telegram: $title непрочитанных\"}"
else
    echo "{\"text\": \"\", \"class\": \"\", \"tooltip\": \"Telegram\"}"
fi
