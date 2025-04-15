#!/usr/bin/env bash
#
# Utility functions for fly.sh
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Function to log info messages
function info() {
  echo -e "\033[0;33m[INFO]\033[0m $1"
}

# Function to log error messages
function error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

# Function to log success messages
function success() {
  echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

# Function to log warning messages
function warning() {
  echo -e "\033[0;33m[WARNING]\033[0m $1"
}

# Function to check if a command exists
function check_command() {
  local cmd="$1"

  if [[ "${TEST_MODE}" == "true" ]]; then
    return 0
  fi

  if ! command -v "$cmd" &> /dev/null; then
    error "Required command not found: $cmd"
    return 1
  fi

  return 0
}

# Function to check if fly is installed and logged in
function check_fly() {
  local target="$1"

  if [[ "${TEST_MODE}" == "true" ]]; then
    return 0
  fi

  # Check if fly command exists
  if ! check_command "fly"; then
    error "fly command not found. Please install Concourse CLI."
    return 1
  fi

  # Check if target is set
  if ! fly targets | grep -q "$target"; then
    error "Target $target not found. Please login using 'fly -t $target login'"
    return 1
  fi

  # Try to get status (will fail if not logged in)
  if ! fly -t "$target" status &> /dev/null; then
    error "Not logged in to target $target. Please login using 'fly -t $target login'"
    return 1
  fi

  return 0
}
