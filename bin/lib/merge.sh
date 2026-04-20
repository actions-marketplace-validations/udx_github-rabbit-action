#!/usr/bin/env bash
# File merging utilities

# Guard against multiple sourcing
if [[ "${MERGE_LIB_LOADED:-}" == "true" ]]; then
    return 0
fi

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/logging.sh"

# File permissions for merged output
readonly MERGED_FILE_PERMISSIONS="644"

# Merge multiple YAML/JSON files into one
# Usage: merge_files "output_file" "input_file1" "input_file2" ...
# Returns: 0 on success, 1 on failure
merge_yaml_files() {
  local output="$1"
  shift
  local files=("$@")
  
  if (( ${#files[@]} == 0 )); then
    err "No files to merge"
    return 1
  fi
  
  dbg "Merging ${#files[@]} files into $output"
  for file in "${files[@]}"; do
    dbg "  - $file"
  done
  
  # Create temporary file for merge
  local tmp_file
  tmp_file=$(mktemp)
  
  # Step 1: Use yq to merge files with deep merge strategy
  if ! yq ea '. as $item ireduce ({}; . *+ $item)' "${files[@]}" > "$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    err "Failed to merge files"
    return 1
  fi
  
  # Step 2: Deduplicate services by module + ID (merge configurations for same module+id)
  # Use * operator to replace arrays (not concatenate)
  local tmp_dedup=$(mktemp)
  yq eval '.services = [.services | group_by(.module + "::" + .id) | .[] | (.[0] * (.[1] // {}))]' "$tmp_file" > "$tmp_dedup"
  rm -f "$tmp_file"
  
  # Step 3: Convert to requested output format
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    yq -o json '.' "$tmp_dedup" > "$output"
  else
    mv "$tmp_dedup" "$output"
  fi
  rm -f "$tmp_dedup"
  
  # Set readable permissions
  chmod "$MERGED_FILE_PERMISSIONS" "$output"
  dbg "Set permissions $MERGED_FILE_PERMISSIONS on merged file: $output"
  
  return 0
}

readonly MERGE_LIB_LOADED="true"
