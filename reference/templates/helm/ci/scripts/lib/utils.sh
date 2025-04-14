#!/usr/bin/env bash
#
# Script: utils.sh
# Description: Utility functions for pipeline management
#

# Print an error message
function error() {
    echo "[ERROR] $*" >&2
}

# Print a warning message
function warn() {
    echo "[WARNING] $*" >&2
}

# Print an info message
function info() {
    echo "[INFO] $*"
}

# Print a debug message (only when DEBUG=true)
function debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo "[DEBUG] $*"
    fi
}

# Check if command exists
function command_exists() {
    command -v "$1" &>/dev/null
}

# Check if fly is installed and working
function check_fly() {
    if [[ "${TEST_MODE}" == "true" ]]; then
        return 0
    fi

    if ! command_exists fly; then
        error "fly command not found. Please install it first."
        return 1
    fi

    return 0
}

# Run a command with dry run support
function run_command() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would execute: $*"
        return 0
    fi

    "$@"
}

# Generic version comparison function
# Returns 0 if version1 >= version2, 1 otherwise
function compare_versions() {
    local version1="$1"
    local version2="$2"

    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi

    local IFS=.
    local i ver1=($version1) ver2=($version2)

    # Fill empty fields with zeros
    for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
        ver1[i]=0
    done

    for ((i = 0; i < ${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi

        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi

        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done

    return 0
}
