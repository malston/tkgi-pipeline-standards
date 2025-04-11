#!/usr/bin/env bash
#
# Script: example.sh
# Description: Enhanced script template that follows our standards
#
# Usage: ./example.sh [options] [command] [argument]
#
# Commands:
#   command1    First command description
#   command2    Second command description
#   command3    Third command description
#
# Options:
#   -f, --flag1 VALUE    First flag description (required)
#   -o, --flag2 VALUE    Second flag description
#   --option1            Boolean option description
#   --dry-run            Simulate without making changes
#   --verbose            Increase output verbosity
#   -h, --help           Show this help message
#
# Examples:
#   ./example.sh command1 -f VALUE --option1
#   ./example.sh command2 -f VALUE --verbose
#   ./example.sh command3 -o VALUE1 -f VALUE2 --option1 --dry-run

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions if available
if [[ -f "${__DIR}/helpers.sh" ]]; then
    source "${__DIR}/helpers.sh"
fi

# Default values
COMMAND="command1"
DRY_RUN=false
VERBOSE=false

# Function to display usage
function show_usage() {
    cat <<USAGE
Script: example.sh
Description: Enhanced script template that follows our standards

Usage: $0 [options] [command] [argument]

Commands:
  command1    First command description
  command2    Second command description
  command3    Third command description

Options:
  -f, --flag1 VALUE    First flag description (required)
  -o, --flag2 VALUE    Second flag description
  --option1            Boolean option description
  --dry-run            Simulate without making changes
  --verbose            Increase output verbosity
  -h, --help           Show this help message

Examples:
  $0 -f VALUE command1 -o ARGUMENT --dry-run
  $0 -f VALUE --verbose command2
  $0 -o VALUE1 -f VALUE2 command3 --option1 --dry-run
USAGE
}

# Function to log info messages
function info() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[INFO] [${timestamp}] $1"
}

# Function to log error messages
function error() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[ERROR] [${timestamp}] $1" >&2
}

# Function to log success messages
function success() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[SUCCESS] [${timestamp}] $1"
}

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Global options
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
    case $1 in
    -f | --flag1)
        shift
        FLAG1=$1
        ;;
    --dry-run)
        DRY_RUN=true
        ;;
    --verbose)
        VERBOSE=true
        ;;
    -h | --help)
        show_usage
        exit 0
        ;;
    esac
    shift
done
if [[ "$1" == '--' ]]; then shift; fi

# Check for additional arguments (command and argument)
if [[ $# -gt 0 ]]; then
    if [[ "$1" =~ ^(command1|command2|command3)$ ]]; then
        COMMAND="$1"
        shift
    fi

    # Command options
    while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
        case $1 in
        -o | --flag2)
            shift
            ARGUMENT=$1
            ;;
        --option1)
            OPTION1=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        esac
        shift
    done
    if [[ "$1" == '--' ]]; then shift; fi
fi

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
    set -x
fi

# Validate required parameters
if [[ -z "${FLAG1}" ]]; then
    error "Flag1 not specified. Use -f or --flag1 option."
    show_usage
    exit 1
fi

# Implementation of command1
function cmd_command1() {
    info "Executing command1 with flag1='${FLAG1}' and argument='${ARGUMENT}' and option1='$OPTION1'"

    if [[ "${DRY_RUN}" == "true" ]]; then
        info "DRY RUN: Would execute command1 here"
    else
        # Actual command implementation
        success "Command1 executed successfully"
    fi
}

# Implementation of command2
function cmd_command2() {
    info "Executing command2 with flag1='${FLAG1}'"

    if [[ "${DRY_RUN}" == "true" ]]; then
        info "DRY RUN: Would execute command2 here"
    else
        # Actual command implementation
        success "Command2 executed successfully"
    fi
}

# Implementation of command3
function cmd_command3() {
    info "Executing command3 with flag1='${FLAG1}'"

    if [[ "${DRY_RUN}" == "true" ]]; then
        info "DRY RUN: Would execute command3 here"
    else
        # Actual command implementation
        success "Command3 executed successfully"
    fi
}

# Execute the requested command
case "${COMMAND}" in
command1)
    cmd_command1
    ;;
command2)
    cmd_command2
    ;;
command3)
    cmd_command3
    ;;
*)
    error "Unknown command: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
