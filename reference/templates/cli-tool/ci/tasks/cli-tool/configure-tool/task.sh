#!/usr/bin/env bash
#
# Task: configure-tool
# Description: Configures the component after installation
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#   - TOOL_NAME: Name of the CLI tool (e.g., tridentctl)
#
# Optional Environment Variables:
#   - NAMESPACE: Namespace to configure (default: tool-specific default)
#   - CONFIG_PATH: Path to configuration files
#   - CONFIG_OPTIONS: Additional configuration options
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
[[ -z "${TOOL_NAME}" ]] && { echo "Error: TOOL_NAME is required"; exit 1; }

# Set defaults for optional variables
NAMESPACE="${NAMESPACE:-}"
CONFIG_PATH="${CONFIG_PATH:-}"
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Configuring ${TOOL_NAME} on foundation ${FOUNDATION}"

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

# Determine the configuration path if not provided
if [[ -z "${CONFIG_PATH}" ]]; then
  CONFIG_PATH="${PWD}/config-repo/foundations/${FOUNDATION}/${TOOL_NAME}-config"
  echo "Using default config path: ${CONFIG_PATH}"
fi

# Create output directory for any results
mkdir -p config-results

# Call the repository's configure script with the appropriate arguments
"${REPO_ROOT}/scripts/configure.sh" \
  -f "${FOUNDATION}" \
  -t "${TOOL_NAME}" \
  -c "${CONFIG_PATH}" \
  -o "${PWD}/config-results" \
  ${NAMESPACE:+-n "${NAMESPACE}"} \
  ${CONFIG_OPTIONS:+-O "${CONFIG_OPTIONS}"} \
  ${VERBOSE:+-V}

echo "Task completed successfully"