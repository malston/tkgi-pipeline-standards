#!/usr/bin/env bash
#
# Script: ns-mgmt-refactored.sh
# Description: Enhanced pipeline management script that combines ns-mgmt functionality with advanced commands
#
# Usage: ./ns-mgmt-refactored.sh [options] [command] [pipeline_name]
#
# Commands:
#   set          Set pipeline (default)
#   unpause      Set and unpause pipeline
#   destroy      Destroy specified pipeline
#   validate     Validate pipeline YAML without setting
#   release      Create a release pipeline
#
# Options:
#   -f, --foundation NAME      Foundation name (required)
#   -t, --target TARGET        Concourse target (default: <foundation>)
#   -e, --environment ENV      Environment type (lab|nonprod|prod)
#   -b, --branch BRANCH        Git branch for pipeline repository 
#   -c, --config-branch BRANCH Git branch for config repository
#   -d, --params-branch BRANCH Params git branch (default: master)
#   -p, --pipeline NAME        Custom pipeline name prefix
#   -o, --github-org ORG       GitHub organization 
#   -v, --version VERSION      Pipeline version
#   --release                  Create a release pipeline
#   --set-release-pipeline     Set the release pipeline
#   --dry-run                  Simulate without making changes
#   --verbose                  Increase output verbosity
#   --timer DURATION           Set timer trigger duration
#   --enable-validation-testing Enable validation testing
#   -h, --help                 Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CI_DIR="$(cd "${__DIR}/.." &>/dev/null && pwd)"
REPO_ROOT="$(cd "${CI_DIR}/.." &>/dev/null && pwd)"
REPO_NAME=$(basename "${REPO_ROOT}")

# Source helper functions if available
if [[ -f "${__DIR}/ns-mgmt-helpers.sh" ]]; then
  source "${__DIR}/ns-mgmt-helpers.sh"
elif [[ -f "${__DIR}/helpers.sh" ]]; then
  source "${__DIR}/helpers.sh"
fi

# Default values (from original ns-mgmt-fly.sh)
PIPELINE="tkgi-ns-mgmt"
RELEASE_PIPELINE_NAME="$PIPELINE-release"
PIPELINE_FILE="${CI_DIR}/pipelines/main.yml"
RELEASE_PIPELINE_FILE="${CI_DIR}/pipelines/release.yml"
GITHUB_ORG="Utilities-tkgieng"
GIT_RELEASE_BRANCH="release"
CONFIG_GIT_BRANCH="master"
PARAMS_GIT_BRANCH="master"
VERSION_FILE="version"
VERSION="$(get_latest_version)"
CREATE_RELEASE=false
SET_RELEASE_PIPELINE=false
DRY_RUN=false
VERBOSE=false
ENABLE_VALIDATION_TESTING=false
ENVIRONMENT=""
TIMER_DURATION="3h"
COMMAND="set"

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

# Function to determine environment based on foundation name
function determine_environment() {
  local foundation="$1"
  
  if [[ "$foundation" == *"-lab-"* || "$foundation" == *"-n-"* ]]; then
    echo "lab"
  elif [[ "$foundation" == *"-nonprod-"* || "$foundation" == *"-d-"* ]]; then
    echo "nonprod"
  elif [[ "$foundation" == *"-prod-"* || "$foundation" == *"-p-"* ]]; then
    echo "prod"
  else
    echo "lab"  # Default to lab if not determined
  fi
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

# Parse arguments - supporting both getopt and direct argument parsing for backward compatibility
SUPPORTED_OPTIONS="f:t:e:b:c:d:p:o:v:rsh"
SUPPORTED_LONG_OPTIONS="foundation:,target:,environment:,branch:,config-branch:,params-branch:,pipeline:,github-org:,version:,release,set-release-pipeline,dry-run,verbose,timer:,enable-validation-testing,help"

# Try to use getopt for enhanced option parsing
if getopt -T &>/dev/null; then
  if [[ $? -eq 4 ]]; then
    # Enhanced getopt is available
    TEMP=$(getopt -o "$SUPPORTED_OPTIONS" --long "$SUPPORTED_LONG_OPTIONS" -n "$0" -- "$@" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
      # Fall back to traditional parsing
      :
    else
      eval set -- "$TEMP"
      # Parse using getopt
      while true; do
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
          -r|--release)
            CREATE_RELEASE=true
            shift
            ;;
          -s|--set-release-pipeline)
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
          --timer)
            TIMER_DURATION="$2"
            shift 2
            ;;
          --enable-validation-testing)
            ENABLE_VALIDATION_TESTING=true
            shift
            ;;
          -h|--help)
            show_usage
            ;;
          --)
            shift
            break
            ;;
          *)
            error "Internal error!"
            exit 1
            ;;
        esac
      done
      
      # Check for additional arguments (command and pipeline)
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
    fi
  fi
