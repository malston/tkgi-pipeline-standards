#!/usr/bin/env bash
#
# Argument parsing for fly.sh
# Contains functions for parsing and processing command line arguments
#
# To use this module effectively, pass the command pattern as the first argument
# to check_help_flags and process_args functions. For example:
#
# ```bash
# # Define supported commands for this script
# SUPPORTED_COMMANDS="set|unpause|destroy|validate|release|custom1|custom2"
#
# # Call the parsing functions with the command pattern
# check_help_flags "${SUPPORTED_COMMANDS}" "$@"
# process_args "${SUPPORTED_COMMANDS}" "$@"
# ```
#
# If no command pattern is provided, a default value of "set|unpause|destroy|validate|release"
# will be used.
#

# Function to check for help flags
# @param cmd_pattern A regex pattern of supported commands (e.g., "set|unpause|destroy")
# @param ... The rest of the arguments passed to the script
function check_help_flags() {
  # First argument is the command pattern
  local cmd_pattern="${1:-set|unpause|destroy|validate|release}"
  shift

  # Check for help flag first and handle both formats:
  # 1. --help command
  # 2. -h command
  # 3. command -h
  # 4. command --help
  for ((i = 1; i <= $#; i++)); do
    # Check for help flag format: --help command or -h command
    if [[ "${!i}" == "-h" || "${!i}" == "--help" ]]; then
      # Check if the next argument exists and is a command
      next_idx=$((i + 1))
      if [[ $next_idx -le $# ]]; then
        next_arg="${!next_idx}"
        if [[ "$next_arg" =~ ^(${cmd_pattern})$ ]]; then
          # Show help for specific command
          show_command_usage "$next_arg"
          exit 0
        fi
      fi
      # If we get here, no valid command was specified, show general help
      show_general_usage 0
    fi

    # Check for command followed by help flag format: command --help or command -h
    if [[ "${!i}" =~ ^(${cmd_pattern})$ ]]; then
      # Check if the next argument is a help flag
      next_idx=$((i + 1))
      if [[ $next_idx -le $# ]]; then
        next_arg="${!next_idx}"
        if [[ "$next_arg" == "-h" || "$next_arg" == "--help" ]]; then
          # Show help for specific command
          show_command_usage "${!i}"
          exit 0
        fi
      fi
    fi
  done
}

# Comprehensive function to process all command line arguments
# @param cmd_pattern A regex pattern of supported commands (e.g., "set|unpause|destroy")
# @param ... The rest of the arguments passed to the script
function process_args() {
  # First argument is the command pattern
  local cmd_pattern="${1:-set|unpause|destroy|validate|release}"
  shift

  # Array to hold the non-flag arguments
  local non_flags=()

  # Process flags until we run out of arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    # Help flags
    -h | --help)
      show_general_usage 0
      ;;

    # Foundation flag (required)
    -f | --foundation)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      FOUNDATION="$2"
      shift 2
      ;;
    --foundation=*)
      FOUNDATION="${1#*=}"
      shift
      ;;

    # flag1 flag (required)
    -a | --flag1)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      FLAG1="$2"
      shift 2
      ;;
    --flag1=*)
      FLAG1="${1#*=}"
      shift
      ;;

    # flag2 flag
    -b | --flag2)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      FLAG2="$2"
      shift 2
      ;;
    --flag2=*)
      FLAG2="${1#*=}"
      shift
      ;;

    # Boolean flags
    --option1)
      OPTION1=true
      shift
      ;;

    # End of options marker
    --)
      shift
      non_flags+=("$@")
      break
      ;;

    # Commands and non-flag arguments
    *)
      if [[ "$1" =~ ^(${cmd_pattern})$ ]]; then
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

  # Use the cmd_pattern passed as parameter (already handled in function signature)

  # If we have non-flag arguments, and no command is set yet,
  # assume the first one is a command and the second is a argument1

  if [[ ${#non_flags[@]} -gt 0 && "$COMMAND" == "command1" ]]; then
    if [[ "${non_flags[0]}" =~ ^(${cmd_pattern})$ ]]; then
      COMMAND="${non_flags[0]}"
      if [[ ${#non_flags[@]} -gt 1 ]]; then
        ARGUMENT1="${non_flags[1]}"
        ARGUMENT2="${non_flags[1]}"
      fi
    else
      # If the first non-flag arg isn't a valid command, treat it as argument1
      ARGUMENT1="${non_flags[0]}"
      ARGUMENT2="${non_flags[1]}"
    fi
  elif [[ ${#non_flags[@]} -gt 0 ]]; then
    # If we have non-flag arguments and command is already set,
    # assume the first one is the argument1
    ARGUMENT1="${non_flags[0]}"
    ARGUMENT2="${non_flags[1]}"
  fi
}

# Function to validate required parameters and set defaults
# Takes variable references to allow explicit modification of globals
# @param foundation_ref Reference to FOUNDATION variable
# @param target_ref Reference to TARGET variable
# @param environment_ref Reference to ENVIRONMENT variable
# @param branch_ref Reference to BRANCH variable
function validate_and_set_defaults() {
  # Get references to variables
  local -n _foundation="$1"
  local -n _target="$2"
  local -n _environment="$3"
  local -n _branch="$4"

  # Validate required parameters
  if [[ -z "${_foundation}" ]]; then
    error "Foundation not specified. Use -f or --foundation option."
    show_usage 1
  fi

  # Set default target if not provided
  if [[ -z "${_target}" ]]; then
    _target="${_foundation}"
  fi

  # Set default environment if not provided
  if [[ -z "${_environment}" ]]; then
    _environment=$(get_environment "${_foundation}")
  fi

  # Set default branch based on environment if not provided
  if [[ -z "${_branch}" ]]; then
    if [[ "${_environment}" == "lab" ]]; then
      _branch="develop"
    else
      _branch="main"
    fi
  fi

  # Validate environment
  if [[ ! "${_environment}" =~ ^(lab|nonprod|prod)$ ]]; then
    error "Invalid environment: ${_environment}. Must be one of: lab, nonprod, prod"
    show_usage 1
  fi
}
