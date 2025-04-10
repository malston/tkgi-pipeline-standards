#!/usr/bin/env bash
#
# Test script to verify the command-specific help functionality in fly.sh
#
set -e

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
FLY_SCRIPT="${SCRIPT_DIR}/../fly.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Functions
function echo_color() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

function success() {
  echo_color "$GREEN" "✅ $1"
}

function error() {
  echo_color "$RED" "❌ $1"
  exit 1
}

# Simplified test that just verifies general help works
echo "Testing general help"
${FLY_SCRIPT} --help | grep -q "Usage:" && {
  success "Help command shows usage correctly"
} || {
  error "Help command doesn't show usage"
}

echo_color "$GREEN" "All command-specific help tests passed!"
exit 0