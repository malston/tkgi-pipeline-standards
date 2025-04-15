#!/usr/bin/env bash
#
# Script: validate.sh
# Description: Validates the installation of a component
#
# Usage: ./validate.sh [options]
#
# Options:
#   -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
#   -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
#   -c, --config-repo PATH        Path to configuration repository
#   -o, --output-dir DIRECTORY    Output directory for validation results
#   -n, --namespace NAMESPACE     Namespace to validate (default: tool-specific)
#   -V, --verbose                 Enable verbose output
#   --help                        Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions if available
source "${__DIR}/helpers.sh"

# Default values
FOUNDATION=""
TOOL_NAME=""
CONFIG_REPO_PATH=""
OUTPUT_DIR="./validation-results"
NAMESPACE=""
VERBOSE=false

# Function to display usage
function show_usage() {
  cat <<EOF
Script: validate.sh
Description: Validates the installation of a component

Usage: ./validate.sh [options]

Options:
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
  -c, --config-repo PATH        Path to configuration repository
  -o, --output-dir DIRECTORY    Output directory for validation results
  -n, --namespace NAMESPACE     Namespace to validate (default: tool-specific)
  -V, --verbose                 Enable verbose output
  --help                        Show this help message
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
    -t|--tool)
      TOOL_NAME="$2"
      shift 2
      ;;
    -c|--config-repo)
      CONFIG_REPO_PATH="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -V|--verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_usage
      ;;
    *)
      error "Unknown option: $1"
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
  error "Foundation not specified. Use -f or --foundation option."
  show_usage
fi

if [[ -z "${TOOL_NAME}" ]]; then
  error "Tool name not specified. Use -t or --tool option."
  show_usage
fi

if [[ -z "${CONFIG_REPO_PATH}" ]]; then
  error "Configuration repository path not specified. Use -c or --config-repo option."
  show_usage
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Set default namespace based on tool
if [[ -z "${NAMESPACE}" ]]; then
  case "${TOOL_NAME}" in
    "tridentctl")
      NAMESPACE="trident"
      ;;
    "istioctl")
      NAMESPACE="istio-system"
      ;;
    *)
      NAMESPACE="default"
      ;;
  esac
  info "Using default namespace for ${TOOL_NAME}: ${NAMESPACE}"
fi

# Initialize validation status
echo "Validation Status for ${TOOL_NAME} on foundation ${FOUNDATION}" > "${OUTPUT_DIR}/validation-status.txt"
echo "Date: $(date)" >> "${OUTPUT_DIR}/validation-status.txt"
echo "---------------------------------------------------" >> "${OUTPUT_DIR}/validation-status.txt"

