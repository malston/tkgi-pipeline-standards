#!/usr/bin/env bash
#
# Script: help.sh
# Description: Help text and usage information for the fly.sh script
#

# Show script usage information
function show_usage() {
    local exit_code=${1:-0}

    cat <<EOF
Usage: $0 [options] [command] [pipeline_name]

Commands:
  set          Set pipeline (default)
  unpause      Set and unpause pipeline
  destroy      Destroy specified pipeline
  validate     Validate pipeline YAML without setting
  release      Create a release pipeline

Options:
  -h, --help                   Show this help message
  -f, --foundation FOUNDATION  Foundation to target (required)
  -t, --target TARGET          Concourse target (defaults to foundation name)
  -p, --pipeline PIPELINE      Pipeline name (default: main)
  -b, --branch BRANCH          Git branch to use (default: develop)
  -d, --params-branch BRANCH   Params repo branch (default: master)
  -r, --release                Set release pipeline
  -e, --environment ENV        Environment (lab, nonprod, prod)
  -v, --version VERSION        Version to use for release
  --verbose                    Enable verbose output
  -o, --org GITHUB_ORG         GitHub organization (default: Utilities-tkgieng)
  --dry-run                    Print commands without executing
EOF

    exit "$exit_code"
}

# Show command-specific help
function show_command_help() {
    local command=$1
    local exit_code=${2:-0}

    case "$command" in
    set)
        cat << EOF
Command: set - Set a pipeline

Usage: $0 set [options] [pipeline_name]

Options:
  -f, --foundation FOUNDATION  Foundation to target (required)
  -t, --target TARGET          Concourse target (defaults to foundation name)
  -b, --branch BRANCH          Git branch to use (default: develop)
  -d, --params-branch BRANCH   Params repo branch (default: master)
  -e, --environment ENV        Environment (lab, nonprod, prod)
  --dry-run                    Print commands without executing
  --verbose                    Enable verbose output
EOF
        ;;
    unpause)
        cat << EOF
Command: unpause - Set pipeline and unpause it

Usage: $0 unpause [options] [pipeline_name]

Options:
  -f, --foundation FOUNDATION  Foundation to target (required)
  -t, --target TARGET          Concourse target (defaults to foundation name)
  -b, --branch BRANCH          Git branch to use (default: develop)
  -d, --params-branch BRANCH   Params repo branch (default: master)
  -e, --environment ENV        Environment (lab, nonprod, prod)
  --dry-run                    Print commands without executing
  --verbose                    Enable verbose output
EOF
        ;;
    destroy)
        cat << EOF
Command: destroy - Destroy a pipeline

Usage: $0 destroy [options] [pipeline_name]

Options:
  -f, --foundation FOUNDATION  Foundation to target (required)
  -t, --target TARGET          Concourse target (defaults to foundation name)
  --dry-run                    Print commands without executing
EOF
        ;;
    validate)
        cat << EOF
Command: validate - Validate pipeline YAML without setting

Usage: $0 validate [options] [pipeline_name]

Options:
  --dry-run                    Print commands without executing
EOF
        ;;
    release)
        cat << EOF
Command: release - Create a release pipeline

Usage: $0 release [options]

Options:
  -f, --foundation FOUNDATION  Foundation to target (required)
  -t, --target TARGET          Concourse target (defaults to foundation name)
  -v, --version VERSION        Version to use for release
  -b, --branch BRANCH          Git branch to use (default: master)
  -d, --params-branch BRANCH   Params repo branch (default: master)
  -e, --environment ENV        Environment (lab, nonprod, prod)
  --verbose                    Enable verbose output
  --dry-run                    Print commands without executing
EOF
        ;;
    *)
        show_usage "$exit_code"
        ;;
    esac

    exit "$exit_code"
}

# Check if help flags were provided and show appropriate help
function check_help_flags() {
    local supported_commands=$1
    shift

    # Look at the first non-option argument (if any) to identify the command
    local command=""
    for arg in "$@"; do
        if [[ ! "$arg" =~ ^- ]]; then
            if [[ "$arg" =~ ^($supported_commands)$ ]]; then
                command="$arg"
                break
            fi
        fi
    done

    # Check for help flags
    for arg in "$@"; do
        case "$arg" in
        -h | --help | help)
            if [[ -n "$command" ]]; then
                show_command_help "$command" 0
            else
                show_usage 0
            fi
            ;;
        esac
    done
}
