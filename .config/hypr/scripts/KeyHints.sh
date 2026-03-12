#!/usr/bin/env bash
# /* ---- 💫 Hyprland Quick Cheat Sheet 💫 ---- */

BACKEND=wayland

if pidof rofi > /dev/null; then pkill rofi; fi
if pidof yad  > /dev/null; then pkill yad;  fi

GDK_BACKEND=$BACKEND yad \
    --center \
    --width=900 \
    --height=700 \
    --title="Hyprland Quick Cheat Sheet" \
    --no-buttons \
    --list \
    --column=Key: \
    --column=Description: \
    --column=Command: \
    --timeout-indicator=bottom \
"ESC"                        "Close this window"                 "" \
" = "                        "SUPER KEY (Windows Key)"           "" \
""                           ""                                  "" \
"--- APPS ---"               ""                                  "" \
" T"                         "Terminal"                          "(kitty)" \
" E"                         "File Manager"                      "(nautilus)" \
" F"                         "Browser"                           "(firefox)" \
" SPACE"                     "Application Launcher"              "(rofi)" \
" SHIFT SPACE"               "Run as sudo"                       "(rofi + alacritty)" \
" SHIFT S"                   "Quick Settings Menu"               "(quick-settings.sh)" \
" H"                         "This cheat sheet"                  "(yad)" \
""                           ""                                  "" \
"--- WINDOWS ---"            ""                                  "" \
" Q"                         "Close active window"               "" \
" V"                         "Toggle floating"                   "single window" \
" ALT SPACE"                 "Float all windows"                 "all windows on workspace" \
" SHIFT F"                   "Fullscreen"                        "true fullscreen" \
" CTRL F"                    "Maximize"                          "keeps bar visible" \
" CTRL O"                    "Toggle opacity"                    "active window only" \
""                           ""                                  "" \
"--- FOCUS ---"              ""                                  "" \
" ← → ↑ ↓"                  "Move focus"                        "arrow keys" \
"ALT Tab"                    "Cycle windows"                     "bring active to top" \
""                           ""                                  "" \
"--- MOVE & RESIZE ---"      ""                                  "" \
" CTRL ← → ↑ ↓"             "Move window"                       "arrow keys" \
" ALT ← → ↑ ↓"              "Swap window"                       "arrow keys" \
" SHIFT ← → ↑ ↓"            "Resize window"                     "(±50px, repeatable)" \
" + drag LMB"                "Move window"                       "(mouse)" \
" + drag RMB"                "Resize window"                     "(mouse)" \
""                           ""                                  "" \
"--- GROUPS ---"             ""                                  "" \
" G"                         "Toggle group"                      "" \
" Tab"                       "Next window in group"              "cycle forward" \
" SHIFT Tab"                 "Previous window in group"          "cycle backward" \
" CTRL K"                    "Move window into group (left)"     "" \
" CTRL L"                    "Move window into group (right)"    "" \
" CTRL H"                    "Move window out of group"          "" \
""                           ""                                  "" \
"--- LAYOUT ---"             ""                                  "" \
" P"                         "Toggle pseudo tile"                "(dwindle)" \
" J"                         "Toggle split"                      "(dwindle)" \
" I"                         "Add master"                        "(master layout)" \
" CTRL D"                    "Remove master"                     "(master layout)" \
" CTRL Enter"                "Swap with master"                  "(master layout)" \
" SHIFT I"                   "Toggle split"                      "(dwindle)" \
""                           ""                                  "" \
"--- WORKSPACES ---"         ""                                  "" \
" 1 .. 0"                    "Switch to workspace 1–10"          "" \
" SHIFT 1 .. 0"              "Move window to workspace 1–10"     "" \
" S"                         "Toggle scratchpad"                 "(special:magic)" \
" + scroll ↑↓"               "Scroll workspaces"                 "" \
""                           ""                                  "" \
"--- SCREENSHOTS ---"        ""                                  "" \
" Print"                     "Screenshot now"                    "~/Pictures/Screenshots/" \
" SHIFT Print"               "Screenshot region"                 "(slurp to select)" \
" CTRL Print"                "Screenshot in 5 sec"               "" \
" CTRL SHIFT Print"          "Screenshot in 10 sec"              "" \
"ALT Print"                  "Screenshot active window"          "" \
""                           ""                                  "" \
"--- SYSTEM ---"             ""                                  "" \
"CTRL ALT L"                 "Lock screen"                       "(hyprlock)" \
" M"                         "Exit Hyprland"                     "(hyprctl exit)" \
""                           ""                                  "" \
"--- MEDIA ---"              ""                                  "" \
"Vol +/-"                    "Volume up / down"                  "(wpctl ±5%)" \
"Mute"                       "Toggle mute"                       "(wpctl)" \
"Mic Mute"                   "Toggle mic"                        "(wpctl)" \
"Brightness +/-"             "Brightness up / down"              "(brightnessctl ±5%)" \
"Play/Pause/Next/Prev"       "Media controls"                    "(playerctl)" \
