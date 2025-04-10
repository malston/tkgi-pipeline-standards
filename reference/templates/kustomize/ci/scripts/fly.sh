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

# Debug mode for additional logging
DEBUG=false

# Initialize default values
PIPELINE="main"
RELEASE_PIPELINE_NAME="release"
GITHUB_ORG="Utilities-tkgieng"
GIT_RELEASE_BRANCH="release"
CONFIG_GIT_BRANCH="master"
PARAMS_GIT_BRANCH="master"
VERSION_FILE=version
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

  # Simple argument processing with our new comprehensive function
  process_args "$@"

  # Handle legacy behavior
  if [[ "${CREATE_RELEASE}" == "true" ]]; then
    COMMAND="release"
  fi

  if [[ "${SET_RELEASE_PIPELINE}" == "true" ]]; then
    PIPELINE="${RELEASE_PIPELINE_NAME}"
  fi

  # Try to get version if available and not already set
  if [[ -z "$VERSION" ]] && type get_latest_version &>/dev/null; then
    VERSION="$(get_latest_version)"
  fi

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

  # Determine datacenter from foundation name
  DATACENTER=$(get_datacenter "${FOUNDATION}")

  # Determine datacenter type from foundation name
  DATACENTER_TYPE=$(get_datacenter_type "${FOUNDATION}")

  # Enable verbose output if requested
  if [[ "${VERBOSE}" == "true" ]]; then
    set -x
  fi

  # Execute the requested command with parameters instead of global variables
  case "${COMMAND}" in
  set)
    cmd_set_pipeline "${PIPELINE}" "${FOUNDATION}" "${REPO_NAME}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${BRANCH}" "${GIT_RELEASE_BRANCH}" "${VERSION_FILE}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}"
    ;;
  unpause)
    cmd_unpause_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${BRANCH}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}"
    ;;
  destroy)
    cmd_destroy_pipeline "${PIPELINE}" "${FOUNDATION}" "${TARGET}" "${DRY_RUN}"
    ;;
  validate)
    cmd_validate_pipeline "${PIPELINE}" "${DRY_RUN}"
    ;;
  release)
    cmd_release_pipeline "${FOUNDATION}" "${REPO_NAME}" "${TARGET}" "${ENVIRONMENT}" "${DATACENTER}" "${DATACENTER_TYPE}" "${BRANCH}" "${GIT_RELEASE_BRANCH}" "${VERSION_FILE}" "${TIMER_DURATION}" "${VERSION}" "${DRY_RUN}" "${VERBOSE}"
    ;;
  *)
    error "Unknown command: ${COMMAND}"
    show_usage 1
    ;;
  esac
}

# Run the main function
main "$@"
