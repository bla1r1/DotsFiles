#!/bin/bash

# Source file path
source_path="$HOME/.cache/wal/colors-polybar"

# Target directory and filename
target_directory="$HOME/.config/polybar/shapes"
target_filename="colors.ini"

# Full target path
target_path="$target_directory/$target_filename"

# Check whether the target directory exists; otherwise create it
if [ ! -d "$target_directory" ]; then
    mkdir -p "$target_directory"
fi

# Copy the file
cp "$source_path" "$target_path"
