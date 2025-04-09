#!/usr/bin/env bash
#
# Script: tests.sh
# Description: Runs all tests for the repository
#
# Usage: ./tests.sh [options]
#
# Options:
#   -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
#   -v, --verbose                 Enable verbose output
#   -h, --help                    Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd "${__DIR}/.." &>/dev/null && pwd)"

# Source common functions if available
HELPERS="${REPO_ROOT}/scripts/helpers.sh"
if [[ -f "${HELPERS}" ]]; then
  source "${HELPERS}"
fi

# Default values
FOUNDATION=""
VERBOSE=false

# Function to display usage
function show_usage() {
  grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \{0,1\}//'
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--foundation)
      FOUNDATION="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      echo "Error: Unknown option: $1"
      show_usage
      ;;
  esac
done

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

# Validate required arguments
if [[ -z "${FOUNDATION}" ]]; then
  echo "Error: Foundation name not specified. Use -f or --foundation option."
  show_usage
fi

# Main function
function run_tests() {
  echo "Running tests for foundation: ${FOUNDATION}"
  
  # Run all test scripts in test/scripts directory
  if [[ -d "${__DIR}/scripts" ]]; then
    for test_script in "${__DIR}/scripts"/*.sh; do
      if [[ -f "${test_script}" && -x "${test_script}" ]]; then
        echo "Running test script: ${test_script}"
        "${test_script}" -f "${FOUNDATION}" ${VERBOSE:+-v}
        
        if [[ $? -eq 0 ]]; then
          echo "✅ Test passed: $(basename "${test_script}")"
        else
          echo "❌ Test failed: $(basename "${test_script}")"
          exit 1
        fi
      fi
    done
  else
    echo "No test scripts found in ${__DIR}/scripts"
  fi
  
  echo "All tests passed successfully"
}

# Execute the tests
run_tests