#!/usr/bin/env bash
#
# Script: fly.sh
# Description: Enhanced pipeline management script that combines default fly functionality with advanced commands
#
# Usage: ./fly.sh [options] [command] [pipeline_name]
#
# Commands:
#   set          Set pipeline (default)
#   unpause      Set and unpause pipeline
#   destroy      Destroy specified pipeline
#   validate     Validate pipeline YAML without setting
#   release      Create a release pipeline
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CI_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
REPO_ROOT="$(cd "${CI_DIR}/.." &>/dev/null && pwd)"
REPO_NAME=$(basename "${REPO_ROOT}")
LIB_DIR="${SCRIPT_DIR}/lib"

# Test mode for automated testing (used in check_fly and other functions)
TEST_MODE=false

# Initialize default values
PIPELINE="main"
RELEASE_PIPELINE_NAME="release"
GITHUB_ORG="Utilities-tkgieng"
# Removed unused variable: GIT_RELEASE_BRANCH
CONFIG_GIT_BRANCH="master"
PARAMS_GIT_BRANCH="master"
# Removed unused variable: VERSION_FILE
VERSION=""
CREATE_RELEASE=false
SET_RELEASE_PIPELINE=false
DRY_RUN=false
VERBOSE=false
ENABLE_VALIDATION_TESTING=false
ENVIRONMENT=""
TIMER_DURATION="3h"
COMMAND="set"

# Source module files
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/help.sh"
source "${LIB_DIR}/parsing.sh"
source "${LIB_DIR}/commands.sh"
source "${LIB_DIR}/pipelines.sh"

# Source additional helper functions if available
# This is for backward compatibility, but should be empty now
if [[ -f "${SCRIPT_DIR}/helpers.sh" ]]; then
  source "${SCRIPT_DIR}/helpers.sh"
fi

# Main execution flow
main() {
  # Process help flags first
  check_help_flags "$@"
  
  # Process arguments in stages
  local processed_args=()
  preprocess_args processed_args "$@"
  
  # Replace the original arguments with our processed ones
  set -- "${processed_args[@]}"
  
  # Process any short-form args
  process_short_args "$@"
  
  # Try to get version if available and not already set
  if [[ -z "$VERSION" ]] && type get_latest_version &>/dev/null; then
    VERSION="$(get_latest_version)"
  fi
  
  # Find command and pipeline name
  detect_command_and_pipeline "$@"
  
  # Handle legacy behavior flags
  handle_legacy_behavior
  
  # Determine datacenter from foundation name
  DATACENTER=$(determine_datacenter "${FOUNDATION}")
  
  # Validate required parameters and set defaults
  validate_and_set_defaults
  
  # Enable verbose output if requested
  if [[ "${VERBOSE}" == "true" ]]; then
    set -x
  fi
  
  # Execute the requested command with parameters instead of global variables
  case "${COMMAND}" in
  set)
    cmd_set_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${BRANCH}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}"
    ;;
  unpause)
    cmd_unpause_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${BRANCH}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}"
    ;;
  destroy)
    cmd_destroy_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${DRY_RUN}"
    ;;
  validate)
    cmd_validate_pipeline "${PIPELINE}" "${DRY_RUN}"
    ;;
  release)
    cmd_release_pipeline "${FOUNDATION}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${BRANCH}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}"
    ;;
  *)
    error "Unknown command: ${COMMAND}"
    show_usage 1
    ;;
  esac
}

# Run the main function
main "$@"