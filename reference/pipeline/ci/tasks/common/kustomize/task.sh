#!/usr/bin/env bash
#
# Task: kustomize
# Description: Builds Kubernetes resources using kustomize
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#
# Optional Environment Variables:
#   - FOUNDATION_PATH: Path within config repo to foundation (default: foundations/${FOUNDATION})
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
FOUNDATION_PATH="${FOUNDATION_PATH:-foundations/${FOUNDATION}}"
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Running kustomize task for foundation: ${FOUNDATION}"
echo "Using foundation path: ${FOUNDATION_PATH}"

# Call the repository's build script with the appropriate arguments
"${REPO_ROOT}/scripts/build.sh" \
  -f "${FOUNDATION}" \
  -c "config/${FOUNDATION_PATH}" \
  ${VERBOSE} && { echo "Kustomize build successful"; } || { echo "Kustomize build failed"; exit 1; }

# Ensure the manifests directory exists and contains output
mkdir -p manifests
cp -r "${REPO_ROOT}/build/"* manifests/

echo "Task completed successfully"