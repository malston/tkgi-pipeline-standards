#!/usr/bin/env bash
#
# Script: install.sh
# Description: Installs a component using a CLI tool
#
# Usage: ./install.sh [options]
#
# Options:
#   -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
#   -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
#   -v, --version VERSION         Tool version
#   -c, --config-repo PATH        Path to configuration repository
#   -n, --namespace NAMESPACE     Namespace to install into (default: tool-specific)
#   -h, --harbor HOSTNAME         Harbor registry hostname
#   -o, --options OPTIONS         Additional installation options
#   -m, --mode MODE               Operation mode (install, wipe, etc.)
#   -V, --verbose                 Enable verbose output
#   --help                        Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions if available
source "${__DIR}/helpers.sh"

# Default values
FOUNDATION=""
TOOL_NAME=""
TOOL_VERSION=""
CONFIG_REPO_PATH=""
NAMESPACE=""
HARBOR_HOSTNAME=""
INSTALL_OPTIONS=""
MODE="install"
VERBOSE=false

# Function to display usage
function show_usage() {
  cat <<EOF
Script: install.sh
Description: Installs a component using a CLI tool

Usage: ./install.sh [options]

Options:
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
  -v, --version VERSION         Tool version
  -c, --config-repo PATH        Path to configuration repository
  -n, --namespace NAMESPACE     Namespace to install into (default: tool-specific)
  -h, --harbor HOSTNAME         Harbor registry hostname
  -o, --options OPTIONS         Additional installation options
  -m, --mode MODE               Operation mode (install, wipe, etc.)
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
    -v|--version)
      TOOL_VERSION="$2"
      shift 2
      ;;
    -c|--config-repo)
      CONFIG_REPO_PATH="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -h|--harbor)
      HARBOR_HOSTNAME="$2"
      shift 2
      ;;
    -o|--options)
      INSTALL_OPTIONS="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
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

if [[ -z "${TOOL_VERSION}" ]]; then
  error "Tool version not specified. Use -v or --version option."
  show_usage
fi

if [[ -z "${CONFIG_REPO_PATH}" ]]; then
  error "Configuration repository path not specified. Use -c or --config-repo option."
  show_usage
fi

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

