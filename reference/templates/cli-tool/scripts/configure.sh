#!/usr/bin/env bash
#
# Script: configure.sh
# Description: Configures a component after installation
#
# Usage: ./configure.sh [options]
#
# Options:
#   -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
#   -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
#   -c, --config-path PATH        Path to configuration files
#   -o, --output-dir DIRECTORY    Output directory for results
#   -n, --namespace NAMESPACE     Namespace to configure (default: tool-specific)
#   -O, --options OPTIONS         Additional configuration options
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
CONFIG_PATH=""
OUTPUT_DIR="./config-results"
NAMESPACE=""
CONFIG_OPTIONS=""
VERBOSE=false

# Function to display usage
function show_usage() {
  cat <<EOF
Script: configure.sh
Description: Configures a component after installation

Usage: ./configure.sh [options]

Options:
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
  -c, --config-path PATH        Path to configuration files
  -o, --output-dir DIRECTORY    Output directory for results
  -n, --namespace NAMESPACE     Namespace to configure (default: tool-specific)
  -O, --options OPTIONS         Additional configuration options
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
    -c|--config-path)
      CONFIG_PATH="$2"
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
    -O|--options)
      CONFIG_OPTIONS="$2"
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

if [[ -z "${CONFIG_PATH}" ]]; then
  error "Configuration path not specified. Use -c or --config-path option."
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

# Initialize configuration status
echo "Configuration Status for ${TOOL_NAME} on foundation ${FOUNDATION}" > "${OUTPUT_DIR}/config-status.txt"
echo "Date: $(date)" >> "${OUTPUT_DIR}/config-status.txt"
echo "---------------------------------------------------" >> "${OUTPUT_DIR}/config-status.txt"

