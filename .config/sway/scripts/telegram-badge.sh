#!/bin/bash
title=$(swaymsg -t get_tree 2>/dev/null | python3 -c "
import json, sys, re
def walk(node):
    if node.get('app_id') == 'org.telegram.desktop':
        name = node.get('name', '') or ''
        m = re.search(r'\((\d+)\)', name)
        if m:
            print(m.group(1))
            return
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        walk(child)
walk(json.load(sys.stdin))
" 2>/dev/null)

if [ -n "$title" ]; then
    echo "{\"text\": \"$title\", \"class\": \"unread\", \"tooltip\": \"Telegram: $title непрочитанных\"}"
else
    echo "{\"text\": \"\", \"class\": \"\", \"tooltip\": \"Telegram\"}"
fi
