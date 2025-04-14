#!/usr/bin/env bash
#
# Script: advanced-example.sh
# Description: Enhanced script example that follows our standards
#
# Usage: ./advanced-example.sh [options] [command] [arguments...]
#
# Commands:
#   command1    First command description
#   command2    Second command description
#   command3    Third command description
#
# Options:
#   -f, --foundation NAME   Foundation name (required)
#   -a, --flag1 VALUE       First flag description (required)
#   -b, --flag2 VALUE       Second flag description [default: VALUE]
#   --option1               Boolean option description
#   -h, --help              Show this help message and exit
#
# Examples:
#   ./advanced-example.sh -f cml-k8s-n-01 command1 -a VALUE --option1
#   ./advanced-example.sh -f cml-k8s-n-01 command2 -a VALUE --option1
#   ./advanced-example.sh -f cml-k8s-n-01 command3  argument1 -a VALUE1 -b VALUE2 --option1
#   ./advanced-example.sh -f cml-k8s-n-01 command3 -a VALUE1 -b VALUE2 --option1 argument1 argument2

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source module files
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/help.sh"
source "${LIB_DIR}/parsing.sh"
source "${LIB_DIR}/commands.sh"

# Default values
COMMAND="command1"
FOUNDATION=""

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Main execution flow
main() {
    # Process help flags first
    check_help_flags "command1|command2|command3" "$@"

    # Simple argument processing with our new comprehensive function
    process_args "command1|command2|command3" "$@"

    # Validate required parameters
    if [[ -z "${FOUNDATION}" ]]; then
        error "Foundation not specified. Use -f or --foundation option."
        show_usage 1
    fi

    # Validate required parameters
    if [[ -z "${FLAG1}" ]]; then
        error "Flag1 not specified. Use -a or --flag1 option."
        show_usage
        exit 1
    fi

    # Execute the requested command
    case "${COMMAND}" in
    command1)
        cmd_command1 "${FOUNDATION}" "${ARGUMENT1}" "${OPTION1}"
        ;;
    command2)
        cmd_command2 "${FOUNDATION}" "${ARGUMENT1}" "${OPTION1}"
        ;;
    command3)
        cmd_command3 "${FOUNDATION}" "${ARGUMENT1}" "${ARGUMENT2}" "${FLAG1}" "${FLAG2}" "${OPTION1}"
        ;;
    *)
        error "Unknown command: ${COMMAND}"
        show_usage
        exit 1
        ;;
    esac
}

# Run the main function
main "$@"
