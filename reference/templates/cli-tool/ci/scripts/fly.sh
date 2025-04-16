#!/usr/bin/env bash
#
# Script: fly.sh
# Description: Advanced pipeline management script for CLI tool deployments
#
# Usage: ./fly.sh [options] [command] [pipeline_name]
#
# Commands:
#   set          Set pipeline (default)
#   unpause      Set and unpause pipeline
#   destroy      Destroy specified pipeline
#   validate     Validate pipeline YAML without setting
#   release      Create a release pipeline
#   set-pipeline Create the set-pipeline pipeline
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CI_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
REPO_ROOT="$(cd "${CI_DIR}/.." &>/dev/null && pwd)"
REPO_NAME=$(basename "${REPO_ROOT}")
LIB_DIR="${SCRIPT_DIR}/lib"

# Test mode for automated testing (used in check_fly and other functions)
TEST_MODE=false

# Debug mode for additional logging
DEBUG=false

# Initialize default values
PIPELINE="main"
RELEASE_PIPELINE_NAME="release"
GITHUB_ORG="Utilities-tkgieng"
GIT_RELEASE_BRANCH="release"
CONFIG_GIT_BRANCH="master"
PARAMS_GIT_BRANCH="master"
VERSION_FILE=version
VERSION=""
CREATE_RELEASE=false
SET_RELEASE_PIPELINE=false
DRY_RUN=false
VERBOSE=false
ENVIRONMENT="lab"
TIMER_DURATION="3h"
COMMAND="set"
CONFIG_REPO_NAME="config-lab"

# Source module files
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/help.sh"
source "${LIB_DIR}/parsing.sh"
source "${LIB_DIR}/commands.sh"

# Source additional helper functions if available
if [[ -f "${SCRIPT_DIR}/helpers.sh" ]]; then
    source "${SCRIPT_DIR}/helpers.sh"
fi

# Define supported commands for this script
export SUPPORTED_COMMANDS="set|unpause|destroy|validate|release|set-pipeline"

# Function to get datacenter from foundation
function get_datacenter() {
    local foundation="$1"
    echo "$foundation" | cut -d'-' -f1
}

# Function to get datacenter type from foundation
function get_datacenter_type() {
    local foundation="$1"
    echo "$foundation" | cut -d'-' -f2
}

# Function to normalize version
function normalize_version() {
    local version="$1"

    # Remove 'v' prefix if present
    version="${version#v}"

    # Add 'v' prefix if not present
    if [[ ! "$version" =~ ^v ]]; then
        version="v$version"
    fi

    echo "$version"
}

# Function to determine foundation environment
function determine_foundation_environment() {
    local datacenter="$1"
    local environment="$2"
    local github_org="$3"
    local config_repo_name="$4"

    # Set environment based on datacenter if not explicitly provided
    if [[ -z "$environment" ]]; then
        case "$datacenter" in
        cml)
            environment="lab"
            ;;
        cmd)
            environment="nonprod"
            ;;
        cmp)
            environment="prod"
            ;;
        *)
            environment="lab" # default
            ;;
        esac
    fi

    # Set config repo name based on environment
    if [[ -z "$config_repo_name" ]]; then
        case "$environment" in
        lab)
            config_repo_name="config-lab"
            ;;
        nonprod)
            config_repo_name="config-nonprod"
            ;;
        prod)
            config_repo_name="config-prod"
            ;;
        esac
    fi

    echo "$environment:$github_org:$config_repo_name"
}

# Function to configure environment settings
function configure_environment() {
    local environment="$1"
    local branch="$2"
    local github_org="$3"
    local config_repo_name="$4"

    # Set branch based on environment if not provided
    if [[ -z "$branch" || "$branch" == "develop" ]]; then
        case "$environment" in
        lab)
            branch="develop"
            ;;
        nonprod)
            branch="release"
            ;;
        prod)
            branch="main"
            ;;
        esac
    fi

    echo "$branch:$github_org:$config_repo_name"
}

