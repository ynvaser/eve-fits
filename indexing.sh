#!/bin/bash

echo "Indexing..."

# Usage: ./generate-index.sh [root_directory]
# Defaults to current directory

ROOT_DIR="${1:-.}"
ROOT_DIR_ABS=$(cd "$ROOT_DIR"; pwd)

# Global associative array for caching ship name -> type ID lookups
declare -A ship_cache

generate_index() {
  local current_dir="$1"
  local prefix="$2"

  # Use absolute path for current directory
  local abs_dir="$ROOT_DIR_ABS/$prefix"

  # Start output to index.json in current directory
  local index_file="$abs_dir/index.json"
  echo "[" > "$index_file"

  local first=true
  # Use nullglob to handle empty directories
  shopt -s nullglob
  # List items inside abs_dir, ignoring hidden and index.json
  for item_path in "$abs_dir"/*; do
    item=$(basename "$item_path")
    if [ "$item" = "index.json" ] || [[ "$item" =~ ^\. ]]; then
      continue
    fi

    if [ -d "$item_path" ]; then
      type="dir"
    elif [ -f "$item_path" ] && [[ "$item" == *.txt ]]; then
      type="file"
    else
      # Ignore other files
      continue
    fi

    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$index_file"
    fi

    # Compose JSON object with full relative path from ROOT_DIR
    local rel_path
    if [ -z "$prefix" ]; then
      rel_path="$item"
    else
      rel_path="$prefix/$item"
    fi

    # Escape strings for JSON
    name_escaped=$(printf '%s' "$item" | sed 's/"/\\"/g')
    path_escaped=$(printf '%s' "$rel_path" | sed 's/"/\\"/g')

    if [ "$type" = "file" ]; then
      # Extract ship name from the first line matching EVE fit header bracket pattern
      first_matching_line=$(grep -m 1 "^\[.*,.*\]" "$item_path")
      ship_name=$(echo "$first_matching_line" | sed -n 's/^\[\([^,]*\),.*/\1/p' | xargs)
      
      ship_id="null"
      if [ -n "$ship_name" ]; then
        if [ -n "${ship_cache[$ship_name]}" ]; then
          ship_id="${ship_cache[$ship_name]}"
        else
          echo "Resolving ID for ship: $ship_name..."
          res=$(curl -s -X POST "https://esi.evetech.net/latest/universe/ids/?datasource=tranquility" \
            -H "Content-Type: application/json" \
            -d "[\"$ship_name\"]")
          fetched_id=$(echo "$res" | sed -n 's/.*"inventory_types":\[{"id":\([0-9]*\),.*/\1/p')
          if [[ "$fetched_id" =~ ^[0-9]+$ ]]; then
            ship_id="$fetched_id"
            ship_cache["$ship_name"]="$ship_id"
          fi
        fi
      fi
      
      echo "  { \"name\": \"$name_escaped\", \"type\": \"$type\", \"path\": \"$path_escaped\", \"shipTypeId\": $ship_id }" >> "$index_file"
    else
      echo "  { \"name\": \"$name_escaped\", \"type\": \"$type\", \"path\": \"$path_escaped\" }" >> "$index_file"
    fi
  done

  echo "]" >> "$index_file"

  # Recurse into subdirectories
  for dir_path in "$abs_dir"/*/; do
    [ -d "$dir_path" ] || continue
    dir_name=$(basename "$dir_path")
    if [[ "$dir_name" =~ ^\. ]]; then
      continue
    fi
    # Recurse with updated prefix path
    if [ -z "$prefix" ]; then
      generate_index "$ROOT_DIR" "$dir_name"
    else
      generate_index "$ROOT_DIR" "$prefix/$dir_name"
    fi
  done
}

generate_index "$ROOT_DIR" ""
