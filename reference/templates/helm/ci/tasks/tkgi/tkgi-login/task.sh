#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../scripts/helpers.sh"

# Validate required parameters
validate_env "PKS_API_URL" "PKS_USER" "PKS_PASSWORD" "FOUNDATION"

# Set TLS verification flag
TLS_VERIFICATION=""
if [[ "$SKIP_TLS_VERIFICATION" == "true" ]]; then
  TLS_VERIFICATION="-k"
fi

info "Logging into TKGI API: $PKS_API_URL"
if ! tkgi login -a "$PKS_API_URL" -u "$PKS_USER" -p "$PKS_PASSWORD" $TLS_VERIFICATION; then
  error "Failed to log in to TKGI API"
  exit 1
fi

# Save credentials for downstream tasks
mkdir -p pks-config
cat > pks-config/creds.yml <<EOF
foundation: $FOUNDATION
pks_api_url: $PKS_API_URL
pks_user: $PKS_USER
pks_password: $PKS_PASSWORD
skip_tls_verification: $SKIP_TLS_VERIFICATION
EOF

info "TKGI login successful, credentials saved for downstream tasks"