fi

# Fall back to traditional option parsing if getopt not available or failed
if [[ -z "$TEMP" ]]; then
  while getopts ":f:t:e:b:c:d:p:o:v:rsh" opt; do
    case ${opt} in
      f)
        FOUNDATION=$OPTARG
        ;;
      t)
        TARGET=$OPTARG
        ;;
      e)
        ENVIRONMENT=$OPTARG
        ;;
      b)
        BRANCH=$OPTARG
        ;;
      c)
        CONFIG_GIT_BRANCH=$OPTARG
        ;;
      d)
        PARAMS_GIT_BRANCH=$OPTARG
        ;;
      p)
        PIPELINE=$OPTARG
        ;;
      o)
        GITHUB_ORG=$OPTARG
        ;;
      v)
        VERSION=$OPTARG
        ;;
      r)
        CREATE_RELEASE=true
        ;;
      s)
        SET_RELEASE_PIPELINE=true
        ;;
      h)
        show_usage
        ;;
      \?)
        echo "Invalid option: $OPTARG" 1>&2
        show_usage
        ;;
      :)
        echo "Invalid option: $OPTARG requires an argument" 1>&2
        show_usage
        ;;
    esac
  done
  shift $((OPTIND -1))
  
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
  
  # Handle legacy flags that would otherwise be dropped
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
    esac
  done
fi

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

# Handle legacy behavior conversion to new command format
if [[ "${CREATE_RELEASE}" == "true" ]]; then
  COMMAND="release"
fi

if [[ "${SET_RELEASE_PIPELINE}" == "true" ]]; then
  PIPELINE="${RELEASE_PIPELINE_NAME}"
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

# Set default environment if not provided
if [[ -z "${ENVIRONMENT}" ]]; then
  ENVIRONMENT=$(determine_environment "${FOUNDATION}")
fi

# Set default branch based on environment if not provided
if [[ -z "${BRANCH}" ]]; then
  if [[ "${ENVIRONMENT}" == "lab" ]]; then
    BRANCH="develop"
  else
    BRANCH="master"
  fi
fi

# Validate environment
if [[ ! "${ENVIRONMENT}" =~ ^(lab|nonprod|prod)$ ]]; then
  error "Invalid environment: ${ENVIRONMENT}. Must be one of: lab, nonprod, prod"
  show_usage
fi

# Determine datacenter from foundation name
if [[ "${FOUNDATION}" == *"cml"* ]]; then
  DATACENTER="cml"
elif [[ "${FOUNDATION}" == *"cic"* ]]; then
  DATACENTER="cic"
else
  DATACENTER=$(echo "${FOUNDATION}" | cut -d"-" -f1)
fi

