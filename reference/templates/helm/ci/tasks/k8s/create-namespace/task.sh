#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../scripts/helpers.sh"

# Set up TKGi credentials from previous step
setup_tkgi_credentials

# Validate required parameters
validate_env "FOUNDATION" "NAMESPACE"

info "Creating namespace $NAMESPACE in foundation $FOUNDATION"

# Create namespace if it doesn't exist
create_namespace_if_not_exists "$NAMESPACE"

# Label the namespace for monitoring, logging, etc.
info "Adding labels to namespace $NAMESPACE"
kubectl label namespace "$NAMESPACE" \
  app.kubernetes.io/name=gatekeeper \
  app.kubernetes.io/part-of=gatekeeper-system \
  app.kubernetes.io/managed-by=helm \
  --overwrite=true

info "Namespace $NAMESPACE created and labeled successfully"