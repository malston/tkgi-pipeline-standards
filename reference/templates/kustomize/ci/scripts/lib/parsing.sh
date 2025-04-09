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

# Function to preprocess arguments
function preprocess_args() {
  local -n processed_args_var=$1
  local -n orig_args=$2

  # Process long-form arguments with values in format --option=value
  for arg in "${orig_args[@]}"; do
    # Convert --option=value style to --option value for getopts
    if [[ "$arg" == "--foundation="* ]]; then
      FOUNDATION="${arg#*=}"
      continue
    elif [[ "$arg" == "--target="* ]]; then
      TARGET="${arg#*=}"
      continue
    elif [[ "$arg" == "--environment="* ]]; then
      ENVIRONMENT="${arg#*=}"
      continue
    elif [[ "$arg" == "--branch="* ]]; then
      BRANCH="${arg#*=}"
      continue
    elif [[ "$arg" == "--config-branch="* ]]; then
      CONFIG_GIT_BRANCH="${arg#*=}"
      continue
    elif [[ "$arg" == "--params-branch="* ]]; then
      PARAMS_GIT_BRANCH="${arg#*=}"
      continue
    elif [[ "$arg" == "--pipeline="* ]]; then
      PIPELINE="${arg#*=}"
      continue
    elif [[ "$arg" == "--github-org="* ]]; then
      GITHUB_ORG="${arg#*=}"
      continue
    elif [[ "$arg" == "--version="* ]]; then
      VERSION="${arg#*=}"
      continue
    elif [[ "$arg" == "--timer="* ]]; then
      TIMER_DURATION="${arg#*=}"
      continue
    elif [[ "$arg" == "--release" ]]; then
      CREATE_RELEASE=true
      continue
    elif [[ "$arg" == "--set-release-pipeline" ]]; then
      SET_RELEASE_PIPELINE=true
      continue
    elif [[ "$arg" == "--dry-run" ]]; then
      DRY_RUN=true
      continue
    elif [[ "$arg" == "--verbose" ]]; then
      VERBOSE=true
      continue
    elif [[ "$arg" == "--enable-validation-testing" ]]; then
      ENABLE_VALIDATION_TESTING=true
      continue
    elif [[ "$arg" == "--test-mode" ]]; then
      TEST_MODE=true
      continue
    fi
    
    # Pass through all other arguments
    processed_args_var+=("$arg")
  done
}

# Function to process short form args that weren't handled during preprocessing
function process_short_args() {
  # Process the passed arguments directly
  
  # Process short-form arguments and their values
  local i=1
  while [[ $i -le $# ]]; do
    local current="${!i}"
    
    case "$current" in
      -h)
        # Standalone -h with no command specified
        next_idx=$((i+1))
        if [[ $next_idx -le $# ]]; then
          next_arg="${!next_idx}"
          if [[ "$next_arg" =~ ^(set|unpause|destroy|validate|release)$ ]]; then
            # Already handled by the help flag checker above
            i=$((i+2))
            continue
          fi
        fi
        show_general_usage 0
        ;;
      -f)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          FOUNDATION="${!next}"
          i=$((i+2))
        else
          error "Option -f requires an argument"
          show_usage 1
        fi
        ;;
      -t)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          TARGET="${!next}"
          i=$((i+2))
        else
          error "Option -t requires an argument"
          show_usage 1
        fi
        ;;
      -e)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          ENVIRONMENT="${!next}"
          i=$((i+2))
        else
          error "Option -e requires an argument"
          show_usage 1
        fi
        ;;
      -b)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          BRANCH="${!next}"
          i=$((i+2))
        else
          error "Option -b requires an argument"
          show_usage 1
        fi
        ;;
      -c)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          CONFIG_GIT_BRANCH="${!next}"
          i=$((i+2))
        else
          error "Option -c requires an argument"
          show_usage 1
        fi
        ;;
      -d)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          PARAMS_GIT_BRANCH="${!next}"
          i=$((i+2))
        else
          error "Option -d requires an argument"
          show_usage 1
        fi
        ;;
      -p)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          PIPELINE="${!next}"
          i=$((i+2))
        else
          error "Option -p requires an argument"
          show_usage 1
        fi
        ;;
      -o)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          GITHUB_ORG="${!next}"
          i=$((i+2))
        else
          error "Option -o requires an argument"
          show_usage 1
        fi
        ;;
      -v)
        next=$((i+1))
        if [[ $next -le $# ]]; then
          VERSION="${!next}"
          i=$((i+2))
        else
          error "Option -v requires an argument"
          show_usage 1
        fi
        ;;
      -r)
        CREATE_RELEASE=true
        i=$((i+1))
        ;;
      -s)
        SET_RELEASE_PIPELINE=true
        i=$((i+1))
        ;;
      -*)
        # Handle other short options not already processed
        i=$((i+1))
        ;;
      *)
        # This might be a command or pipeline name, will be handled below
        i=$((i+1))
        ;;
    esac
  done
}

