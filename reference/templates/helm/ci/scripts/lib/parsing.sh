#!/usr/bin/env bash
#
# Script: parsing.sh
# Description: Command-line argument parsing functions for the fly.sh script
#

# Process command line arguments
function process_args() {
    local supported_commands=$1
    shift

    # Look for a command first (non-option argument)
    for arg in "$@"; do
        if [[ ! "$arg" =~ ^- ]]; then
            if [[ "$arg" =~ ^($supported_commands)$ ]]; then
                COMMAND="$arg"
                break
            fi
        fi
    done

    # Process all arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        # Commands - only process if not already set
        set | unpause | destroy | validate | release)
            if [[ "$1" =~ ^($supported_commands)$ ]]; then
                COMMAND="$1"
            fi
            shift
            ;;

        # Short options
        -h | --help)
            # Handled by check_help_flags
            shift
            ;;
        -f | --foundation)
            FOUNDATION="$2"
            shift 2
            ;;
        -t | --target)
            TARGET="$2"
            shift 2
            ;;
        -p | --pipeline)
            PIPELINE="$2"
            shift 2
            ;;
        -b | --branch)
            BRANCH="$2"
            shift 2
            ;;
        -d | --params-branch)
            PARAMS_GIT_BRANCH="$2"
            shift 2
            ;;
        -e | --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v | --version)
            VERSION="$2"
            shift 2
            ;;
        -o | --org)
            GITHUB_ORG="$2"
            shift 2
            ;;
        -r | --release)
            SET_RELEASE_PIPELINE=true
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --testing)
            ENABLE_VALIDATION_TESTING=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --create-release)
            CREATE_RELEASE=true
            shift
            ;;
        --timer-duration)
            TIMER_DURATION="$2"
            shift 2
            ;;
        # Stop parsing after '--'
        --)
            shift
            break
            ;;
        # Handle unknown options
        -*)
            error "Unknown option: $1"
            show_usage 1
            ;;
        # Handle non-option arguments (pipeline name as the last argument)
        *)
            # If this doesn't match a known command and appears to be a pipeline name
            if [[ ! "$1" =~ ^($supported_commands)$ ]] && [[ -n "$1" ]]; then
                # Only set if not already explicitly set by -p option
                if [[ "$PIPELINE" == "main" ]] || [[ "$PIPELINE" == "$RELEASE_PIPELINE_NAME" ]]; then
                    PIPELINE="$1"
                fi
            fi
            shift
            ;;
        esac
    done

    # Special handling for testing mode
    if [[ "${ENABLE_VALIDATION_TESTING}" == "true" ]]; then
        TEST_MODE=true
    fi
}
