#!/usr/bin/env bash
# Discovery utilities - finds files and directories (no lifecycle logic)

# Guard against multiple sourcing
if [[ "${DISCOVERY_LIB_LOADED:-}" == "true" ]]; then
    return 0
fi

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/logging.sh"

# Note: Configuration is set in index.sh and passed via environment variables:
# - MERGED_FILE_PREFIX
# - CONFIG_FILE_EXTENSIONS (comma-separated)
# - SKIP_DIRECTORIES (comma-separated)

# PUBLIC: Enhanced file discovery with pattern matching and recursion control
discovery_find_config_files() {
  local search_dir="$1"
  local -n files_ref=$2
  files_ref=()
  
  if [[ ! -d "$search_dir" ]]; then
    dbg "Directory '$search_dir' does not exist, skipping"
    return
  fi
  
  # Build find command based on recursion setting
  local find_cmd=("find" "$search_dir")
  if [[ "$RECURSIVE" == "false" ]]; then
    find_cmd+=("-maxdepth" "1")
  fi
  find_cmd+=("-type" "f")
  
  # Add file patterns
  local -a pattern_args=()
  IFS=',' read -ra patterns <<< "$FILE_PATTERNS"
  for i in "${!patterns[@]}"; do
    pattern="${patterns[$i]// /}" # Remove spaces
    if [[ $i -eq 0 ]]; then
      pattern_args+=("-name" "$pattern")
    else
      pattern_args+=("-o" "-name" "$pattern")
    fi
  done
  
  if [[ ${#pattern_args[@]} -gt 0 ]]; then
    find_cmd+=("(" "${pattern_args[@]}" ")")
  fi
  
  dbg "Running: ${find_cmd[*]}"
  
  # Execute find and collect results
  while IFS= read -r file; do
    # Apply exclude patterns
    local skip=false
    local basename_file=$(basename "$file")
    
    # Check if it's a merged file
    if [[ "$basename_file" == ${MERGED_FILE_PREFIX}* ]]; then
      dbg "Excluding merged file: $file"
      skip=true
    else
      # Check other exclude patterns
      IFS=',' read -ra excludes <<< "$EXCLUDE"
      for exclude in "${excludes[@]}"; do
        exclude="${exclude// /}" # Remove spaces
        # Support glob patterns
        if [[ "$file" == $exclude ]] || [[ "$basename_file" == $exclude ]]; then
          dbg "Excluding file: $file (matches pattern: $exclude)"
          skip=true
          break
        fi
      done
    fi
    
    if [[ "$skip" == "false" ]]; then
      files_ref+=("$file")
    fi
  done < <("${find_cmd[@]}" 2>/dev/null | sort)
}

# PUBLIC: Check if directory contains YAML files
# Returns: 0 if contains YAML files, 1 otherwise
discovery_has_yaml_files() {
    local dir="$1"
    local patterns=()
    IFS=',' read -ra extensions <<< "${CONFIG_FILE_EXTENSIONS}"
    local first=true
    for ext in "${extensions[@]}"; do
        ext="${ext// /}" # Remove spaces
        if [[ "$first" == "true" ]]; then
            patterns+=("-name" "*.$ext")
            first=false
        else
            patterns+=("-o" "-name" "*.$ext")
        fi
    done
    find "$dir" -maxdepth 1 \( "${patterns[@]}" \) 2>/dev/null | head -1 | read
}

# PUBLIC: Check if directory should be skipped
# Returns: 0 if should skip, 1 otherwise
discovery_should_skip_directory() {
    local dir_name="$1"
    
    # Skip hidden directories
    [[ "$dir_name" == .* ]] && return 0
    
    # Skip configured directories
    IFS=',' read -ra skip_dirs <<< "${SKIP_DIRECTORIES}"
    for skip_dir in "${skip_dirs[@]}"; do
        skip_dir="${skip_dir// /}" # Remove spaces
        [[ "$dir_name" == "$skip_dir" ]] && return 0
    done
    
    return 1
}

# PUBLIC: Find directory matching a pattern
# Usage: discovery_find_dir_matching "pattern" "unique_dirs_array"
# Returns: first matching directory or empty string
discovery_find_dir_matching() {
    local pattern="$1"
    shift
    local dirs=("$@")
    
    for dir in "${dirs[@]}"; do
        if [[ "$dir" == $pattern ]]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}
