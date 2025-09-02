#!/bin/bash

# Usage: ./generate-index.sh [directory]
# Defaults to current directory if no argument provided

DIR="${1:-.}"

generate_index() {
  local current_dir="$1"

  cd "$current_dir" || return

  echo "[" > index.json

  local first=true
  for item in *; do
    # Skip index.json and hidden files/folders
    if [ "$item" = "index.json" ] || [[ "$item" =~ ^\. ]]; then
      continue
    fi

    if [ -d "$item" ]; then
      type="dir"
    elif [ -f "$item" ] && [[ "$item" == *.txt ]]; then
      type="file"
    else
      continue
    fi

    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> index.json
    fi

    name_escaped=$(printf '%s' "$item" | sed 's/"/\\"/g')
    path_escaped=$(printf '%s' "$item" | sed 's/"/\\"/g')

    echo "  { \"name\": \"$name_escaped\", \"type\": \"$type\", \"path\": \"$path_escaped\" }" >> index.json
  done

  echo "]" >> index.json

  # Recurse into subdirectories
  for dir in */; do
    [ -d "$dir" ] || continue
    generate_index "$dir"
  done

  cd - > /dev/null || return
}

generate_index "$DIR"
