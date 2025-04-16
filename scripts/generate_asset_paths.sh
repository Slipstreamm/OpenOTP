#!/bin/bash

PRIMARY_PATH="assets/vectors"
FALLBACK_PATH="../assets/vectors"
OUTPUT_FILE="asset_paths.txt"

# Determine which path to use
if [ -d "$PRIMARY_PATH" ]; then
  TARGET="$PRIMARY_PATH"
elif [ -d "$FALLBACK_PATH" ]; then
  echo "Primary path not found. Using fallback path: $FALLBACK_PATH"
  TARGET="$FALLBACK_PATH"
else
  echo "Error: Neither '$PRIMARY_PATH' nor '$FALLBACK_PATH' exist."
  exit 1
fi

# Find immediate subdirectories and format
find "$TARGET" -mindepth 1 -maxdepth 1 -type d \
  | sed 's|\\|/|g' \
  | sed 's|$|/|' \
  | sed 's|^|    - |' > "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE with $(wc -l < "$OUTPUT_FILE") entries."