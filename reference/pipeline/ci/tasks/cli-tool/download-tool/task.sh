#!/usr/bin/env bash
#
# Task: download-tool
# Description: Downloads and prepares the CLI tool for use
#
# Required Environment Variables:
#   - TOOL_NAME: Name of the CLI tool (e.g., tridentctl)
#   - TOOL_VERSION: Version of the CLI tool to download
#
# Optional Environment Variables:
#   - DOWNLOAD_URL: URL to download the tool (if not using built-in logic)
#   - HARBOR_HOSTNAME: Harbor registry hostname (for container images)
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
[[ -z "${TOOL_NAME}" ]] && { echo "Error: TOOL_NAME is required"; exit 1; }
[[ -z "${TOOL_VERSION}" ]] && { echo "Error: TOOL_VERSION is required"; exit 1; }

# Set defaults for optional variables
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Downloading ${TOOL_NAME} version ${TOOL_VERSION}"

# Create output directory
mkdir -p cli-tool-bin

# Call the repository's download script with the appropriate arguments
"${REPO_ROOT}/scripts/download.sh" \
  -t "${TOOL_NAME}" \
  -v "${TOOL_VERSION}" \
  -o "cli-tool-bin" \
  ${DOWNLOAD_URL:+-u "${DOWNLOAD_URL}"} \
  ${HARBOR_HOSTNAME:+-h "${HARBOR_HOSTNAME}"} \
  ${VERBOSE:+-V}

# Verify the tool was downloaded successfully
if [[ -f "cli-tool-bin/${TOOL_NAME}" ]]; then
  echo "Tool ${TOOL_NAME} v${TOOL_VERSION} downloaded successfully"
else
  echo "Error: Failed to download ${TOOL_NAME}"
  exit 1
fi

# Make the tool executable
chmod +x cli-tool-bin/${TOOL_NAME}

# Add the tool to PATH and verify it works
export PATH="${PWD}/cli-tool-bin:${PATH}"
if ! command -v "${TOOL_NAME}" &> /dev/null; then
  echo "Error: ${TOOL_NAME} not found in PATH"
  exit 1
fi

# Try to get the version (if the tool supports it)
echo "Verifying ${TOOL_NAME} version:"
${TOOL_NAME} version 2>/dev/null || ${TOOL_NAME} --version 2>/dev/null || echo "Note: ${TOOL_NAME} does not support version checking"

echo "Task completed successfully"