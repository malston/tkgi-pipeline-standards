#!/usr/bin/env bash
#
# Argument parsing functions for fly.sh
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Function to process command-line arguments
function process_args() {
  local supported_commands="$1"
  shift

  # Default values set in main script
  local args=()
  local positional=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        # Already handled in check_help_flags
        shift
        ;;
      -f|--foundation)
        FOUNDATION="$2"
        shift 2
        ;;
      -t|--target)
        TARGET="$2"
        shift 2
        ;;
      -e|--environment)
        ENVIRONMENT="$2"
        shift 2
        ;;
      -b|--branch)
        BRANCH="$2"
        shift 2
        ;;
      -c|--config-branch)
        CONFIG_GIT_BRANCH="$2"
        shift 2
        ;;
      -d|--params-branch)
        PARAMS_GIT_BRANCH="$2"
        shift 2
        ;;
      -p|--pipeline)
        PIPELINE="$2"
        shift 2
        ;;
      -o|--github-org)
        GITHUB_ORG="$2"
        shift 2
        ;;
      -v|--version)
        VERSION="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --timer)
        TIMER_DURATION="$2"
        shift 2
        ;;
      --release)
        CREATE_RELEASE=true
        shift
        ;;
      --release-pipeline)
        SET_RELEASE_PIPELINE=true
        shift
        ;;
      --help=*)
        # Already handled in check_help_flags
        shift
        ;;
      -*)
        error "Unknown option: $1"
        show_usage 1
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  # Check if the next positional is a command
  if [[ -n "${positional[0]}" && "${positional[0]}" =~ ^($supported_commands)$ ]]; then
    COMMAND="${positional[0]}"
    positional=("${positional[@]:1}")
  fi

  # Set pipeline name from positional arguments if provided
  if [[ ${#positional[@]} -gt 0 && "${COMMAND}" != "validate" ]]; then
    PIPELINE="${positional[0]}"
  fi

  # For validate command, set PIPELINE to validate all if not specified
  if [[ "${COMMAND}" == "validate" && ${#positional[@]} -eq 0 ]]; then
    PIPELINE="all"
  elif [[ "${COMMAND}" == "validate" && ${#positional[@]} -gt 0 ]]; then
    PIPELINE="${positional[0]}"
  fi
}
