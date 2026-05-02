#!/bin/bash
#                _ _
# __      ____ _| | |_ __   __ _ _ __   ___ _ __
# \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '__|
#  \ V  V / (_| | | | |_) | (_| | |_) |  __/ |
#   \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_|
#                   |_|         |_|
#
# by Avni Bilgin (2023)
# -----------------------------------------------------

# -----------------------------------------------------
# Pass the selected filename as a parameter
# -----------------------------------------------------
selected="$1"

# -----------------------------------------------------
# Check whether the file exists
# -----------------------------------------------------
if [ ! -f "$selected" ]; then
    echo "Error: File '$selected' does not exist."
    exit 1
fi

# -----------------------------------------------------
# Pass wallpaper to Pywal
# -----------------------------------------------------
wal -q -i "$selected"

# -----------------------------------------------------
# Load current pywal color scheme
# -----------------------------------------------------
source "$HOME/.cache/wal/colors.sh"
echo "Wallpaper: $wallpaper"

# -----------------------------------------------------
# Copy selected wallpaper into .cache folder
# -----------------------------------------------------
cp $wallpaper ~/.cache/current_wallpaper.jpg

# -----------------------------------------------------
# get wallpaper image name
# -----------------------------------------------------
newwall=$(echo $wallpaper | sed "s|$HOME/wallpaper/||g")

# -----------------------------------------------------
# Reload waybar with new colors
# -----------------------------------------------------
~/dotfiles/waybar/launch.sh

# -----------------------------------------------------
# Set the new wallpaper
# -----------------------------------------------------
transition_type="wipe"
# transition_type="outer"
# transition_type="random"

swww img $wallpaper \
    --transition-bezier .43,1.19,1,.4 \
    --transition-fps=60 \
    --transition-type=$transition_type \
    --transition-duration=0.7 \
    --transition-pos "$( hyprctl cursorpos )"

# -----------------------------------------------------
# Send notification
# -----------------------------------------------------
sleep 1
notify-send "Colors and wallpaper updated" "New image: $newwall"

echo "DONE!"
