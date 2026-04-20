#!/usr/bin/env bash
# Output generation utilities

# Guard against multiple sourcing
if [[ "${OUTPUT_LIB_LOADED:-}" == "true" ]]; then
  return 0
fi

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/logging.sh"

# Note: Configuration is set in index.sh and passed via environment variables:
# - MERGED_FILE_PREFIX
# - NO_ENVIRONMENT_VALUE
# - LIFECYCLE_DEVELOPMENT
# - FALLBACK_LIFECYCLE

# Global associative array to track source files for each merged file
declare -gA SOURCE_FILE_MAPPING

# PUBLIC: Generate empty outputs when no valid configs are found
output_generate_empty() {
    # Output empty values to GitHub Actions
    echo "environment=${ENV_NAME:-$NO_ENVIRONMENT_VALUE}" >> "$GITHUB_OUTPUT"
    echo "lifecycle=" >> "$GITHUB_OUTPUT"
    echo "files_count=0" >> "$GITHUB_OUTPUT"
    echo "merged_config=" >> "$GITHUB_OUTPUT"
    echo "source_files=[]" >> "$GITHUB_OUTPUT"
    echo "merged_files=[]" >> "$GITHUB_OUTPUT"
    
    dbg "GitHub Actions outputs set to empty values"
}

_append_summary_table() {
    local environment_value="$1"
    local lifecycle_value="$2"
    local files_count="$3"
    local merged_files_count="$4"
    local merged_config_value="$5"
    local status_value="$6"

    if [[ "${ENABLE_SUMMARY:-false}" != "true" || -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
        return 0
    fi

    {
        echo "## Infra Config Summary"
        echo ""
        echo "| Field | Value |"
        echo "| --- | --- |"
        echo "| Environment | \`${environment_value}\` |"
        echo "| Lifecycle | \`${lifecycle_value}\` |"
        echo "| Files Processed | \`${files_count}\` |"
        echo "| Merged Files | \`${merged_files_count}\` |"
        echo "| Primary Config | \`${merged_config_value}\` |"
        echo "| Status | \`${status_value}\` |"
        echo ""
    } >> "$GITHUB_STEP_SUMMARY"
}

_count_json_array_items() {
    local json_array="$1"

    if [[ "$json_array" == "[]" ]]; then
        echo "0"
        return 0
    fi

    local count
    count=$(echo "$json_array" | tr -cd ',' | wc -c)
    echo $((count + 1))
}

_count_total_source_files() {
    local merged_files_array=("$@")
    local total_source_files=0

    for merged_file in "${merged_files_array[@]}"; do
        local json_array="${SOURCE_FILE_MAPPING[$merged_file]:-[]}"
        local count
        count=$(_count_json_array_items "$json_array")
        total_source_files=$((total_source_files + count))
    done

    echo "$total_source_files"
}

_resolve_main_config() {
    local merged_files_array=("$@")
    local main_config="${merged_files_array[0]:-}"

    for file in "${merged_files_array[@]}"; do
        if [[ "$file" == *"${MERGED_FILE_PREFIX}${ENV_NAME}-"* ]]; then
            main_config="$file"
            break
        fi
    done

    echo "$main_config"
}

output_write_empty_summary() {
    local note="$1"

    _append_summary_table \
      "${ENV_NAME:-$NO_ENVIRONMENT_VALUE}" \
      "n/a" \
      "0" \
      "0" \
      "n/a" \
      "no-op"

    if [[ "${ENABLE_SUMMARY:-false}" == "true" && -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            echo "> ${note}"
            echo ""
        } >> "$GITHUB_STEP_SUMMARY"
    fi
}

# PRIVATE: Build JSON array from bash array
_build_json_array() {
    local -n array_ref=$1
    local json="["
    for i in "${!array_ref[@]}"; do
        if [[ $i -gt 0 ]]; then
            json+=","
        fi
        json+="\"${array_ref[$i]}\""
    done
    json+="]"
    echo "$json"
}

# PUBLIC: Track source files for a merged file
# Usage: output_track_merged_file "merged_file" "source_file1" "source_file2" ...
output_track_merged_file() {
    local merged_file="$1"
    shift
    local source_files=("$@")
    
    SOURCE_FILE_MAPPING["$merged_file"]=$(_build_json_array source_files)
}

# PUBLIC: Determine output file name based on environment and lifecycle
# Returns: output file path
# Usage: output_file=$(output_determine_filename "$source_dir" "$env_name")
output_determine_filename() {
    local source_dir="$1"
    local env_name="$2"
    
    # Always use environment name for output file (one file per environment)
    echo "$source_dir/${MERGED_FILE_PREFIX}${env_name}-infra.yaml"
}

# PUBLIC: Generate log message for lifecycle determination
# Returns: log message string
output_generate_log_message() {
    local env_name="$1"
    local lifecycle="$2"
    local best_dir="$3"
    
    if [[ -z "$best_dir" ]]; then
        echo "Using fallback configuration"
        return 0
    fi
    
    # Lifecycle subdirectory (production/env or development/env)
    if [[ "$best_dir" == *"/$lifecycle/$env_name" ]]; then
        echo "Using $lifecycle/$env_name/ + $lifecycle/ defaults (smart merge)"
        return 0
    fi
    
    # Exact match (explicit lifecycle name)
    if [[ "$best_dir" == *"/$env_name" ]] && [[ "$best_dir" != *"/$env_name/"* ]]; then
        echo "Using $env_name/ directory"
        return 0
    fi
    
    # Using lifecycle root directory as default
    echo "Using $lifecycle/ defaults"
}

# PUBLIC: Generate standardized outputs
output_generate() {
  local merged_files_array=("$@")
  
  # Determine mode: single environment or auto-detect
  local is_auto_detect=false
  if [[ -z "$ENV_NAME" || "$ENV_NAME" == "$NO_ENVIRONMENT_VALUE" ]]; then
    is_auto_detect=true
  fi
  
  # Single environment mode: set merged_config, empty merged_files
  # Auto-detect mode: empty merged_config, set merged_files array
  local main_config=""
  local merged_files_json="[]"
  
  if [[ "$is_auto_detect" == "true" ]]; then
    # Auto-detect mode: populate merged_files array, empty merged_config
    merged_files_json=$(_build_json_array merged_files_array)
    dbg "Auto-detect mode: merged_config=empty, merged_files=${#merged_files_array[@]} files"
  else
    # Single environment mode: set merged_config, empty merged_files
    main_config=$(_resolve_main_config "${merged_files_array[@]}")
    dbg "Single env mode: merged_config=$main_config, merged_files=empty"
  fi
  
  # Generate source files array
  local source_files_json="[]"
  if [[ -n "$main_config" && -n "${SOURCE_FILE_MAPPING[$main_config]}" ]]; then
    source_files_json="${SOURCE_FILE_MAPPING[$main_config]}"
  fi
  
  # Count total source files processed
  local total_source_files
  total_source_files=$(_count_total_source_files "${merged_files_array[@]}")
  
  # Generate outputs
  echo "environment=${ENV_NAME:-$NO_ENVIRONMENT_VALUE}" >> "$GITHUB_OUTPUT"
  echo "lifecycle=${LIFECYCLE:-}" >> "$GITHUB_OUTPUT"
  echo "files_count=$total_source_files" >> "$GITHUB_OUTPUT"
  echo "merged_config=$main_config" >> "$GITHUB_OUTPUT"
  echo "source_files=$source_files_json" >> "$GITHUB_OUTPUT"
  echo "merged_files=$merged_files_json" >> "$GITHUB_OUTPUT"
  
  dbg "GitHub Actions outputs generated successfully"
}

output_write_summary() {
  local merged_files_array=("$@")
  local merged_files_count="${#merged_files_array[@]}"
  local lifecycle_value="${LIFECYCLE:-n/a}"
  local merged_config_value="n/a"
  local status_value="merged"
  local total_source_files

  if [[ -n "$ENV_NAME" && "$ENV_NAME" != "$NO_ENVIRONMENT_VALUE" ]]; then
    merged_config_value=$(_resolve_main_config "${merged_files_array[@]}")
  else
    lifecycle_value="multiple"
  fi

  total_source_files=$(_count_total_source_files "${merged_files_array[@]}")

  _append_summary_table \
    "${ENV_NAME:-$NO_ENVIRONMENT_VALUE}" \
    "$lifecycle_value" \
    "$total_source_files" \
    "$merged_files_count" \
    "$merged_config_value" \
    "$status_value"

  if [[ "${ENABLE_SUMMARY:-false}" == "true" && -n "${GITHUB_STEP_SUMMARY:-}" && "$merged_files_count" -gt 0 ]]; then
    {
      echo "### Generated Files"
      echo ""
      for merged_file in "${merged_files_array[@]}"; do
        echo "- \`$(basename "$merged_file")\`"
      done
      echo ""
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

readonly OUTPUT_LIB_LOADED="true"
