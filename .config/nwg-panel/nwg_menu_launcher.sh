#!/bin/bash

nwg-menu \
  -s "menu-start.css" \
  -va "top" \
  -ha "left" \
  -fm "nautilus" \
  -term "kitty" \
  -cmd-lock "swaylock -f" \
  -cmd-logout "hyprctl dispatch exit" \
  -cmd-restart "systemctl -i reboot" \
  -cmd-shutdown "systemctl -i poweroff" \
  -isl 24 \
  -iss 16 \
  -d \