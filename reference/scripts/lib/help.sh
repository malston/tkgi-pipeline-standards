#!/usr/bin/env bash
#
# Help command module for fly.sh
# Contains functions related to displaying help messages
#

# Function to display command-specific usage
function show_command_usage() {
  local command="$1"

  case "$command" in
  command1)
    cat <<USAGE_COMMAND1
Usage: $0 [options] command1 [argument1] [argument2]

Describe what command 1 does.

Options:
  -a, --flag1 FLAG1    Flag1 option (required)
  -b, --flag2 FLAG2    Flag2 option [default: VALUE]
  --option1            Boolean option description

Example:
  $0 -f cml-k8s-n-01 command1 argument1
  $0 -f cml-k8s-n-01 command1 argument1 argument2 -a VALUE1 -b VALUE2 --option1
USAGE_COMMAND1
    ;;
  command2)
    cat <<USAGE_COMMAND2
Usage: $0 [options] command2 [argument1] [argument2]

Describe what command 2 does.

Options:
  -a, --flag1 FLAG1    Flag1 option (required)
  -b, --flag2 FLAG2    Flag2 option [default: VALUE]
  --option1            Boolean option description

Example:
  $0 -f cml-k8s-n-01 command2 argument1
  $0 -f cml-k8s-n-01 command2 argument1 argument2 -a VALUE1 -b VALUE2 --option1
USAGE_COMMAND2
    ;;
  command3)
    cat <<USAGE_COMMAND3
Usage: $0 [options] command3 [argument1] [argument2]

Describe what command 3 does.

Options:
  -a, --flag1 FLAG1    Flag1 option (required)
  -b, --flag2 FLAG2    Flag2 option [default: VALUE]
  --option1            Boolean option description

Example:
  $0 -f cml-k8s-n-01 command3 argument1
  $0 -f cml-k8s-n-01 command3 argument1 argument2 -a VALUE1 -b VALUE2 --option1
USAGE_COMMAND3
    ;;
  *)
    # If no specific command is given, show the general usage
    show_general_usage "${1:-1}"
    ;;
  esac
}

# Function to display general usage
function show_general_usage() {
  cat <<USAGE
Description: Enhanced script example that follows our standards

Usage: $0 [options] [command] [arguments...]

Commands:
  command1    First command description
  command2    Second command description
  command3    Third command description

Options:
  -f, --foundation NAME   Foundation name (required)
  -a, --flag1 VALUE       First flag description (required)
  -b, --flag2 VALUE       Second flag description [default: VALUE]
  --option1               Boolean option description
  -h, --help              Show this help message and exit

Examples:
  $0 -f FOUNDATION command1 -a VALUE --option1
  $0 -f FOUNDATION command2 -a VALUE --option1
  $0 -f FOUNDATION command3  argument1 -a VALUE1 -b VALUE2 --option1
  $0 -f FOUNDATION command3 -a VALUE1 -b VALUE2 --option1 argument1 argument2

For more detailed help on a specific command, use any of these formats:
  $0 --help [command]   Example: $0 --help command1
  $0 -h [command]       Example: $0 -h command2
  $0 [command] --help   Example: $0 command3 --help
USAGE
  exit "${1:-1}"
}

# Function to display usage (maintains backward compatibility)
function show_usage() {
  # Default to general usage
  show_general_usage "${1:-1}"
}
