#!/usr/bin/env bash
#
# Task: install-tool
# Description: Installs the component using the CLI tool
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#   - TOOL_NAME: Name of the CLI tool (e.g., tridentctl)
#   - TOOL_VERSION: Version of the CLI tool
#
# Optional Environment Variables:
#   - NAMESPACE: Namespace to install the tool into (default: tool-specific default)
#   - HARBOR_HOSTNAME: Harbor registry hostname
#   - INSTALL_OPTIONS: Additional installation options
#   - TOOL_CMD: Command to run (default: install)
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
[[ -z "${TOOL_VERSION}" ]] && { echo "Error: TOOL_VERSION is required"; exit 1; }

# Set defaults for optional variables
NAMESPACE="${NAMESPACE:-}"
TOOL_CMD="${TOOL_CMD:-install}"
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Installing ${TOOL_NAME} version ${TOOL_VERSION} on foundation ${FOUNDATION}"

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

# Create output directory for any results
mkdir -p install-results

# Call the repository's install script with the appropriate arguments
"${REPO_ROOT}/scripts/install.sh" \
  -f "${FOUNDATION}" \
  -t "${TOOL_NAME}" \
  -v "${TOOL_VERSION}" \
  -c "${PWD}/config-repo" \
  ${NAMESPACE:+-n "${NAMESPACE}"} \
  ${HARBOR_HOSTNAME:+-h "${HARBOR_HOSTNAME}"} \
  ${INSTALL_OPTIONS:+-o "${INSTALL_OPTIONS}"} \
  ${TOOL_CMD:+-m "${TOOL_CMD}"} \
  ${VERBOSE:+-V}

echo "Task completed successfully"