# Get the list of clusters for the foundation
for CLUSTER in $(get_desired_clusters "${FOUNDATION}" "${CONFIG_REPO_PATH}"); do
  # Check if cluster directory exists
  if [[ ! -d "${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}" ]]; then
    warning "Cluster directory not found for ${CLUSTER}, skipping"
    continue
  fi
  
  # If there is a 'no-<tool>' file, skip this cluster
  if [[ -f "${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}/no-${TOOL_NAME}" ]]; then
    info "Skipping ${CLUSTER} as it has a 'no-${TOOL_NAME}' file"
    continue
  fi
  
  # Get cluster file
  cluster_file="${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}/cluster.yml"
  if ! cluster_file=$(check_yaml_file_exists "${cluster_file}"); then
    error "Failed to find cluster file for ${CLUSTER}"
    continue
  fi
  
  # Get cluster external hostname
  external_hostname=$(get_cluster_external_hostname "${cluster_file}")
  if [[ -z "${external_hostname}" ]]; then
    error "Failed to get external hostname for ${CLUSTER}"
    continue
  fi
  
  # Switch context to this cluster
  info "Switching to cluster: ${external_hostname}"
  kubectl config use-context "${external_hostname}" || {
    error "Failed to switch to context ${external_hostname}"
    continue
  }
  
  # Execute the requested operation for the specific tool
  case "${TOOL_NAME}" in
    "tridentctl")
      if [[ "${MODE}" == "install" ]]; then
        info "Installing Trident on cluster: ${CLUSTER}"
        
        # Create namespace if it doesn't exist
        kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
        
        # Determine whether to use CLI or Helm based on configuration
        if [[ "${INSTALL_OPTIONS}" == *"use-cli"* ]]; then
          info "Using tridentctl CLI for installation"
          
          # Build tridentctl install command
          cmd="${TOOL_NAME} install"
          cmd+=" -n ${NAMESPACE}"
          
          # Add image registry if provided
          if [[ -n "${HARBOR_HOSTNAME}" ]]; then
            cmd+=" --image-registry=${HARBOR_HOSTNAME}/netapp"
            cmd+=" --autosupport-image=${HARBOR_HOSTNAME}/netapp/trident-autosupport:${TOOL_VERSION}"
            cmd+=" --trident-image=${HARBOR_HOSTNAME}/netapp/trident:${TOOL_VERSION}"
          fi
          
          # Add standard options for TKGi
          cmd+=" --kubelet-dir=/var/vcap/data/kubelet"
          cmd+=" --image-pull-policy=Always"
          
          # Execute the command
          eval "${cmd}"
        else
          info "Using Helm for Trident installation"
          
          # Check if Helm is installed
          if ! command -v helm &> /dev/null; then
            error "Helm not found, cannot install Trident using Helm"
            continue
          fi
          
          # Build Helm install command
          cmd="helm upgrade -i trident trident/trident/${TOOL_VERSION}/helm/trident-operator"
          cmd+=" --version ${TOOL_VERSION}"
          
          # Add Harbor registry if provided
          if [[ -n "${HARBOR_HOSTNAME}" ]]; then
            cmd+=" --set imageRegistry=${HARBOR_HOSTNAME}/netapp"
            cmd+=" --set tridentAutosupportImage=${HARBOR_HOSTNAME}/netapp/trident-autosupport:${TOOL_VERSION}"
            cmd+=" --set tridentImage=${HARBOR_HOSTNAME}/netapp/trident:${TOOL_VERSION}"
            cmd+=" --set acpImage=${HARBOR_HOSTNAME}/netapp/trident-acp:${TOOL_VERSION}"
          fi
          
          # Add standard options for TKGi
          cmd+=" --set kubeletDir=/var/vcap/data/kubelet"
          cmd+=" --set imagePullPolicy=Always"
          cmd+=" --set excludePodSecurityPolicy=true"
          cmd+=" --set enableACP=true"
          cmd+=" --create-namespace"
          cmd+=" --namespace ${NAMESPACE}"
          cmd+=" --atomic"
          cmd+=" --timeout 5m"
          
          # Execute the command
          eval "${cmd}"
          
          # Show Helm status
          helm status trident -n "${NAMESPACE}"
        fi
      elif [[ "${MODE}" == "wipe" ]]; then
        info "Removing Trident from cluster: ${CLUSTER}"
        
        # Check if Trident namespace exists
        if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
          # Use the appropriate method to remove Trident
          if [[ "${INSTALL_OPTIONS}" == *"use-cli"* ]]; then
            # Try tridentctl uninstall first
            ${TOOL_NAME} uninstall -n "${NAMESPACE}" --all || true
          else
            # Try Helm uninstall first
            helm uninstall trident -n "${NAMESPACE}" || true
          fi
          
          # Clean up any remaining Trident resources
          kubectl delete namespace "${NAMESPACE}" --timeout=5m || true
        else
          info "Trident namespace not found on cluster ${CLUSTER}, nothing to wipe"
        fi
      else
        error "Unknown mode: ${MODE} for tool: ${TOOL_NAME}"
      fi
      ;;
      
    "istioctl")
      if [[ "${MODE}" == "install" ]]; then
        info "Installing Istio on cluster: ${CLUSTER}"
        
        # Create namespace if it doesn't exist
        kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
        
        # Determine the profile to use
        PROFILE="default"
        if [[ -n "${INSTALL_OPTIONS}" ]]; then
          PROFILE="${INSTALL_OPTIONS}"
        fi
        
        # Check for overlay configurations
        CONFIG_ARGS=""
        OVERLAY_PATH="${CONFIG_REPO_PATH}/foundations/${FOUNDATION}/${CLUSTER}/istio/overlay.yaml"
        if [[ -f "${OVERLAY_PATH}" ]]; then
          CONFIG_ARGS="-f ${OVERLAY_PATH}"
        fi
        
        # Install Istio
        ${TOOL_NAME} install --set profile=${PROFILE} ${CONFIG_ARGS} -y
      elif [[ "${MODE}" == "wipe" ]]; then
        info "Removing Istio from cluster: ${CLUSTER}"
        
        # Check if Istio namespace exists
        if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
          # Use istioctl uninstall to remove Istio
          ${TOOL_NAME} uninstall --purge -y
          
          # Clean up namespace
          kubectl delete namespace "${NAMESPACE}" --timeout=5m || true
        else
          info "Istio namespace not found on cluster ${CLUSTER}, nothing to wipe"
        fi
      else
        error "Unknown mode: ${MODE} for tool: ${TOOL_NAME}"
      fi
      ;;
      
    *)
      error "Unsupported tool: ${TOOL_NAME}"
      continue
      ;;
  esac
done

info "${MODE} operation completed for all clusters in foundation ${FOUNDATION}"
