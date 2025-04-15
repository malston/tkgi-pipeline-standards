#!/usr/bin/env bash
#
# Task: kubectl-apply
# Description: Applies Kubernetes resources to a cluster
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#   - PKS_PASSWORD: PKS/TKGi password
#
# Optional Environment Variables:
#   - KINDS: Comma-separated list of kinds to apply (default: all)
#   - NAMESPACE_LIMIT: Number of namespaces to process (default: 0 = all)
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
[[ -z "${PKS_PASSWORD}" ]] && { echo "Error: PKS_PASSWORD is required"; exit 1; }

# Set defaults for optional variables
KINDS="${KINDS:-all}"
NAMESPACE_LIMIT="${NAMESPACE_LIMIT:-0}"
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Running kubectl-apply task for foundation: ${FOUNDATION}"
echo "Using kinds: ${KINDS}"
if [[ "${NAMESPACE_LIMIT}" -gt 0 ]]; then
  echo "Limiting to ${NAMESPACE_LIMIT} namespaces"
fi

# Call the repository's apply script with the appropriate arguments
"${REPO_ROOT}/scripts/apply.sh" \
  -f "${FOUNDATION}" \
  -p "${PKS_PASSWORD}" \
  -k "${KINDS}" \
  -n "${NAMESPACE_LIMIT}" \
  -m "manifests" \
  ${VERBOSE} && { echo "Kubectl apply successful"; } || { echo "Kubectl apply failed"; exit 1; }

echo "Task completed successfully"