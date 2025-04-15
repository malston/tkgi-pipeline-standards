#!/usr/bin/env bash
#
# Script: apply.sh
# Description: Applies Kubernetes resources to a cluster
#
# Usage: ./apply.sh [options]
#
# Options:
#   -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
#   -p, --password PASSWORD       PKS/TKGi password
#   -k, --kinds KINDS             Comma-separated list of kinds to apply (default: all)
#   -n, --namespace-limit LIMIT   Number of namespaces to process (default: 0 = all)
#   -m, --manifests PATH          Path to manifests directory (default: ./build)
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
HELPERS="${__DIR}/helpers.sh"
if [[ -f "${HELPERS}" ]]; then
  source "${HELPERS}"
fi

# Default values
FOUNDATION=""
PKS_PASSWORD=""
KINDS="all"
NAMESPACE_LIMIT=0
MANIFESTS_DIR="${REPO_ROOT}/build"
VERBOSE=false

# Function to display usage
function show_usage() {
  cat <<EOF
Script: apply.sh
Description: Applies Kubernetes resources to a cluster

Usage: ./apply.sh [options]

Options:
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -p, --password PASSWORD       PKS/TKGi password
  -k, --kinds KINDS             Comma-separated list of kinds to apply (default: all)
  -n, --namespace-limit LIMIT   Number of namespaces to process (default: 0 = all)
  -m, --manifests PATH          Path to manifests directory (default: ./build)
  -v, --verbose                 Enable verbose output
  -h, --help                    Show this help message
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--foundation)
      FOUNDATION="$2"
      shift 2
      ;;
    -p|--password)
      PKS_PASSWORD="$2"
      shift 2
      ;;
    -k|--kinds)
      KINDS="$2"
      shift 2
      ;;
    -n|--namespace-limit)
      NAMESPACE_LIMIT="$2"
      shift 2
      ;;
    -m|--manifests)
      MANIFESTS_DIR="$2"
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
  error "Foundation name not specified. Use -f or --foundation option."
  show_usage
fi

if [[ -z "${PKS_PASSWORD}" ]]; then
  error "PKS/TKGi password not specified. Use -p or --password option."
  show_usage
fi

# Login to PKS/TKGi
function login_to_pks() {
  info "Logging into PKS/TKGi for foundation: ${FOUNDATION}"
  
  # Get PKS/TKGi API URL from foundation
  local pks_api_url
  case "${FOUNDATION}" in
    cml-k8s-n-*)
      pks_api_url="api.pks.cml.vmware.com"
      ;;
    cic-vxrail-n-*)
      pks_api_url="api.pks.cic.vmware.com"
      ;;
    *)
      error "Unknown foundation: ${FOUNDATION}"
      return 1
      ;;
  esac
  
  # Check if tkgi command exists
  if ! check_command_exists "tkgi"; then
    error "tkgi command not found"
    return 1
  fi
  
  # Login to PKS/TKGi
  info "Logging into PKS/TKGi API at ${pks_api_url}"
  tkgi login -a "${pks_api_url}" -u "admin" -p "${PKS_PASSWORD}" -k
  
  # Check login status
  if [[ $? -ne 0 ]]; then
    error "Failed to login to PKS/TKGi API"
    return 1
  fi
  
  success "Successfully logged into PKS/TKGi API"
  return 0
}

# Get cluster credentials
function get_cluster_credentials() {
  local cluster_name="$1"
  
  info "Getting credentials for cluster: ${cluster_name}"
  
  # Check if cluster exists
  if ! tkgi cluster "${cluster_name}" &> /dev/null; then
    error "Cluster not found: ${cluster_name}"
    return 1
  fi
  
  # Get cluster credentials
  tkgi get-credentials "${cluster_name}"
  
  if [[ $? -ne 0 ]]; then
    error "Failed to get credentials for cluster: ${cluster_name}"
    return 1
  fi
  
  success "Successfully retrieved credentials for cluster: ${cluster_name}"
  return 0
}

# Apply manifests to cluster
function apply_manifests() {
  local cluster_name="$1"
  
  info "Applying manifests to cluster: ${cluster_name}"
  
  # Check if manifests directory exists
  if ! validate_directory_exists "${MANIFESTS_DIR}" "Manifests directory"; then
    return 1
  fi
  
  # Get manifest files
  local manifest_files
  manifest_files=$(find "${MANIFESTS_DIR}" -type f -name "*.yaml" -o -name "*.yml" | sort)
  
  if [[ -z "${manifest_files}" ]]; then
    warning "No manifest files found in ${MANIFESTS_DIR}"
    return 0
  fi
  
  # Apply manifests
  local count=0
  for manifest_file in ${manifest_files}; do
    info "Applying manifest: ${manifest_file}"
    
    # If KINDS is specified, filter by kind
    if [[ "${KINDS}" != "all" ]]; then
      # Extract kinds from the manifest
      local kinds_to_apply
      kinds_to_apply=$(grep -i "kind:" "${manifest_file}" | awk '{print tolower($2)}' | tr '\n' ',')
      
      # Check if any of the specified kinds are in the manifest
      local found=false
      IFS=',' read -ra KIND_ARRAY <<< "${KINDS}"
      for kind in "${KIND_ARRAY[@]}"; do
        if [[ "${kinds_to_apply}" == *"${kind}"* ]]; then
          found=true
          break
        fi
      done
      
      if [[ "${found}" == "false" ]]; then
        info "Skipping manifest as it doesn't contain any of the specified kinds: ${KINDS}"
        continue
      fi
    fi
    
    # Apply manifest
    kubectl apply -f "${manifest_file}"
    
    if [[ $? -ne 0 ]]; then
      error "Failed to apply manifest: ${manifest_file}"
      return 1
    fi
    
    ((count++))
    
    # Check if namespace limit is reached
    if [[ "${NAMESPACE_LIMIT}" -gt 0 && "${count}" -ge "${NAMESPACE_LIMIT}" ]]; then
      warning "Namespace limit reached (${NAMESPACE_LIMIT}). Stopping."
      break
    fi
  done
  
  success "Successfully applied ${count} manifests to cluster: ${cluster_name}"
  return 0
}

# Main function
function main() {
  info "Starting apply process for foundation: ${FOUNDATION}"
  
  # Login to PKS/TKGi
  login_to_pks || { error "Failed to login to PKS/TKGi"; exit 1; }
  
  # Get cluster names for the foundation
  local clusters
  clusters=$(tkgi clusters --json | jq -r ".[] | select(.name | startswith(\"${FOUNDATION}\")) | .name")
  
  if [[ -z "${clusters}" ]]; then
    error "No clusters found for foundation: ${FOUNDATION}"
    exit 1
  fi
  
  info "Found clusters for foundation: ${FOUNDATION}"
  echo "${clusters}"
  
  # Process each cluster
  for cluster in ${clusters}; do
    info "Processing cluster: ${cluster}"
    
    # Get cluster credentials
    get_cluster_credentials "${cluster}" || { error "Failed to get credentials for cluster: ${cluster}"; continue; }
    
    # Apply manifests
    apply_manifests "${cluster}" || { error "Failed to apply manifests to cluster: ${cluster}"; continue; }
  done
  
  success "Apply process completed for foundation: ${FOUNDATION}"
}

# Execute main function
main