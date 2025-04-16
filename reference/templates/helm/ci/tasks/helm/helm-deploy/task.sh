#!/usr/bin/env bash
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
if [[ -f "${__DIR}/../../../scripts/helpers.sh" ]]; then
  source "${__DIR}/../../../scripts/helpers.sh"
else
  echo "Helper script not found at ${__DIR}/../../../scripts/helpers.sh"
  exit 1
fi

# Set up TKGi credentials from previous step
setup_tkgi_credentials

# Validate required parameters
validate_env "FOUNDATION" "NAMESPACE" "RELEASE_NAME" "CHART_PATH"

# Handle dry run mode
if [[ "$PIPELINE_DRY_RUN" == "true" ]]; then
  info "DRY RUN mode - would have deployed Helm chart $CHART_PATH as $RELEASE_NAME to $NAMESPACE in foundation $FOUNDATION"
  exit 0
fi

info "Deploying Helm chart $CHART_PATH as $RELEASE_NAME to $NAMESPACE in foundation $FOUNDATION"

# Make sure helm is available
ensure_helm

# Set up Helm command parameters
HELM_ARGS=""

# Add values file if specified
if [[ -n $VALUES_FILE && -f $VALUES_FILE ]]; then
  HELM_ARGS="$HELM_ARGS --values $VALUES_FILE"
  info "Using values file: $VALUES_FILE"
else
  info "No values file specified or file not found, using chart defaults"
fi

# Add timeout if specified
if [[ -n $TIMEOUT ]]; then
  HELM_ARGS="$HELM_ARGS --timeout $TIMEOUT"
  info "Using timeout: $TIMEOUT"
fi

# If version is specified, use it for specific Gatekeeper version
if [[ -n $GATEKEEPER_VERSION ]]; then
  HELM_ARGS="$HELM_ARGS --set image.release=$GATEKEEPER_VERSION"
  info "Setting Gatekeeper version: $GATEKEEPER_VERSION"
fi

# Make sure namespace exists
create_namespace_if_not_exists "$NAMESPACE"

# Execute Helm upgrade/install
if ! helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  $HELM_ARGS \
  --atomic \
  --wait; then
  error "Helm deployment failed"
  exit 1
fi

info "Helm deployment completed successfully"

# Display deployed Helm release
info "Deployed Helm release details:"
helm status "$RELEASE_NAME" -n "$NAMESPACE"
