#!/usr/bin/env bash
#
# Script: example.sh
# Description: Example script that follows our standards
#
# Usage: ./example.sh [options] [command] [arguments...]
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
#   -h, --help           Show this help message
#
# Examples:
#   ./example.sh command1 -f VALUE --option1
#   ./example.sh command2 -f VALUE
#   ./example.sh command3 -o VALUE1 -f VALUE2 --option1
#   ./example.sh -f VALUE1 --option1 command1 -o VALUE2

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions if available
if [[ -f "${__DIR}/helpers.sh" ]]; then
    source "${__DIR}/helpers.sh"
fi

# Default values
COMMAND="command1"
OPTION1=false

# Function to display usage
function show_usage() {
    cat <<USAGE
Script: example.sh
Description: Example script that follows our standards

Usage: $0 [options] [command] [argument]

Commands:
  command1    First command description
  command2    Second command description
  command3    Third command description

Options:
  -f, --flag1 VALUE    First flag description (required)
  -o, --flag2 VALUE    Second flag description
  --option1            Boolean option description
  -h, --help           Show this help message

Examples:
  $0 command1 -f VALUE --option1
  $0 command2 -f VALUE
  $0 command3 -o VALUE1 -f VALUE2 --option1
  $0 -f VALUE1 --option1 command1 -o VALUE2
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
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_usage
        exit 0
        ;;
    -f | --flag1)
        if [[ -z "$2" || "$2" == -* ]]; then
            error "Option $1 requires an argument"
            show_usage 1
        fi
        FLAG1="$2"
        shift 2
        ;;
    -o | --flag2)
        FLAG2="$2"
        shift 2
        ;;
    --option1)
        OPTION1=true
        shift
        ;;
    --)
        shift
        non_flags+=("$@")
        break
        ;;
    # Commands and non-flag arguments
    *)
        if [[ "$1" =~ ^(command1|command2|command3)$ ]]; then
            COMMAND="$1"
        elif [[ ! "$1" =~ ^- ]]; then
            # Assume this is a pipeline name
            non_flags+=("$1")
        else
            error "Unknown option: $1"
            show_usage 1
        fi
        shift
        ;;
    esac
done

# Implementation of command1
function cmd_command1() {
    local flag1=$1
    local flag2=$2
    local option="${3:-false}"

    info "Executing command1 with flag1='${flag1}' and flag2='${flag2}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "Would execute option1 here"
    fi
    # Actual command implementation
    success "Command1 executed successfully"
}

# Implementation of command2
function cmd_command2() {
    local flag1=$1
    local flag2=$2
    local option="${3:-false}"

    info "Executing command2 with flag1='${flag1}' and flag2='${flag2}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "Would execute option1 here"
    fi
    # Actual command implementation
    success "Command2 executed successfully"
}

# Implementation of command3
function cmd_command3() {
    local flag1=$1
    local flag2=$2
    local option="${3:-false}"

    info "Executing command3 with flag1='${flag1}' and flag2='${flag2}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "Would execute option1 here"
    fi
    # Actual command implementation
    success "Command3 executed successfully"
}

# Execute the requested command
case "${COMMAND}" in
command1)
    cmd_command1 "${FLAG1}" "${FLAG2}" "${OPTION1}"
    ;;
command2)
    cmd_command2 "${FLAG1}" "${FLAG2}" "${OPTION1}"
    ;;
command3)
    cmd_command3 "${FLAG1}" "${FLAG2}" "${OPTION1}"
    ;;
*)
    error "Unknown command: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
