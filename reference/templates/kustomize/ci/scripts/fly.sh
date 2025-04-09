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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CI_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
REPO_ROOT="$(cd "${CI_DIR}/.." &>/dev/null && pwd)"
REPO_NAME=$(basename "${REPO_ROOT}")

# Test mode for automated testing
TEST_MODE=false

# Source helper functions if available
if [[ -f "${SCRIPT_DIR}/helpers.sh" ]]; then
  source "${SCRIPT_DIR}/helpers.sh"
fi

# Function to display usage
function show_usage() {
  cat <<USAGE
Script: fly.sh
Description: Enhanced pipeline management script that combines simple usage with advanced commands

Usage: ./fly.sh [options] [command] [pipeline_name]

Commands:
  set          Set pipeline (default)
  unpause      Set and unpause pipeline
  destroy      Destroy specified pipeline
  validate     Validate pipeline YAML without setting
  release      Create a release pipeline

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -e, --environment ENV      Environment type (lab|nonprod|prod)
  -b, --branch BRANCH        Git branch for pipeline repository
  -c, --config-branch BRANCH Git branch for config repository
  -d, --params-branch BRANCH Params git branch (default: master)
  -p, --pipeline NAME        Custom pipeline name prefix
  -o, --github-org ORG       GitHub organization
  -v, --version VERSION      Pipeline version
  --release                  Create a release pipeline
  --set-release-pipeline     Set the release pipeline
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity
  --timer DURATION           Set timer trigger duration
  --enable-validation-testing Enable validation testing
  -h, --help                 Show this help message
USAGE
  exit "${1:-1}"
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
    echo "lab" # Default to lab if not determined
  fi
}

# Function to determine datacenter from foundation name
function determine_datacenter() {
  local foundation="$1"

  if [[ "${foundation}" == *"cml"* ]]; then
    echo "cml"
  elif [[ "${foundation}" == *"cic"* ]]; then
    echo "cic"
  else
    echo "${foundation}" | cut -d"-" -f1
  fi
}

# Function to check if fly is installed and accessible
function check_fly() {
  # In test mode, skip these checks
  if [[ "${TEST_MODE}" == "true" ]]; then
    return 0
  fi

  if ! command -v fly &>/dev/null; then
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
  if ! fly targets | grep -q "${TARGET}" 2>/dev/null; then
    error "Concourse target not found: ${TARGET}"
    error "Available targets:"
    fly targets 2>/dev/null || echo "  None found"
    exit 1
  fi

  return 0
}

# Function to validate a file exists
function validate_file_exists() {
  local file_path="$1"
  local description="${2:-File}"

  # In test mode, bypass file existence check
  if [[ "${TEST_MODE}" == "true" ]]; then
    return 0
  fi

  if [[ ! -f "$file_path" ]]; then
    error "$description not found: $file_path"
    return 1
  fi

  return 0
}

# Check for help flag first
for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    show_usage 0
  fi
done

# Check for long-form arguments that need preprocessing
PROCESSED_ARGS=()
for arg in "$@"; do
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
  PROCESSED_ARGS+=("$arg")
done

# Replace the original arguments with our processed ones
set -- "${PROCESSED_ARGS[@]}"

# Initialize default values
# These values need to be set here, not overridden if they were already set during preprocessing
if [[ -z "$PIPELINE" ]]; then PIPELINE="main"; fi
if [[ -z "$RELEASE_PIPELINE_NAME" ]]; then RELEASE_PIPELINE_NAME="release"; fi
if [[ -z "$GITHUB_ORG" ]]; then GITHUB_ORG="Utilities-tkgieng"; fi
if [[ -z "$GIT_RELEASE_BRANCH" ]]; then GIT_RELEASE_BRANCH="release"; fi
if [[ -z "$CONFIG_GIT_BRANCH" ]]; then CONFIG_GIT_BRANCH="master"; fi
if [[ -z "$PARAMS_GIT_BRANCH" ]]; then PARAMS_GIT_BRANCH="master"; fi
if [[ -z "$VERSION_FILE" ]]; then VERSION_FILE="version"; fi
if [[ -z "$VERSION" ]]; then VERSION=""; fi

# Try to get version if available and not already set
if [[ -z "$VERSION" ]] && type get_latest_version &>/dev/null; then
  VERSION="$(get_latest_version)"
fi

# Only set these if they weren't already set during preprocessing
if [[ -z "$CREATE_RELEASE" ]]; then CREATE_RELEASE=false; fi
if [[ -z "$SET_RELEASE_PIPELINE" ]]; then SET_RELEASE_PIPELINE=false; fi
if [[ -z "$DRY_RUN" ]]; then DRY_RUN=false; fi
if [[ -z "$VERBOSE" ]]; then VERBOSE=false; fi
if [[ -z "$ENABLE_VALIDATION_TESTING" ]]; then ENABLE_VALIDATION_TESTING=false; fi
if [[ -z "$ENVIRONMENT" ]]; then ENVIRONMENT=""; fi
if [[ -z "$TIMER_DURATION" ]]; then TIMER_DURATION="3h"; fi
if [[ -z "$COMMAND" ]]; then COMMAND="set"; fi

