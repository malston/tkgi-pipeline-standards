#!/usr/bin/env bash
#
# Test script to verify debug logging
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CI_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

# Source the logging functions
source "${CI_DIR}/lib/utils.sh"

# Enable debug mode
DEBUG=true

# Log different message types
info "This is an info message from line $LINENO"
error "This is an error message from line $LINENO"
success "This is a success message from line $LINENO"

# Exit gracefully
exit 0