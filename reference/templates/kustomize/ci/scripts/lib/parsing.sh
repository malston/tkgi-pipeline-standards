#!/usr/bin/env bash
#
# Argument parsing for fly.sh
# Contains functions for parsing and processing command line arguments
#

# Function to check for help flags
function check_help_flags() {
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
        if [[ "$next_arg" =~ ^(set|unpause|destroy|validate|release)$ ]]; then
          # Show help for specific command
          show_command_usage "$next_arg"
          exit 0
        fi
      fi
      # If we get here, no valid command was specified, show general help
      show_general_usage 0
    fi

    # Check for command followed by help flag format: command --help or command -h
    if [[ "${!i}" =~ ^(set|unpause|destroy|validate|release)$ ]]; then
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
function process_args() {
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

    # Target flag
    -t | --target)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      TARGET="$2"
      shift 2
      ;;
    --target=*)
      TARGET="${1#*=}"
      shift
      ;;

    # Environment flag
    -e | --environment)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      ENVIRONMENT="$2"
      shift 2
      ;;
    --environment=*)
      ENVIRONMENT="${1#*=}"
      shift
      ;;

    # Branch flag
    -b | --branch)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      BRANCH="$2"
      shift 2
      ;;
    --branch=*)
      BRANCH="${1#*=}"
      shift
      ;;

    # Config branch flag
    -c | --config-branch)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      CONFIG_GIT_BRANCH="$2"
      shift 2
      ;;
    --config-branch=*)
      CONFIG_GIT_BRANCH="${1#*=}"
      shift
      ;;

    # Params branch flag
    -d | --params-branch)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      PARAMS_GIT_BRANCH="$2"
      shift 2
      ;;
    --params-branch=*)
      PARAMS_GIT_BRANCH="${1#*=}"
      shift
      ;;

    # Pipeline flag
    -p | --pipeline)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      PIPELINE="$2"
      shift 2
      ;;
    --pipeline=*)
      PIPELINE="${1#*=}"
      shift
      ;;

    # GitHub org flag
    -o | --github-org)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      GITHUB_ORG="$2"
      shift 2
      ;;
    --github-org=*)
      GITHUB_ORG="${1#*=}"
      shift
      ;;

    # Version flag
    -v | --version)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      VERSION="$2"
      shift 2
      ;;
    --version=*)
      VERSION="${1#*=}"
      shift
      ;;

    # Timer flag
    --timer)
      if [[ -z "$2" || "$2" == -* ]]; then
        error "Option $1 requires an argument"
        show_usage 1
      fi
      TIMER_DURATION="$2"
      shift 2
      ;;
    --timer=*)
      TIMER_DURATION="${1#*=}"
      shift
      ;;

    # Boolean flags
    -r | --release)
      CREATE_RELEASE=true
      shift
      ;;
    -s | --set-release-pipeline)
      SET_RELEASE_PIPELINE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-validation-testing)
      ENABLE_VALIDATION_TESTING=true
      shift
      ;;
    --test-mode)
      TEST_MODE=true
      shift
      ;;
    --debug)
      DEBUG=true
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
      if [[ "$1" =~ ^(set|unpause|destroy|validate|release)$ ]]; then
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

  # If we have non-flag arguments, and no command is set yet,
  # assume the first one is a command and the second is a pipeline
  if [[ ${#non_flags[@]} -gt 0 && "$COMMAND" == "set" ]]; then
    COMMAND="${non_flags[0]}"
    if [[ ${#non_flags[@]} -gt 1 ]]; then
      PIPELINE="${non_flags[1]}"
    fi
  elif [[ ${#non_flags[@]} -gt 0 ]]; then
    # If we have non-flag arguments and command is already set,
    # assume the first one is the pipeline
    PIPELINE="${non_flags[0]}"
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
