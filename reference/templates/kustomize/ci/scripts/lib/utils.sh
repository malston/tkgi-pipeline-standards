#!/usr/bin/env bash
#
# Utility functions for fly.sh
# Contains shared functions used throughout the script
#

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