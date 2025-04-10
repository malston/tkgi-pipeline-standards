#!/usr/bin/env bash
#
# Utility functions for fly.sh
# Contains shared functions used throughout the script
#

# Function to log info messages
function info() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local caller_info
  if [[ "${BASH_VERSINFO[0]}" -ge 4 && "${DEBUG}" == "true" ]]; then
    # Only add caller info in debug mode
    caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}"
    echo "[INFO] [${timestamp}] [${caller_info}] $1"
  else
    # Normal mode without caller info
    echo "[INFO] [${timestamp}] $1"
  fi
}

# Function to log error messages
function error() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local caller_info
  if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    # Get caller information (file and line number)
    # BASH_SOURCE[1] is the file that called the error function
    # BASH_LINENO[0] is the line number in that file
    caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}"
    echo "[ERROR] [${timestamp}] [${caller_info}] $1" >&2
  else
    # Fallback for older Bash versions
    echo "[ERROR] [${timestamp}] $1" >&2
  fi
}

# Function to log success messages
function success() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local caller_info
  if [[ "${BASH_VERSINFO[0]}" -ge 4 && "${DEBUG}" == "true" ]]; then
    # Only add caller info in debug mode
    caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}"
    echo "[SUCCESS] [${timestamp}] [${caller_info}] $1"
  else
    # Normal mode without caller info
    echo "[SUCCESS] [${timestamp}] $1"
  fi
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

# Function to get datacenter from foundation name
function get_datacenter() {
  local foundation="$1"

  echo "${foundation}" | cut -d"-" -f1
}

# Function to get datacenter type from foundation name
function get_datacenter_type() {
  local foundation="$1"

  echo "${foundation}" | cut -d"-" -f2
}

# Function to check if fly is installed and accessible
# @param target_ref Reference to TARGET variable
# @param test_mode_ref Reference to TEST_MODE variable
function check_fly() {
  # Get references to variables if they're passed, otherwise use the values directly
  if [[ "$#" -ge 2 ]]; then
    local -n _target="$1"
    local -n _test_mode="$2"
    local target="${_target}"
  else
    # Fallback to direct parameter for backward compatibility
    local target="$1"
    local _test_mode="${TEST_MODE}"
  fi

  # In test mode, skip these checks
  if [[ "${_test_mode}" == "true" ]]; then
    return 0
  fi

  if ! command -v fly &>/dev/null; then
    error "fly command not found"
    error "Please install the Concourse CLI: https://concourse-ci.org/download.html"
    exit 1
  fi

  # Check if target is defined
  if [[ -z "${target}" ]]; then
    error "Concourse target not specified"
    exit 1
  fi

  # Check if target exists
  if ! fly targets | grep -q "${target}" 2>/dev/null; then
    error "Concourse target not found: ${target}"
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
