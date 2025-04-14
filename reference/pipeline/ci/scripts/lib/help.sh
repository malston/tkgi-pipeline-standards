#!/usr/bin/env bash
#
# help.sh - Help functions for the fly.sh script
#

# Show general usage information
function show_usage() {
    local exit_code=${1:-0}
    cat <<EOF
Usage: fly.sh [options] [command] [pipeline_name]

Commands:
  set          Set pipeline (default)
  unpause      Set and unpause pipeline
  destroy      Destroy specified pipeline
  validate     Validate pipeline YAML without setting
  release      Create a release pipeline

Options:
  -h, --help           Show this help message
  --help-<command>     Show help for a specific command
  -f, --foundation     Specify foundation to deploy (required)
  -t, --target         Concourse target (default: foundation name)
  -b, --branch         Git branch to use (default: develop)
  -p, --pipeline       Pipeline name (default: main)
  -P, --params-repo    Path to params repo (default: ../../../../params)
  -d, --params-branch  Params git branch (default: master)
  -v, --verbose        Enable verbose output
  --dry-run            Show what would be done without making changes
  -e, --environment    Environment (lab, nonprod, prod)
  --version            Specify version for release pipeline
EOF
    exit ${exit_code}
}

# Show command-specific help
function show_command_help() {
    local command=$1
    local exit_code=${2:-0}

    case "${command}" in
    set)
        cat <<EOF
Usage: fly.sh [options] set [pipeline_name]

Set a pipeline in Concourse.

Required Options:
  -f, --foundation     Specify foundation to deploy

Additional Options:
  -t, --target         Concourse target (default: foundation name)
  -b, --branch         Git branch to use (default: develop)
  -p, --pipeline       Pipeline name (default: main)
  -P, --params-repo    Path to params repo
  -d, --params-branch  Params git branch (default: master)
  -v, --verbose        Enable verbose output
  --dry-run            Show what would be done without making changes

Examples:
  ./fly.sh -f cml-k8s-n-01 set
  ./fly.sh -f cml-k8s-n-01 -p custom set
  ./fly.sh -f cml-k8s-n-01 --params-branch feature-branch set
EOF
        ;;
    unpause)
        cat <<EOF
Usage: fly.sh [options] unpause [pipeline_name]

Set and unpause a pipeline in Concourse.

Required Options:
  -f, --foundation     Specify foundation to deploy

Additional Options:
  Same as the "set" command

Examples:
  ./fly.sh -f cml-k8s-n-01 unpause
  ./fly.sh -f cml-k8s-n-01 -p custom unpause
EOF
        ;;
    destroy)
        cat <<EOF
Usage: fly.sh [options] destroy [pipeline_name]

Destroy a pipeline in Concourse.

Required Options:
  -f, --foundation     Specify foundation to deploy
  -t, --target         Concourse target (if different from foundation)

Additional Options:
  -p, --pipeline       Pipeline name (default: main)
  --dry-run            Show what would be done without making changes

Examples:
  ./fly.sh -f cml-k8s-n-01 destroy
  ./fly.sh -f cml-k8s-n-01 -p custom destroy
EOF
        ;;
    validate)
        cat <<EOF
Usage: fly.sh [options] validate [pipeline_name]

Validate a pipeline YAML without setting it in Concourse.

Options:
  -f, --foundation     Specify foundation (for parameter interpolation)
  -p, --pipeline       Pipeline name (default: main)
  --dry-run            Always true for this command

Examples:
  ./fly.sh -f cml-k8s-n-01 validate
  ./fly.sh -f cml-k8s-n-01 -p custom validate
EOF
        ;;
    release)
        cat <<EOF
Usage: fly.sh [options] release

Create and set a release pipeline in Concourse.

Required Options:
  -f, --foundation     Specify foundation to deploy
  --version            Version for release (e.g., 1.2.3)

Additional Options:
  Same as the "set" command, plus:
  --version-file       File containing version (default: version)

Examples:
  ./fly.sh -f cml-k8s-n-01 --version 1.2.3 release
  ./fly.sh -f cml-k8s-n-01 --version-file custom-version release
EOF
        ;;
    *)
        error "Unknown command: ${command}"
        show_usage 1
        ;;
    esac

    exit ${exit_code}
}

# Process help flags, display help if requested
function check_help_flags() {
    local supported_commands=$1
    shift

    local args=("$@")
    local command=""

    # Process global help flag
    for arg in "${args[@]}"; do
        if [[ "${arg}" == "--help" || "${arg}" == "-h" ]]; then
            show_usage 0
        elif [[ "${arg}" =~ ^--help-(.+)$ ]]; then
            command="${BASH_REMATCH[1]}"
            if [[ "${command}" =~ ^(${supported_commands})$ ]]; then
                show_command_help "${command}" 0
            else
                error "Unknown command for help: ${command}"
                show_usage 1
            fi
        fi
    done
}
