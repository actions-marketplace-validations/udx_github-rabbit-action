#!/usr/bin/env bash
# Logging utilities for GitHub Actions

# Guard against multiple sourcing
if [[ "${LOGGING_LIB_LOADED:-}" == "true" ]]; then
    return 0
fi

# Logging Strategy:
# - log()  : User-facing progress/success messages (ONLY in index.sh orchestrator)
# - dbg()  : Internal technical details (all modules, only shown with DEBUG=true)
# - err()  : Fatal errors from specific operations (modules for domain errors, index.sh for orchestration errors)
# - warn() : Non-fatal issues and fallback scenarios (modules for domain warnings, index.sh for orchestration warnings)
#
# Separation of Concerns:
# - index.sh: Orchestrates flow, provides user-facing progress updates via log()
# - Modules: Handle specific domains, use dbg() for internals, err()/warn() for domain-specific issues

annotations_enabled() {
    [[ "${ENABLE_ANNOTATIONS:-false}" == "true" ]]
}

# Log a notice message (user-facing)
log() {
    if annotations_enabled; then
        echo "::notice::$*"
    else
        echo "$*"
    fi
}

# Log a debug message (internal details, only shown if DEBUG=true)
dbg() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "::dbg::$*"
    fi
}

# Log an error message (fatal issues)
err() {
    echo "::error::$*"
}

# Log a warning message (non-fatal issues)
warn() {
    if annotations_enabled; then
        echo "::warning::$*"
    else
        echo "warning: $*"
    fi
}

readonly LOGGING_LIB_LOADED="true"
