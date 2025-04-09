#!/usr/bin/env bash
#
# Script: fly.sh
# Description: Manages Concourse pipelines
#
# Usage: ./fly.sh [options] [command] [pipeline_name]
#
# Commands:
#   set          Set pipeline (default)
#   unpause      Set and unpause pipeline
#   destroy      Destroy specified pipeline
#   validate     Validate pipeline YAML without setting
#
# Special Commands:
#   -r, --release [MESSAGE]    Set the release pipeline
#   -s, --set [NAME]           Set the set-pipeline pipeline
#
# Options:
#   -f, --foundation NAME      Foundation name (required)
#   -t, --target TARGET        Concourse target (default: <foundation>)
#   -e, --environment ENV      Environment type (lab|nonprod|prod)
#   -b, --branch BRANCH        Git branch for pipeline repository 
#   -c, --config-branch BRANCH Git branch for config repository
#   -n, --config-repo NAME     Config repository name
#   -d, --params-branch BRANCH Params git branch (default: master)
#   -p, --pipeline NAME        Custom pipeline name prefix
#   -o, --github-org ORG       GitHub organization 
#   -v, --version VERSION      Pipeline version
#   --dry-run                  Simulate without making changes
#   --verbose                  Increase output verbosity
#   --timer DURATION           Set timer trigger duration
#   -h, --help                 Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get repository root directory
CI_DIR="$(cd "${__DIR}/.." &>/dev/null && pwd)"
REPO_ROOT="$(cd "${CI_DIR}/.." &>/dev/null && pwd)"
REPO_NAME=$(basename "${REPO_ROOT}")

# Source helper functions if available
if [[ -f "${__DIR}/helpers.sh" ]]; then
  source "${__DIR}/helpers.sh"
fi

# Default values
FOUNDATION=""
TARGET=""
ENVIRONMENT="lab"
BRANCH="develop"
CONFIG_BRANCH="master"
CONFIG_REPO="config-lab"
PARAMS_BRANCH="master"
PIPELINE="${REPO_NAME}"
GITHUB_ORG="your-org"
VERSION="latest"
DRY_RUN=false
VERBOSE=false
TIMER="24h"
COMMAND="set"
PIPELINE=""

# Function to display usage
function show_usage() {
  grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \{0,1\}//'
  exit 1
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

# Function to check if fly is installed and accessible
function check_fly() {
  if ! command -v fly &> /dev/null; then
    error "fly command not found"
    error "Please install the Concourse CLI: https://concourse-ci.org/download.html"
    exit 1
  fi
  
  # Check if target is defined
  if [[ -z "${TARGET}" ]]; then
    error "Concourse target not specified"
    exit 1
  fi
  
  # Check if target exists
  if ! fly targets | grep -q "${TARGET}"; then
    error "Concourse target not found: ${TARGET}"
    error "Available targets:"
    fly targets
    exit 1
  fi
  
  return 0
}

# Function to validate a file exists
function validate_file_exists() {
  local file_path="$1"
  local description="${2:-File}"
  
  if [[ ! -f "$file_path" ]]; then
    error "$description not found: $file_path"
    return 1
  fi
  
  return 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
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
      CONFIG_BRANCH="$2"
      shift 2
      ;;
    -n|--config-repo)
      CONFIG_REPO="$2"
      shift 2
      ;;
    -d|--params-branch)
      PARAMS_BRANCH="$2"
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
      TIMER="$2"
      shift 2
      ;;
    -r|--release)
      COMMAND="release"
      if [[ "$2" != -* && ! -z "$2" ]]; then
        RELEASE_MESSAGE="$2"
        shift
      fi
      shift
      ;;
    -s|--set)
      COMMAND="set-pipeline"
      if [[ "$2" != -* && ! -z "$2" ]]; then
        PIPELINE="$2"
        shift
      fi
      shift
      ;;
    -h|--help)
      show_usage
      ;;
    set|unpause|destroy|validate)
      COMMAND="$1"
      shift
      ;;
    *)
      # Assume it's the pipeline name
      if [[ -z "$PIPELINE" ]]; then
        PIPELINE="$1"
      else
        error "Unknown option: $1"
        show_usage
      fi
      shift
      ;;
  esac
done

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

# Validate required parameters
if [[ -z "${FOUNDATION}" ]]; then
  error "Foundation not specified. Use -f or --foundation option."
  show_usage
fi

# Set default target if not provided
if [[ -z "${TARGET}" ]]; then
  TARGET="${FOUNDATION}"
fi

# Validate environment
if [[ ! "${ENVIRONMENT}" =~ ^(lab|nonprod|prod)$ ]]; then
  error "Invalid environment: ${ENVIRONMENT}. Must be one of: lab, nonprod, prod"
  show_usage
fi

# Command implementations
source "${__DIR}/cmd_set_pipeline.sh"

# Execute the requested command
case "${COMMAND}" in
  set)
    cmd_set_pipeline "$@"
    ;;
  unpause)
    cmd_unpause_pipeline "$@"
    ;;
  destroy)
    cmd_destroy_pipeline "$@"
    ;;
  validate)
    cmd_validate_pipeline "$@"
    ;;
  release)
    cmd_release_pipeline "$@"
    ;;
  set-pipeline)
    cmd_set_pipeline_pipeline "$@"
    ;;
  *)
    error "Unknown command: ${COMMAND}"
    show_usage
    ;;
esac