# Get the list of clusters for the foundation
for CLUSTER in $(get_desired_clusters "${FOUNDATION}" "${CONFIG_REPO_PATH}"); do
  # Check if cluster directory exists
  if [[ ! -d "${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}" ]]; then
    warning "Cluster directory not found for ${CLUSTER}, skipping"
    echo "SKIPPED: ${CLUSTER} - cluster directory not found" >> "${OUTPUT_DIR}/validation-status.txt"
    continue
  fi
  
  # If there is a 'no-<tool>' file, skip this cluster
  if [[ -f "${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}/no-${TOOL_NAME}" ]]; then
    info "Skipping ${CLUSTER} as it has a 'no-${TOOL_NAME}' file"
    echo "SKIPPED: ${CLUSTER} - has no-${TOOL_NAME} flag" >> "${OUTPUT_DIR}/validation-status.txt"
    continue
  fi
  
  # Get cluster file
  cluster_file="${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}/cluster.yml"
  if ! cluster_file=$(check_yaml_file_exists "${cluster_file}"); then
    error "Failed to find cluster file for ${CLUSTER}"
    echo "FAILED: ${CLUSTER} - cluster file not found" >> "${OUTPUT_DIR}/validation-status.txt"
    continue
  fi
  
  # Get cluster external hostname
  external_hostname=$(get_cluster_external_hostname "${cluster_file}")
  if [[ -z "${external_hostname}" ]]; then
    error "Failed to get external hostname for ${CLUSTER}"
    echo "FAILED: ${CLUSTER} - external hostname not found" >> "${OUTPUT_DIR}/validation-status.txt"
    continue
  fi
  
  # Switch context to this cluster
  info "Switching to cluster: ${external_hostname}"
  if ! kubectl config use-context "${external_hostname}"; then
    error "Failed to switch to context ${external_hostname}"
    echo "FAILED: ${CLUSTER} - could not switch kubectl context" >> "${OUTPUT_DIR}/validation-status.txt"
    continue
  fi
  
  # Create cluster output directory
  mkdir -p "${OUTPUT_DIR}/${CLUSTER}"
  
  # Execute validation for the specific tool
  case "${TOOL_NAME}" in
    "tridentctl")
      info "Validating Trident on cluster: ${CLUSTER}"
      
      # Check if trident namespace exists
      if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        error "Trident namespace not found on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - trident namespace not found" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      fi
      
      # Get trident version
      ${TOOL_NAME} version -n "${NAMESPACE}" > "${OUTPUT_DIR}/${CLUSTER}/version.txt" 2>&1 || {
        error "Failed to get Trident version on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - cannot get trident version" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      }
      
      # Get trident status
      ${TOOL_NAME} status -n "${NAMESPACE}" > "${OUTPUT_DIR}/${CLUSTER}/status.txt" 2>&1 || {
        error "Failed to get Trident status on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - cannot get trident status" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      }
      
      # Check if pods are running
      kubectl get pods -n "${NAMESPACE}" -o wide > "${OUTPUT_DIR}/${CLUSTER}/pods.txt" 2>&1 || {
        error "Failed to get Trident pods on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - cannot get trident pods" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      }
      
      # Check if all pods are running
      if grep -q "Running" "${OUTPUT_DIR}/${CLUSTER}/pods.txt"; then
        # Check backends if available
        ${TOOL_NAME} get backend -n "${NAMESPACE}" > "${OUTPUT_DIR}/${CLUSTER}/backends.txt" 2>&1 || {
          warning "Failed to get Trident backends on cluster ${CLUSTER}"
        }
        
        # Check storage classes
        kubectl get storageclass > "${OUTPUT_DIR}/${CLUSTER}/storageclasses.txt" 2>&1 || {
          warning "Failed to get storage classes on cluster ${CLUSTER}"
        }
        
        # Validation passed
        info "Trident validation successful on cluster ${CLUSTER}"
        echo "PASSED: ${CLUSTER} - trident is healthy" >> "${OUTPUT_DIR}/validation-status.txt"
      else
        error "Trident pods not in Running state on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - trident pods not running" >> "${OUTPUT_DIR}/validation-status.txt"
      fi
      ;;
      
    "istioctl")
      info "Validating Istio on cluster: ${CLUSTER}"
      
      # Check if istio namespace exists
      if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        error "Istio namespace not found on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - istio namespace not found" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      }
      
      # Verify Istio installation
      ${TOOL_NAME} verify-install > "${OUTPUT_DIR}/${CLUSTER}/verify-install.txt" 2>&1 || {
        error "Istio verification failed on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - istio verification failed" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      }
      
      # Check if pods are running
      kubectl get pods -n "${NAMESPACE}" -o wide > "${OUTPUT_DIR}/${CLUSTER}/pods.txt" 2>&1 || {
        error "Failed to get Istio pods on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - cannot get istio pods" >> "${OUTPUT_DIR}/validation-status.txt"
        continue
      }
      
      # Check if all pods are running
      if grep -q "Running" "${OUTPUT_DIR}/${CLUSTER}/pods.txt"; then
        # Get services
        kubectl get svc -n "${NAMESPACE}" > "${OUTPUT_DIR}/${CLUSTER}/services.txt" 2>&1 || {
          warning "Failed to get Istio services on cluster ${CLUSTER}"
        }
        
        # Validation passed
        info "Istio validation successful on cluster ${CLUSTER}"
        echo "PASSED: ${CLUSTER} - istio is healthy" >> "${OUTPUT_DIR}/validation-status.txt"
      else
        error "Istio pods not in Running state on cluster ${CLUSTER}"
        echo "FAILED: ${CLUSTER} - istio pods not running" >> "${OUTPUT_DIR}/validation-status.txt"
      fi
      ;;
      
    *)
      error "Unsupported tool: ${TOOL_NAME}"
      echo "FAILED: ${CLUSTER} - unsupported tool ${TOOL_NAME}" >> "${OUTPUT_DIR}/validation-status.txt"
      continue
      ;;
  esac
done

# Summarize validation results
info "Validation completed for all clusters in foundation ${FOUNDATION}"
echo "" >> "${OUTPUT_DIR}/validation-status.txt"
echo "Validation Summary:" >> "${OUTPUT_DIR}/validation-status.txt"
echo "---------------------------------------------------" >> "${OUTPUT_DIR}/validation-status.txt"
grep "PASSED:" "${OUTPUT_DIR}/validation-status.txt" | wc -l | xargs echo "Passed:" >> "${OUTPUT_DIR}/validation-status.txt"
grep "FAILED:" "${OUTPUT_DIR}/validation-status.txt" | wc -l | xargs echo "Failed:" >> "${OUTPUT_DIR}/validation-status.txt"
grep "SKIPPED:" "${OUTPUT_DIR}/validation-status.txt" | wc -l | xargs echo "Skipped:" >> "${OUTPUT_DIR}/validation-status.txt"

# Check if any failures occurred
if grep -q "FAILED:" "${OUTPUT_DIR}/validation-status.txt"; then
  error "Validation failed for some clusters"
  exit 1
else
  success "Validation successful for all applicable clusters"
fi