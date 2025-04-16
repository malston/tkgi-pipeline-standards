#!/usr/bin/env bash
#
# Task: validate-tool
# Description: Validates the installation of the component
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#   - TOOL_NAME: Name of the CLI tool (e.g., tridentctl)
#
# Optional Environment Variables:
#   - NAMESPACE: Namespace to validate (default: tool-specific default)
#   - VERBOSE: Enable verbose output (default: false)
#

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get repository root directory
REPO_ROOT="$(cd "${__DIR}/../../../../.." &>/dev/null && pwd)"

# Validate required environment variables
[[ -z "${FOUNDATION}" ]] && { echo "Error: FOUNDATION is required"; exit 1; }
[[ -z "${TOOL_NAME}" ]] && { echo "Error: TOOL_NAME is required"; exit 1; }

# Set defaults for optional variables
NAMESPACE="${NAMESPACE:-}"
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Validating ${TOOL_NAME} installation on foundation ${FOUNDATION}"

# Add the CLI tool to PATH
export PATH="${PWD}/cli-tool-bin:${PATH}"
if ! command -v "${TOOL_NAME}" &> /dev/null; then
  echo "Error: ${TOOL_NAME} not found in PATH"
  exit 1
fi

# Source PKS/TKGi credentials if available
if [[ -f "pks-config/credentials" ]]; then
  source pks-config/credentials
  echo "Loaded PKS/TKGi credentials"
fi

# Use KUBECONFIG if available
if [[ -f "pks-config/environment" ]]; then
  source pks-config/environment
  echo "Loaded KUBECONFIG from: ${KUBECONFIG}"
fi

# Create output directory for validation results
mkdir -p validation-results

# Call the repository's validate script with the appropriate arguments
"${REPO_ROOT}/scripts/validate.sh" \
  -f "${FOUNDATION}" \
  -t "${TOOL_NAME}" \
  -c "${PWD}/config-repo" \
  -o "${PWD}/validation-results" \
  ${NAMESPACE:+-n "${NAMESPACE}"} \
  ${VERBOSE:+-V}

# Check if validation was successful
if [[ -f "validation-results/validation-status.txt" ]]; then
  if grep -q "FAILED" "validation-results/validation-status.txt"; then
    echo "Error: Validation failed"
    cat "validation-results/validation-status.txt"
    exit 1
  else
    echo "Validation successful"
    cat "validation-results/validation-status.txt"
  fi
else
  echo "Warning: No validation status file was created"
fi

echo "Task completed successfully"