# Implementation of set pipeline command
function cmd_set_pipeline() {
  check_fly
  
  # Prepare variables
  local pipeline_name="$PIPELINE-$FOUNDATION"
  local pipeline_file="${PIPELINE_FILE}"
  
  # Handle release pipeline
  if [[ "$PIPELINE" == *"-release"* ]]; then
    pipeline_file="${RELEASE_PIPELINE_FILE}"
  fi
  
  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    exit 1
  fi
  
  # Build the list of vars files in the correct hierarchy
  local vars_files=(
    "-l" "${REPO_ROOT}/../params/global.yml"
    "-l" "${REPO_ROOT}/../params/k8s-global.yml"
    "-l" "${REPO_ROOT}/../params/${DATACENTER}/${DATACENTER}.yml"
    "-l" "${REPO_ROOT}/../params/${DATACENTER}/${FOUNDATION}.yml"
  )
  
  # Build variables
  local vars=(
    "-v" "foundation=${FOUNDATION}"
    "-v" "datacenter=${DATACENTER}"
    "-v" "environment=${ENVIRONMENT}"
    "-v" "branch=${BRANCH}"
    "-v" "config_branch=${CONFIG_GIT_BRANCH}"
    "-v" "params_branch=${PARAMS_GIT_BRANCH}"
    "-v" "github_org=${GITHUB_ORG}"
    "-v" "version=${VERSION}"
    "-v" "pipeline=${PIPELINE}"
    "-v" "timer_duration=${TIMER_DURATION}"
    "-v" "enable_validation_testing=${ENABLE_VALIDATION_TESTING}"
    "-v" "verbose=${VERBOSE}"
  )
  
  # Execute the command
  info "Setting pipeline: ${pipeline_name}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" set-pipeline -p \"${pipeline_name}\" -c \"${pipeline_file}\" ${vars_files[@]} ${vars[@]}"
  else
    fly -t "$TARGET" set-pipeline \
      -p "${pipeline_name}" \
      -c "${pipeline_file}" \
      "${vars_files[@]}" \
      "${vars[@]}"
      
    success "Pipeline '${pipeline_name}' set successfully"
  fi
}

# Implementation of unpause pipeline command
function cmd_unpause_pipeline() {
  # First set the pipeline
  cmd_set_pipeline
  
  local pipeline_name="$PIPELINE-$FOUNDATION"
  
  info "Unpausing pipeline: ${pipeline_name}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" unpause-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$TARGET" unpause-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' unpaused successfully"
  fi
}

# Implementation of destroy pipeline command
function cmd_destroy_pipeline() {
  check_fly
  
  local pipeline_name="$PIPELINE-$FOUNDATION"
  local confirmation=""
  
  # Confirm destruction
  if [[ -z "$confirmation" ]]; then
    read -p "Are you sure you want to destroy pipeline '${pipeline_name}'? (yes/no): " confirmation
  fi
  
  if [[ "${confirmation}" != "yes" ]]; then
    info "Pipeline destruction cancelled"
    return 0
  fi
  
  # Execute the command
  info "Destroying pipeline: ${pipeline_name}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" destroy-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$TARGET" destroy-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' destroyed successfully"
  fi
}

# Implementation of validate pipeline command
function cmd_validate_pipeline() {
  local pipeline_file="${PIPELINE_FILE}"
  
  # Handle release pipeline
  if [[ "$PIPELINE" == *"-release"* ]]; then
    pipeline_file="${RELEASE_PIPELINE_FILE}"
  fi
  
  # Validate all pipelines if requested
  if [[ "$PIPELINE" == "all" ]]; then
    info "Validating all pipelines"
    
    for pipeline_file in "${CI_DIR}"/pipelines/*.yml; do
      local pipeline_name=$(basename "${pipeline_file}" .yml)
      info "Validating pipeline: ${pipeline_name}"
      
      fly validate-pipeline -c "${pipeline_file}" || {
        error "Pipeline validation failed: ${pipeline_name}"
        return 1
      }
    done
    
    success "All pipelines validated successfully"
    return 0
  fi
  
  # Validate a specific pipeline
  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    exit 1
  fi
  
  info "Validating pipeline: ${PIPELINE}"
  
  fly validate-pipeline -c "${pipeline_file}" || {
    error "Pipeline validation failed: ${PIPELINE}"
    return 1
  }
  
  success "Pipeline validated successfully: ${PIPELINE}"
}

# Implementation of release pipeline command (legacy behavior)
function cmd_release_pipeline() {
  # Update to use release pipeline
  PIPELINE="${RELEASE_PIPELINE_NAME}"
  PIPELINE_FILE="${RELEASE_PIPELINE_FILE}"
  
  # Set the pipeline
  cmd_set_pipeline
}

# Execute the requested command
case "${COMMAND}" in
  set)
    cmd_set_pipeline
    ;;
  unpause)
    cmd_unpause_pipeline
    ;;
  destroy)
    cmd_destroy_pipeline
    ;;
  validate)
    cmd_validate_pipeline
    ;;
  release)
    cmd_release_pipeline
    ;;
  *)
    error "Unknown command: ${COMMAND}"
    show_usage
    ;;
esac