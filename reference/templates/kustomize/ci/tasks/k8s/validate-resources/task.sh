#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../scripts/helpers.sh"

# Validate required parameters
validate_env "FOUNDATION" "NAMESPACE"

# Setup TKGI credentials if provided
if [[ -f "pks-config/credentials" ]]; then
  source pks-config/credentials
  
  # Login to TKGI if credentials provided
  if [[ -n "$PKS_API_URL" && -n "$PKS_USER" && -n "$PKS_PASSWORD" ]]; then
    info "Logging into TKGI API: $PKS_API_URL"
    
    # Set TLS verification flag
    TLS_VERIFICATION=""
    if [[ "$SKIP_TLS_VERIFICATION" == "true" ]]; then
      TLS_VERIFICATION="-k"
    fi
    
    tkgi login -a "$PKS_API_URL" -u "$PKS_USER" -p "$PKS_PASSWORD" $TLS_VERIFICATION
  fi
fi

# Check that kube config exists
if [[ ! -f ~/.kube/config ]]; then
  error "No Kubernetes configuration found. Make sure you're logged into the cluster."
  exit 1
fi

info "Validating Kubernetes resources in namespace $NAMESPACE"

# Make sure the namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  error "Namespace $NAMESPACE does not exist in the cluster"
  exit 1
fi

# Validate manifests directory
if [[ ! -d "manifests" ]]; then
  error "Manifests directory not found"
  exit 1
fi

# Define validation functions
function validate_namespace_resources() {
  local namespace="$1"
  
  # Check deployment resources
  local deployments
  deployments=$(kubectl get deployments -n "$namespace" -o name 2>/dev/null || echo "")
  
  if [[ -n "$deployments" ]]; then
    info "Found deployments in namespace $namespace:"
    echo "$deployments" | while read -r deployment; do
      deployment_name=$(echo "$deployment" | cut -d'/' -f2)
      ready_status=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
      
      if [[ "$ready_status" == "True" ]]; then
        success "✓ Deployment $deployment_name is available"
      else
        warning "! Deployment $deployment_name is not available"
        kubectl describe deployment "$deployment_name" -n "$namespace"
      fi
    done
  else
    info "No deployments found in namespace $namespace"
  fi
  
  # Check service resources
  local services
  services=$(kubectl get services -n "$namespace" -o name 2>/dev/null || echo "")
  
  if [[ -n "$services" ]]; then
    info "Found services in namespace $namespace:"
    echo "$services"
  else
    info "No services found in namespace $namespace"
  fi
  
  # Check configmap resources
  local configmaps
  configmaps=$(kubectl get configmaps -n "$namespace" -o name 2>/dev/null || echo "")
  
  if [[ -n "$configmaps" ]]; then
    info "Found configmaps in namespace $namespace:"
    echo "$configmaps"
  else
    info "No configmaps found in namespace $namespace"
  fi
  
  return 0
}

# Validate resources
validate_namespace_resources "$NAMESPACE"

success "Validation of namespace $NAMESPACE completed"