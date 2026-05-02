#!/bin/bash

# Target file where all .jsonc contents will be merged
TARGET_FILE="merged.json"

# Check and remove old target file if needed
if [ -e "$TARGET_FILE" ]; then
  rm "$TARGET_FILE"
fi

# Loop through all .jsonc files in the current directory
for file in *.jsonc; do
  # Check whether the file exists and is readable
  if [ -r "$file" ]; then
    # Append current file contents to the target file
    cat "$file" >> "$TARGET_FILE"
    # Add an empty line as separator
    echo >> "$TARGET_FILE"
  else
    echo "Error: File $file could not be read."
  fi
done

echo "Merge process completed. Results are in $TARGET_FILE."
