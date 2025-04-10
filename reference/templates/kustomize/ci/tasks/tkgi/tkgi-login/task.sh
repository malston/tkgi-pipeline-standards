#!/usr/bin/env bash
#
# Task: tkgi-login
# Description: Logs into a TKGi/PKS cluster
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#   - PKS_API_URL: PKS/TKGi API URL
#   - PKS_USER: PKS/TKGi username
#   - PKS_PASSWORD: PKS/TKGi password
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
[[ -z "${PKS_API_URL}" ]] && { echo "Error: PKS_API_URL is required"; exit 1; }
[[ -z "${PKS_USER}" ]] && { echo "Error: PKS_USER is required"; exit 1; }
[[ -z "${PKS_PASSWORD}" ]] && { echo "Error: PKS_PASSWORD is required"; exit 1; }

# Set defaults for optional variables
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Running tkgi-login task for foundation: ${FOUNDATION}"
echo "Logging into PKS/TKGi API at: ${PKS_API_URL}"

# Check if tkgi command exists
if ! command -v tkgi &> /dev/null; then
  echo "Error: tkgi command not found"
  exit 1
fi

# Create output directory
mkdir -p pks-config

# Login to PKS/TKGi
echo "Logging into PKS/TKGi API"
tkgi login -a "${PKS_API_URL}" -u "${PKS_USER}" -p "${PKS_PASSWORD}" -k

# Check login status
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to login to PKS/TKGi API"
  exit 1
fi

# Save clusters information
echo "Retrieving clusters information"
tkgi clusters --json > pks-config/clusters.json

# Filter clusters for this foundation
echo "Filtering clusters for foundation: ${FOUNDATION}"
jq ".[] | select(.name | startswith(\"${FOUNDATION}\"))" pks-config/clusters.json > pks-config/foundation-clusters.json

# Get the first cluster for this foundation
FIRST_CLUSTER=$(jq -r ".[0].name" pks-config/foundation-clusters.json)

if [[ -z "${FIRST_CLUSTER}" || "${FIRST_CLUSTER}" == "null" ]]; then
  echo "Warning: No clusters found for foundation: ${FOUNDATION}"
else
  echo "Getting credentials for cluster: ${FIRST_CLUSTER}"
  tkgi get-credentials "${FIRST_CLUSTER}"
  
  # Export KUBECONFIG
  KUBECONFIG_FILE="$(find ~/.kube -name "config" -o -name "*${FIRST_CLUSTER}*" | head -n 1)"
  if [[ -f "${KUBECONFIG_FILE}" ]]; then
    cp "${KUBECONFIG_FILE}" pks-config/kubeconfig
    echo "KUBECONFIG=${KUBECONFIG_FILE}" > pks-config/environment
    echo "Saved kubeconfig to: pks-config/kubeconfig"
  else
    echo "Warning: Could not find kubeconfig file for cluster: ${FIRST_CLUSTER}"
  fi
fi

# Save PKS/TKGi credentials
cat > pks-config/credentials <<EOF
PKS_API_URL=${PKS_API_URL}
PKS_USER=${PKS_USER}
PKS_PASSWORD=${PKS_PASSWORD}
FOUNDATION=${FOUNDATION}
EOF

echo "Task completed successfully"