# Get the list of clusters for the foundation
for CLUSTER in $(get_desired_clusters "${FOUNDATION}" "${CONFIG_PATH%/*}"); do
  # Check if cluster directory exists
  if [[ ! -d "${CONFIG_PATH%/*}/${CLUSTER}" ]]; then
    warning "Cluster directory not found for ${CLUSTER}, skipping"
    echo "SKIPPED: ${CLUSTER} - cluster directory not found" >> "${OUTPUT_DIR}/config-status.txt"
    continue
  fi
  
  # If there is a 'no-<tool>' file, skip this cluster
  if [[ -f "${CONFIG_PATH%/*}/${CLUSTER}/no-${TOOL_NAME}" ]]; then
    info "Skipping ${CLUSTER} as it has a 'no-${TOOL_NAME}' file"
    echo "SKIPPED: ${CLUSTER} - has no-${TOOL_NAME} flag" >> "${OUTPUT_DIR}/config-status.txt"
    continue
  fi
  
  # Get cluster file
  cluster_file="${CONFIG_PATH%/*}/${CLUSTER}/cluster.yml"
  if ! cluster_file=$(check_yaml_file_exists "${cluster_file}"); then
    error "Failed to find cluster file for ${CLUSTER}"
    echo "FAILED: ${CLUSTER} - cluster file not found" >> "${OUTPUT_DIR}/config-status.txt"
    continue
  fi
  
  # Get cluster external hostname
  external_hostname=$(get_cluster_external_hostname "${cluster_file}")
  if [[ -z "${external_hostname}" ]]; then
    error "Failed to get external hostname for ${CLUSTER}"
    echo "FAILED: ${CLUSTER} - external hostname not found" >> "${OUTPUT_DIR}/config-status.txt"
    continue
  fi
  
  # Switch context to this cluster
  info "Switching to cluster: ${external_hostname}"
  if ! kubectl config use-context "${external_hostname}"; then
    error "Failed to switch to context ${external_hostname}"
    echo "FAILED: ${CLUSTER} - could not switch kubectl context" >> "${OUTPUT_DIR}/config-status.txt"
    continue
  fi
  
  # Create cluster output directory
  mkdir -p "${OUTPUT_DIR}/${CLUSTER}"
  
  # Check tool namespace exists
  if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    error "Namespace ${NAMESPACE} not found on cluster ${CLUSTER}"
    echo "FAILED: ${CLUSTER} - namespace ${NAMESPACE} not found" >> "${OUTPUT_DIR}/config-status.txt"
    continue
  fi
  
  # Execute configuration for the specific tool
  case "${TOOL_NAME}" in
    "tridentctl")
      info "Configuring Trident on cluster: ${CLUSTER}"
      
      # Check for backend configuration files
      BACKEND_FILES=$(find "${CONFIG_PATH}/${CLUSTER}" -name "*backend*.json" -o -name "*backend*.yaml" -o -name "*backend*.yml" 2>/dev/null || echo "")
      if [[ -z "${BACKEND_FILES}" ]]; then
        warning "No backend configuration files found for cluster ${CLUSTER}"
        echo "SKIPPED: ${CLUSTER} - no backend configurations found" >> "${OUTPUT_DIR}/config-status.txt"
      else
        # Process each backend file
        for backend_file in ${BACKEND_FILES}; do
          backend_name=$(basename "${backend_file}" | sed 's/\.[^.]*$//')
          info "Creating backend ${backend_name} from ${backend_file}"
          
          # Create the backend
          ${TOOL_NAME} create backend -f "${backend_file}" -n "${NAMESPACE}" > "${OUTPUT_DIR}/${CLUSTER}/backend-${backend_name}.txt" 2>&1 || {
            error "Failed to create backend ${backend_name} on cluster ${CLUSTER}"
            echo "FAILED: ${CLUSTER} - backend ${backend_name} creation failed" >> "${OUTPUT_DIR}/config-status.txt"
            continue
          }
          
          info "Backend ${backend_name} created successfully"
        done
      fi
      
      # Check for storage class configuration files
      SC_FILES=$(find "${CONFIG_PATH}/${CLUSTER}" -name "*storageclass*.yaml" -o -name "*storageclass*.yml" -o -name "*sc*.yaml" -o -name "*sc*.yml" 2>/dev/null || echo "")
      if [[ -z "${SC_FILES}" ]]; then
        warning "No storage class configuration files found for cluster ${CLUSTER}"
      else
        # Process each storage class file
        for sc_file in ${SC_FILES}; do
          sc_name=$(grep -i "name:" "${sc_file}" | head -1 | awk '{print $2}')
          info "Creating storage class ${sc_name} from ${sc_file}"
          
          # Create the storage class
          kubectl apply -f "${sc_file}" > "${OUTPUT_DIR}/${CLUSTER}/sc-${sc_name}.txt" 2>&1 || {
            error "Failed to create storage class ${sc_name} on cluster ${CLUSTER}"
            echo "FAILED: ${CLUSTER} - storage class ${sc_name} creation failed" >> "${OUTPUT_DIR}/config-status.txt"
            continue
          }
          
          info "Storage class ${sc_name} created successfully"
          
          # Set default storage class if specified
          if [[ "${CONFIG_OPTIONS}" == *"default-sc=${sc_name}"* ]]; then
            info "Setting ${sc_name} as default storage class"
            
            # Remove default from any existing storage classes
            kubectl get storageclass -o name | xargs -I{} kubectl patch {} -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
            
            # Set this one as default
            kubectl patch storageclass "${sc_name}" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
          fi
        done
      fi
      
      # Configuration completed successfully
      echo "PASSED: ${CLUSTER} - trident configured successfully" >> "${OUTPUT_DIR}/config-status.txt"
      ;;
      
    "istioctl")
      info "Configuring Istio on cluster: ${CLUSTER}"
      
      # Check for Istio overlay files
      OVERLAY_FILES=$(find "${CONFIG_PATH}/${CLUSTER}" -name "*overlay*.yaml" -o -name "*overlay*.yml" 2>/dev/null || echo "")
      if [[ -z "${OVERLAY_FILES}" ]]; then
        warning "No Istio overlay files found for cluster ${CLUSTER}"
      else
        # Apply configuration from overlay files
        for overlay_file in ${OVERLAY_FILES}; then
          overlay_name=$(basename "${overlay_file}" | sed 's/\.[^.]*$//')
          info "Applying Istio overlay ${overlay_name} from ${overlay_file}"
          
          # Apply the overlay
          ${TOOL_NAME} apply -f "${overlay_file}" > "${OUTPUT_DIR}/${CLUSTER}/overlay-${overlay_name}.txt" 2>&1 || {
            error "Failed to apply Istio overlay ${overlay_name} on cluster ${CLUSTER}"
            echo "FAILED: ${CLUSTER} - istio overlay ${overlay_name} application failed" >> "${OUTPUT_DIR}/config-status.txt"
            continue
          }
          
          info "Istio overlay ${overlay_name} applied successfully"
        done
      fi
      
      # Check for gateway configurations
      GATEWAY_FILES=$(find "${CONFIG_PATH}/${CLUSTER}" -name "*gateway*.yaml" -o -name "*gateway*.yml" 2>/dev/null || echo "")
      if [[ -z "${GATEWAY_FILES}" ]]; then
        warning "No gateway configuration files found for cluster ${CLUSTER}"
      else
        # Apply gateway configurations
        for gateway_file in ${GATEWAY_FILES}; do
          gateway_name=$(grep -i "name:" "${gateway_file}" | head -1 | awk '{print $2}')
          info "Creating gateway ${gateway_name} from ${gateway_file}"
          
          # Create the gateway
          kubectl apply -f "${gateway_file}" > "${OUTPUT_DIR}/${CLUSTER}/gateway-${gateway_name}.txt" 2>&1 || {
            error "Failed to create gateway ${gateway_name} on cluster ${CLUSTER}"
            echo "FAILED: ${CLUSTER} - gateway ${gateway_name} creation failed" >> "${OUTPUT_DIR}/config-status.txt"
            continue
          }
          
          info "Gateway ${gateway_name} created successfully"
        done
      fi
      
      # Configuration completed successfully
      echo "PASSED: ${CLUSTER} - istio configured successfully" >> "${OUTPUT_DIR}/config-status.txt"
      ;;
      
    *)
      error "Unsupported tool: ${TOOL_NAME}"
      echo "FAILED: ${CLUSTER} - unsupported tool ${TOOL_NAME}" >> "${OUTPUT_DIR}/config-status.txt"
      continue
      ;;
  esac
done

# Summarize configuration results
info "Configuration completed for all clusters in foundation ${FOUNDATION}"
echo "" >> "${OUTPUT_DIR}/config-status.txt"
echo "Configuration Summary:" >> "${OUTPUT_DIR}/config-status.txt"
echo "---------------------------------------------------" >> "${OUTPUT_DIR}/config-status.txt"
grep "PASSED:" "${OUTPUT_DIR}/config-status.txt" | wc -l | xargs echo "Passed:" >> "${OUTPUT_DIR}/config-status.txt"
grep "FAILED:" "${OUTPUT_DIR}/config-status.txt" | wc -l | xargs echo "Failed:" >> "${OUTPUT_DIR}/config-status.txt"
grep "SKIPPED:" "${OUTPUT_DIR}/config-status.txt" | wc -l | xargs echo "Skipped:" >> "${OUTPUT_DIR}/config-status.txt"

# Check if any failures occurred
if grep -q "FAILED:" "${OUTPUT_DIR}/config-status.txt"; then
  error "Configuration failed for some clusters"
  exit 1
else
  success "Configuration successful for all applicable clusters"
fi