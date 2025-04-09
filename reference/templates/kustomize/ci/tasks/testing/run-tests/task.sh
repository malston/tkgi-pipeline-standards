#!/usr/bin/env bash
#
# Task: run-tests
# Description: Runs tests for the repository
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#
# Optional Environment Variables:
#   - VERBOSE: Enable verbose output (default: false)
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get repository root directory
REPO_ROOT="$(cd "${__DIR}/../../../../.." &>/dev/null && pwd)"

# Validate required environment variables
[[ -z "${FOUNDATION}" ]] && { echo "Error: FOUNDATION is required"; exit 1; }

# Set defaults for optional variables
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Running tests for foundation: ${FOUNDATION}"

# Source PKS/TKGi credentials if available
if [[ -f "pks-config/credentials" ]]; then
  source pks-config/credentials
  echo "Loaded PKS/TKGi credentials"
fi

# Source KUBECONFIG if available
if [[ -f "pks-config/environment" ]]; then
  source pks-config/environment
  echo "Loaded KUBECONFIG from: ${KUBECONFIG}"
fi

# Call the repository's test script with the appropriate arguments
"${REPO_ROOT}/test/tests.sh" \
  -f "${FOUNDATION}" \
  ${VERBOSE}

echo "Task completed successfully"