# Function to detect command and pipeline arguments
# Takes variable references to allow explicit modification of globals
# @param command_ref Reference to COMMAND variable
# @param pipeline_ref Reference to PIPELINE variable
# @param dry_run_ref Reference to DRY_RUN variable
# @param verbose_ref Reference to VERBOSE variable
# @param validation_ref Reference to ENABLE_VALIDATION_TESTING variable
# @param test_mode_ref Reference to TEST_MODE variable
# @param create_release_ref Reference to CREATE_RELEASE variable
# @param set_pipeline_ref Reference to SET_RELEASE_PIPELINE variable
# @param args The command line arguments to process
function detect_command_and_pipeline() {
  # Get references to variables
  local -n _command="$1"
  local -n _pipeline="$2"
  local -n _dry_run="$3"
  local -n _verbose="$4"
  local -n _validation="$5"
  local -n _test_mode="$6"
  local -n _create_release="$7"
  local -n _set_pipeline="$8"
  
  # Shift to get to the original arguments
  shift 8
  
  # Check for command and pipeline arguments
  if [[ $# -gt 0 ]]; then
    if [[ "$1" =~ ^(set|unpause|destroy|validate|release)$ ]]; then
      _command="$1"
      shift
    fi
    
    if [[ $# -gt 0 ]]; then
      _pipeline="$1"
      shift
    fi
  fi
  
  # Handle any remaining flags that were not captured by processing
  for arg in "$@"; do
    case "$arg" in
    --dry-run)
      _dry_run=true
      ;;
    --verbose)
      _verbose=true
      ;;
    --enable-validation-testing)
      _validation=true
      ;;
    --test-mode)
      _test_mode=true
      ;;
    --release)
      _create_release=true
      ;;
    --set-release-pipeline)
      _set_pipeline=true
      ;;
    esac
  done
}

# Function to handle legacy behavior conversion to new command format
# Takes variable references to allow explicit modification of globals
# @param create_release_ref Reference to CREATE_RELEASE variable
# @param set_pipeline_ref Reference to SET_RELEASE_PIPELINE variable
# @param command_ref Reference to COMMAND variable
# @param pipeline_ref Reference to PIPELINE variable
# @param release_pipeline_name The name of the release pipeline
function handle_legacy_behavior() {
  # Get references to variables
  local -n _create_release="$1"
  local -n _set_pipeline="$2"
  local -n _command="$3"
  local -n _pipeline="$4"
  local _release_pipeline_name="$5"

  # Apply legacy behavior rules
  if [[ "${_create_release}" == "true" ]]; then
    _command="release"
  fi

  if [[ "${_set_pipeline}" == "true" ]]; then
    _pipeline="${_release_pipeline_name}"
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
    _environment=$(determine_environment "${_foundation}")
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