#!/usr/bin/env bash
set -euo pipefail

backend="wayland"

if pidof rofi >/dev/null; then pkill rofi; fi
if pidof yad >/dev/null; then pkill yad; fi

GDK_BACKEND="$backend" yad \
    --center \
    --width=920 \
    --height=720 \
    --title="Sway Key Hints" \
    --no-buttons \
    --list \
    --column=Key: \
    --column=Description: \
    --column=Command: \
    --timeout-indicator=bottom \
"ESC"                 "Close this window"                     "" \
"Super"               "Main modifier key"                     "" \
""                    ""                                      "" \
"--- APPS ---"        ""                                      "" \
"Super+T"             "Terminal"                              "kitty" \
"Super+E"             "File manager"                          "nautilus" \
"Super+F"             "Browser"                               "firefox" \
"Super+Space"         "Application launcher"                  "rofi" \
"Super+Shift+S"       "Quick settings"                        "quick-settings.sh" \
"Super+H"             "This help"                             "keyhints.sh" \
"Super+W"             "Wallpaper picker"                      "waypaper" \
""                    ""                                      "" \
"--- WINDOWS ---"     ""                                      "" \
"Super+Q"             "Close focused window"                  "kill" \
"Super+Shift+V"       "Toggle floating"                       "floating toggle" \
"Super+Shift+F"       "Fullscreen"                            "fullscreen toggle" \
"Super+Ctrl+F"        "Global fullscreen"                     "fullscreen toggle global" \
""                    ""                                      "" \
"--- FOCUS ---"       ""                                      "" \
"Super+Left/Right/Up/Down" "Move focus"                       "focus direction" \
"Alt+Tab"             "Focus next window"                     "focus next" \
""                    ""                                      "" \
"--- MOVE/RESIZE ---" ""                                      "" \
"Super+Ctrl+Arrows"   "Move focused window"                   "move direction" \
"Super+Shift+Arrows"  "Resize focused window"                 "resize +/- 50px" \
"Super+J"             "Toggle split layout"                   "layout toggle split" \
"Super+Shift+I"       "Toggle split direction"                "split toggle" \
""                    ""                                      "" \
"--- WORKSPACES ---"  ""                                      "" \
"Super+1..0"          "Switch workspace 1..10"                "workspace number" \
"Super+Shift+1..0"    "Move window to workspace 1..10"        "move container" \
"Super+MouseWheel"    "Next/prev workspace"                   "workspace next/prev" \
"Super+Ctrl+S"        "Show scratchpad"                       "scratchpad show" \
"Super+Ctrl+Shift+S"  "Move to scratchpad"                    "move scratchpad" \
""                    ""                                      "" \
"--- SCREENSHOTS ---" ""                                      "" \
"Super+Print"         "Screenshot full"                       "screenshot.sh full" \
"Super+Alt+Print"     "Screenshot current output"             "screenshot.sh monitor" \
"Super+Shift+Print"   "Screenshot region"                     "screenshot.sh region" \
"Alt+Print"           "Screenshot active window"              "screenshot.sh window" \
"Super+Ctrl+Print"    "Screenshot in 5s"                      "screenshot.sh delay5" \
"Super+Ctrl+Shift+Print" "Screenshot in 10s"                  "screenshot.sh delay10" \
""                    ""                                      "" \
"--- SYSTEM ---"      ""                                      "" \
"Ctrl+Alt+L"          "Lock screen"                           "swaylock.sh" \
"Super+Shift+M"       "Exit sway (with confirmation)"         "swaynag + swaymsg exit" \
""                    ""                                      "" \
"--- MEDIA ---"       ""                                      "" \
"XF86AudioRaise/Lower" "Volume up/down"                       "audio-control.sh" \
"XF86AudioMute"       "Toggle output mute"                    "audio-control.sh --toggle" \
"XF86AudioMicMute"    "Toggle mic mute"                       "mic-control.sh --toggle" \
"XF86MonBrightnessUp/Down" "Screen brightness"                "brightnessctl +/-5%" \
"XF86KbdBrightnessUp/Down" "Keyboard backlight"               "kbd-backlight.sh" \
"XF86AudioPlay/Pause/Next/Prev" "Media controls"              "playerctl"
