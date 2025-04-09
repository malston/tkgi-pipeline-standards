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
function detect_command_and_pipeline() {
  # Check for command and pipeline arguments
  if [[ $# -gt 0 ]]; then
    if [[ "$1" =~ ^(set|unpause|destroy|validate|release)$ ]]; then
      COMMAND="$1"
      shift
    fi
    
    if [[ $# -gt 0 ]]; then
      PIPELINE="$1"
      shift
    fi
  fi
  
  # Handle any remaining flags that were not captured by processing
  for arg in "$@"; do
    case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    --verbose)
      VERBOSE=true
      ;;
    --enable-validation-testing)
      ENABLE_VALIDATION_TESTING=true
      ;;
    --test-mode)
      TEST_MODE=true
      ;;
    --release)
      CREATE_RELEASE=true
      ;;
    --set-release-pipeline)
      SET_RELEASE_PIPELINE=true
      ;;
    esac
  done
}

# Function to handle legacy behavior conversion to new command format
function handle_legacy_behavior() {
  if [[ "${CREATE_RELEASE}" == "true" ]]; then
    COMMAND="release"
  fi

  if [[ "${SET_RELEASE_PIPELINE}" == "true" ]]; then
    PIPELINE="${RELEASE_PIPELINE_NAME}"
  fi
}

# Function to validate required parameters and set defaults
function validate_and_set_defaults() {
  # Validate required parameters
  if [[ -z "${FOUNDATION}" ]]; then
    error "Foundation not specified. Use -f or --foundation option."
    show_usage 1
  fi

  # Set default target if not provided
  if [[ -z "${TARGET}" ]]; then
    TARGET="${FOUNDATION}"
  fi

  # Set default environment if not provided
  if [[ -z "${ENVIRONMENT}" ]]; then
    ENVIRONMENT=$(determine_environment "${FOUNDATION}")
  fi

  # Set default branch based on environment if not provided
  if [[ -z "${BRANCH}" ]]; then
    if [[ "${ENVIRONMENT}" == "lab" ]]; then
      BRANCH="develop"
    else
      BRANCH="main"
    fi
  fi

  # Validate environment
  if [[ ! "${ENVIRONMENT}" =~ ^(lab|nonprod|prod)$ ]]; then
    error "Invalid environment: ${ENVIRONMENT}. Must be one of: lab, nonprod, prod"
    show_usage 1
  fi
}