# Main execution flow
function main() {
    # Process help flags first
    check_help_flags "${SUPPORTED_COMMANDS}" "$@"

    # Simple argument processing with our new comprehensive function
    process_args "${SUPPORTED_COMMANDS}" "$@"

    # Handle legacy behavior
    if [[ "${CREATE_RELEASE}" == "true" ]]; then
        COMMAND="release"
    fi

    if [[ "${SET_RELEASE_PIPELINE}" == "true" ]]; then
        PIPELINE="${RELEASE_PIPELINE_NAME}"
    fi

    # Validate required parameters
    if [[ -z "${FOUNDATION}" ]]; then
        error "Foundation not specified. Use -f or --foundation option."
        show_usage 1
    fi

    # Set default target if not provided
    if [[ -z "${TARGET}" ]]; then
        TARGET="${FOUNDATION}"
    fi

    # Determine datacenter from foundation name
    DATACENTER=$(get_datacenter "${FOUNDATION}")

    # Determine datacenter type from foundation name
    DATACENTER_TYPE=$(get_datacenter_type "${FOUNDATION}")

    # Set foundation path
    FOUNDATION_PATH="foundations/$FOUNDATION"

    # Determine environment and config repo from foundation
    FOUNDATION_RESULT=$(determine_foundation_environment "$DATACENTER" "$ENVIRONMENT" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
    IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<<"$FOUNDATION_RESULT"

    # Configure environment specific settings
    ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$BRANCH" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
    IFS=':' read -r BRANCH GITHUB_ORG CONFIG_REPO_NAME <<<"$ENV_RESULT"

    # Set git URIs based on environment settings
    GIT_URI="git@github.com:$GITHUB_ORG/$REPO_NAME.git"
    CONFIG_GIT_URI="git@github.com:$GITHUB_ORG/$CONFIG_REPO_NAME.git"

    # Validate environment
    if [[ ! "${ENVIRONMENT}" =~ ^(lab|nonprod|prod)$ ]]; then
        error "Invalid environment: ${ENVIRONMENT}. Must be one of: lab, nonprod, prod"
        show_usage 1
    fi

    # Enable verbose output if requested
    if [[ "${VERBOSE}" == "true" ]]; then
        set -x
    fi

    # Execute the requested command with parameters instead of global variables
    case "${COMMAND}" in
    set)
        cmd_set_pipeline "${PIPELINE}" "${FOUNDATION}" "${REPO_NAME}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${BRANCH}" "${GIT_RELEASE_BRANCH}" "${VERSION_FILE}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}" "${FOUNDATION_PATH}" "${GIT_URI}" "${CONFIG_GIT_URI}" "${CONFIG_GIT_BRANCH}" "${PARAMS_GIT_BRANCH}"
        ;;
    unpause)
        cmd_unpause_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${BRANCH}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}" "${FOUNDATION_PATH}" "${GIT_URI}" "${CONFIG_GIT_URI}" "${CONFIG_GIT_BRANCH}" "${PARAMS_GIT_BRANCH}"
        ;;
    destroy)
        cmd_destroy_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${DRY_RUN}"
        ;;
    validate)
        cmd_validate_pipeline "${PIPELINE}" "${DRY_RUN}"
        ;;
    release)
        cmd_release_pipeline "${FOUNDATION}" "${REPO_NAME}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${BRANCH}" "${GIT_RELEASE_BRANCH}" "${VERSION_FILE}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}" "${FOUNDATION_PATH}" "${GIT_URI}" "${CONFIG_GIT_URI}" "${CONFIG_GIT_BRANCH}" "${PARAMS_GIT_BRANCH}"
        ;;
    set-pipeline)
        cmd_set_pipeline_pipeline "${FOUNDATION}" "${REPO_NAME}" "${TARGET}" "${BRANCH}" "${TIMER_DURATION}" "${DRY_RUN}" "${VERBOSE}" "${GIT_URI}"
        ;;
    *)
        error "Unknown command: ${COMMAND}"
        show_usage 1
        ;;
    esac
}

# Run the main function
main "$@"
