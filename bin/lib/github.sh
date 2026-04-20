#!/usr/bin/env bash
# GitHub API interaction utilities

# Guard against multiple sourcing
if [[ "${GITHUB_LIB_LOADED:-}" == "true" ]]; then
    return 0
fi

# Source dependencies
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/logging.sh"

# Constants
readonly GITHUB_API_BASE="https://api.github.com"
readonly GITHUB_API_VERSION="2022-11-28"

# Simple protection check - no need for approval counting

# PRIVATE: Make a GitHub API request
# Usage: _github_api_request "GET" "/repos/owner/repo/branches/main" "github_token"
# Returns: response body (stdout) and http code (via return value check)
_github_api_request() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X "$method" \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
    "${GITHUB_API_BASE}${endpoint}" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Output body to stdout
    echo "$body"
    
    # Return 0 for 2xx status codes, 1 otherwise
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# PRIVATE: Get branch info to check protection status
# Usage: _get_branch_info "owner/repo" "branch-name" "token"
# Returns: 0 if successful, 1 otherwise
_get_branch_info() {
    local repository="$1"
    local branch="$2"
    local token="$3"
    
    dbg "Fetching branch info for '$branch' in '$repository'" >&2
    
    local response
    response=$(_github_api_request "GET" "/repos/${repository}/branches/${branch}" "$token")
    local status=$?
    
    if [[ $status -eq 0 ]]; then
        echo "$response"
        return 0
    fi
    
    return 1
}

# PUBLIC: Check if branch is protected via GitHub API
# Returns: 0 if protected, 1 if not protected
# Usage: github_check_branch_protection "branch-name" ["repository"] ["token"]
#   - branch: Branch name to check (required)
#   - repository: GitHub repository (optional, defaults to GITHUB_REPOSITORY env)
#   - token: GitHub token (optional, defaults to GITHUB_TOKEN env)
github_check_branch_protection() {
    local branch="$1"
    local repository="${2:-${GITHUB_REPOSITORY:-}}"
    local token="${3:-${GITHUB_TOKEN:-}}"
    
    # Skip if missing required parameters
    if [[ -z "$branch" ]] || [[ -z "$token" ]] || [[ -z "$repository" ]]; then
        dbg "Skipping branch protection check - missing parameters" >&2
        return 1
    fi
    
    dbg "Checking branch protection for '$branch' in '$repository'" >&2
    
    # Get branch info and check protected field
    local branch_info
    if branch_info=$(_get_branch_info "$repository" "$branch" "$token"); then
        if echo "$branch_info" | grep -q '"protected": *true'; then
            dbg "Branch '$branch' is protected" >&2
            return 0
        fi
    fi
    
    dbg "Branch '$branch' is not protected" >&2
    return 1
}

readonly GITHUB_LIB_LOADED="true"
