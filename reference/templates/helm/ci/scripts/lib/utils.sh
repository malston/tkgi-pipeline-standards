#!/usr/bin/env bash
#
# utils.sh - Utility functions for the fly.sh script
#

# Display error message and exit with error code
function error() {
    echo -e "\033[0;31mERROR: $1\033[0m" >&2
}

# Display warning message
function warn() {
    echo -e "\033[0;33mWARN: $1\033[0m" >&2
}

# Display info message
function info() {
    echo -e "\033[0;36mINFO: $1\033[0m"
}

# Display success message
function success() {
    echo -e "\033[0;32mSUCCESS: $1\033[0m"
}

# Display debug message if debug is enabled
function debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo -e "\033[0;35mDEBUG: $1\033[0m" >&2
    fi
}

# Check if fly is installed and logged in
function check_fly() {
    if [[ "${TEST_MODE}" == "true" ]]; then
        debug "Skipping fly check in test mode"
        return 0
    fi

    if ! command -v fly &>/dev/null; then
        error "fly command not found. Please install it: https://concourse-ci.org/download.html"
        return 1
    fi

    if ! fly --version &>/dev/null; then
        error "Failed to run fly --version. It may be outdated or not properly installed."
        return 1
    fi

    return 0
}

# Check if a command exists
function command_exists() {
    command -v "$1" &>/dev/null
}

# Verify the existence of a file
function verify_file_exists() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        error "File not found: ${file}"
        return 1
    fi
    return 0
}

# Verify the existence of a directory
function verify_dir_exists() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        error "Directory not found: ${dir}"
        return 1
    fi
    return 0
}

# Get the absolute path for a file
function get_abs_path() {
    local path="$1"
    echo "$(cd "$(dirname "${path}")" && pwd)/$(basename "${path}")"
}

# Check if a value is in an array
function in_array() {
    local value="$1"
    shift
    local array=("$@")
    for item in "${array[@]}"; do
        if [[ "${item}" == "${value}" ]]; then
            return 0
        fi
    done
    return 1
}
