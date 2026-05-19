#!/usr/bin/env bash

pgrep -f "joystick-inhibit" | grep -v $$ > /dev/null && exit 0

inhibit_device() {
    local dev="$1"
    pgrep -f "dd if=$dev" > /dev/null && return
    systemd-inhibit \
        --what=idle \
        --who="Wheel" \
        --why="Steering wheel active" \
        --mode=block \
        dd if="$dev" of=/dev/null &
}

for dev in /dev/input/js*; do
    [ -e "$dev" ] && inhibit_device "$dev"
done

inotifywait -m -e create /dev/input/ 2>/dev/null | while read -r _ _ file; do
    [[ "$file" == js* ]] && inhibit_device "/dev/input/$file"
done
