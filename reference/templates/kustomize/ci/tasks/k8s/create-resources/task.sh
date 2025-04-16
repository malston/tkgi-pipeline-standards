#!/usr/bin/env bash

set -o errexit
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${SCRIPT_DIR}/../../../scripts/helpers.sh"

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

info "Creating Kubernetes resources for namespace $NAMESPACE in foundation $FOUNDATION"

# Validate manifests directory
if [[ ! -d "manifests" ]]; then
  error "Manifests directory not found"
  exit 1
fi

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  info "Creating namespace: $NAMESPACE"
  kubectl create namespace "$NAMESPACE"
else
  info "Namespace $NAMESPACE already exists"
fi

# Apply all manifests
find manifests -name "*.yaml" -o -name "*.yml" | sort | while read -r manifest; do
  info "Applying manifest: $(basename "$manifest")"
  kubectl apply -f "$manifest" -n "$NAMESPACE"
done

# Label the namespace
info "Adding standard labels to namespace $NAMESPACE"
kubectl label namespace "$NAMESPACE" \
  foundation="$FOUNDATION" \
  managed-by=pipeline \
  --overwrite=true

success "Successfully created Kubernetes resources for namespace $NAMESPACE"