# Parse arguments using traditional option parsing
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
    show_usage 0
    ;;
  \?)
    echo "Invalid option: $OPTARG" 1>&2
    show_usage 1
    ;;
  :)
    echo "Invalid option: $OPTARG requires an argument" 1>&2
    show_usage 1
    ;;
  esac
done
shift $((OPTIND - 1))

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

# Handle any remaining flags that were not captured by getopts or preprocessing
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
DATACENTER=$(determine_datacenter "${FOUNDATION}")

# Implementation of set pipeline command
function cmd_set_pipeline() {
  check_fly

  # Prepare variables
  local pipeline_name="${PIPELINE}-${FOUNDATION}"
  local pipeline_file="${CI_DIR}/pipelines/${PIPELINE}.yml"

  # Handle release pipeline
  if [[ "$PIPELINE" == "release" ]]; then
    pipeline_file="${CI_DIR}/pipelines/release.yml"
  fi

  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    error "Available pipelines:"
    find "${CI_DIR}/pipelines/" -name "*.yml" -exec basename {} \; | sort | sed 's/\.yml$//'
    exit 1
  fi

  # Params directory path - check if it exists
  local params_path="${REPO_ROOT}/../params"

  # Build variables array
  local vars=(
    "-v" "foundation=${FOUNDATION}"
    "-v" "environment=${ENVIRONMENT}"
    "-v" "branch=${BRANCH}"
    "-v" "timer_duration=${TIMER_DURATION}"
    "-v" "verbose=${VERBOSE}"
  )

  # Add version if set
  if [[ -n "${VERSION}" ]]; then
    vars+=("-v" "version=${VERSION}")
  fi

  # Add datacenter if available
  if [[ -n "${DATACENTER}" ]]; then
    vars+=("-v" "datacenter=${DATACENTER}")
  fi

  # Add foundation path
  if [[ -n "${DATACENTER}" ]]; then
    vars+=("-v" "foundation_path=${DATACENTER}/${FOUNDATION}")
  fi

  # Build vars files array if params directory exists
  local vars_files=()

  if [[ -d "$params_path" ]]; then
    # Add global params if they exist
    if [[ -f "${params_path}/global.yml" ]]; then
      vars_files+=("-l" "${params_path}/global.yml")
    fi

    if [[ -f "${params_path}/k8s-global.yml" ]]; then
      vars_files+=("-l" "${params_path}/k8s-global.yml")
    fi

    # Add datacenter params if they exist
    if [[ -d "${params_path}/${DATACENTER}" ]]; then
      if [[ -f "${params_path}/${DATACENTER}/${DATACENTER}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${DATACENTER}/${DATACENTER}.yml")
      fi

      if [[ -f "${params_path}/${DATACENTER}/${FOUNDATION}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${DATACENTER}/${FOUNDATION}.yml")
      fi
    fi
  fi

  # Execute the command
  info "Setting pipeline: ${pipeline_name}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" set-pipeline -p \"${pipeline_name}\" -c \"${pipeline_file}\" ${vars_files[*]} ${vars[*]}"
  else
    # With vars_files
    if [[ ${#vars_files[@]} -gt 0 ]]; then
      fly -t "$TARGET" set-pipeline \
        -p "${pipeline_name}" \
        -c "${pipeline_file}" \
        "${vars_files[@]}" \
        "${vars[@]}"
    else
      # Without vars_files
      fly -t "$TARGET" set-pipeline \
        -p "${pipeline_name}" \
        -c "${pipeline_file}" \
        "${vars[@]}"
    fi

    success "Pipeline '${pipeline_name}' set successfully"
  fi
}

# Implementation of unpause pipeline command
function cmd_unpause_pipeline() {
  # First set the pipeline
  cmd_set_pipeline

  local pipeline_name="${PIPELINE}-${FOUNDATION}"

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

  local pipeline_name="${PIPELINE}-${FOUNDATION}"
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
  # Determine pipeline file
  local pipeline_file="${CI_DIR}/pipelines/${PIPELINE}.yml"

  # Handle special pipeline names
  if [[ "$PIPELINE" == "release" ]]; then
    pipeline_file="${CI_DIR}/pipelines/release.yml"
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
    error "Available pipelines:"
    find "${CI_DIR}/pipelines/" -name "*.yml" -exec basename {} \; | sort | sed 's/\.yml$//'
    exit 1
  fi

  info "Validating pipeline: ${PIPELINE}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly validate-pipeline -c \"${pipeline_file}\""
  else
    fly validate-pipeline -c "${pipeline_file}" || {
      error "Pipeline validation failed: ${PIPELINE}"
      return 1
    }

    success "Pipeline validated successfully: ${PIPELINE}"
  fi
}

# Implementation of release pipeline command (legacy behavior)
function cmd_release_pipeline() {
  # Switch to release pipeline
  PIPELINE="release"

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
  show_usage 1
  ;;
esac
