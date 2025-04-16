#!/usr/bin/env bash

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
#
# parsing.sh - Argument parsing functions for the fly.sh script
#

# Process command line arguments
function process_args() {
    local supported_commands=$1
    shift
    local args=("$@")

    # Variables for parsing
    local positional_args=()
    local i=0

    # Loop through all arguments
    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"

        # Handle options with values
        if [[ "${arg}" == "-f" || "${arg}" == "--foundation" ]]; then
            ((i++))
            FOUNDATION="${args[$i]}"
        elif [[ "${arg}" == "-t" || "${arg}" == "--target" ]]; then
            ((i++))
            TARGET="${args[$i]}"
        elif [[ "${arg}" == "-b" || "${arg}" == "--branch" ]]; then
            ((i++))
            BRANCH="${args[$i]}"
        elif [[ "${arg}" == "-p" || "${arg}" == "--pipeline" ]]; then
            ((i++))
            PIPELINE="${args[$i]}"
        elif [[ "${arg}" == "-P" || "${arg}" == "--params-repo" ]]; then
            ((i++))
            PARAMS_REPO="${args[$i]}"
        elif [[ "${arg}" == "-d" || "${arg}" == "--params-branch" ]]; then
            ((i++))
            PARAMS_GIT_BRANCH="${args[$i]}"
        elif [[ "${arg}" == "-e" || "${arg}" == "--environment" ]]; then
            ((i++))
            ENVIRONMENT="${args[$i]}"
        elif [[ "${arg}" == "-v" || "${arg}" == "--version" ]]; then
            ((i++))
            VERSION="${args[$i]}"
        elif [[ "${arg}" == "--version-file" ]]; then
            ((i++))
            VERSION_FILE="${args[$i]}"
        elif [[ "${arg}" == "--timer-duration" ]]; then
            ((i++))
            TIMER_DURATION="${args[$i]}"

        # Handle boolean flags
        elif [[ "${arg}" == "--verbose" ]]; then
            VERBOSE="true"
        elif [[ "${arg}" == "--debug" ]]; then
            DEBUG="true"
        elif [[ "${arg}" == "--dry-run" ]]; then
            DRY_RUN="true"

        # Handle positional arguments (commands and pipeline names)
        elif [[ "${arg}" =~ ^(${supported_commands})$ ]]; then
            COMMAND="${arg}"
        elif [[ -z "${COMMAND}" ]]; then
            # If no explicit command and this is the first positional arg, assume it's a command
            if [[ "${arg}" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ${#positional_args[@]} -eq 0 ]]; then
                # Check if it looks like a valid command name
                if [[ "${arg}" =~ ^(${supported_commands})$ ]]; then
                    COMMAND="${arg}"
                else
                    # Otherwise it might be a pipeline name
                    positional_args+=("${arg}")
                fi
            else
                positional_args+=("${arg}")
            fi
        else
            # If we already have a command, this must be a pipeline name
            positional_args+=("${arg}")
        fi

        ((i++))
    done

    # Process positional arguments if any
    if [[ ${#positional_args[@]} -gt 0 ]]; then
        # If first positional arg isn't a command but we don't have a command yet, it might be a pipeline name
        if [[ -z "${COMMAND}" && ! "${positional_args[0]}" =~ ^(${supported_commands})$ ]]; then
            PIPELINE="${positional_args[0]}"
        # If first positional arg after the command, treat it as pipeline name
        elif [[ -n "${COMMAND}" && ${#positional_args[@]} -gt 0 ]]; then
            PIPELINE="${positional_args[0]}"
        fi
    fi

    # Set default command if not specified
    if [[ -z "${COMMAND}" ]]; then
        COMMAND="set"
    fi

    debug "Parsed args: COMMAND=${COMMAND}, PIPELINE=${PIPELINE}, FOUNDATION=${FOUNDATION}"
}

# Extract datacenter from foundation name
function get_datacenter() {
    local foundation="$1"
    echo "${foundation}" | cut -d"-" -f1
}

# Extract datacenter type from foundation name
function get_datacenter_type() {
    local foundation="$1"
    echo "${foundation}" | cut -d"-" -f2
}

# Normalize version string (ensure format x.y.z)
function normalize_version() {
    local version="$1"
    # Remove 'v' prefix if present
    version="${version#v}"
    # Ensure at least major.minor.patch format
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        if [[ "${version}" =~ ^[0-9]+\.[0-9]+$ ]]; then
            # If major.minor, add .0 for patch
            version="${version}.0"
        elif [[ "${version}" =~ ^[0-9]+$ ]]; then
            # If only major, add .0.0 for minor and patch
            version="${version}.0.0"
        fi
    fi
    echo "${version}"
}
