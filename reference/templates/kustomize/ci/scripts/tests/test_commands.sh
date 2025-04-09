#!/usr/bin/env bash
#
# Test script for fly.sh commands
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
  echo_color "$GREEN" "✓ $1"
}

function error() {
  echo_color "$RED" "✗ $1"
  exit 1
}

# Set up pipeline directories for tests
mkdir -p "${SCRIPT_DIR}/../pipelines"
if [[ ! -f "${SCRIPT_DIR}/../pipelines/main.yml" ]]; then
  touch "${SCRIPT_DIR}/../pipelines/main.yml"
fi
if [[ ! -f "${SCRIPT_DIR}/../pipelines/release.yml" ]]; then
  touch "${SCRIPT_DIR}/../pipelines/release.yml"
fi

# Ensure we have a TEST_MODE flag to avoid real fly invocations
export TEST_MODE=true

function test_command() {
  local command="$1"
  local expected="$2"

  echo_color "$YELLOW" "Testing '$command' command..."

  # Run command in dry-run and test mode
  local output
  output=$("$FLY_SCRIPT" -f "test-foundation" -t "test-target" "$command" --pipeline "main" --dry-run --test-mode 2>&1) || {
    echo "Command failed with output:"
    echo "$output"
    error "Command '$command' failed to execute"
  }

  # Check for expected output
  if echo "$output" | grep -q "$expected"; then
    success "Command '$command' works correctly"
  else
    error "Command '$command' did not produce expected output"
    echo "Expected to find: $expected"
    echo "Got:"
    echo "$output"
  fi
}

# Create a minimal mock for fly command
function setup_mock() {
  # Create temp directory for mocks
  MOCK_DIR=$(mktemp -d)
  
  # Create mock fly
  cat > "${MOCK_DIR}/fly" << 'EOF'
#!/usr/bin/env bash
echo "FLY: $@"
if [[ "$1" == "targets" ]]; then
  echo "name            url                   team  expiry"
  echo "----            ---                   ----  -----"
  echo "test-target     https://example.com   main  n/a"
fi
exit 0
EOF
  chmod +x "${MOCK_DIR}/fly"
  
  # Add to PATH
  export PATH="${MOCK_DIR}:${PATH}"
}

# Set up the mock
setup_mock

# Main tests
echo "Testing all fly.sh commands..."

# Test set command
test_command "set" "set-pipeline"

# Test unpause command
test_command "unpause" "unpause-pipeline"

# Test validate command
test_command "validate" "validate-pipeline"

# Test release command
test_command "release" "release"

# Test destroy command (more complex due to confirmation)
echo_color "$YELLOW" "Testing 'destroy' command..."
output=$(echo "yes" | "$FLY_SCRIPT" -f "test-foundation" -t "test-target" "destroy" --pipeline "main" --dry-run --test-mode 2>&1) || {
  echo "Command failed with output:"
  echo "$output"
  error "Command 'destroy' failed to execute"
}

if echo "$output" | grep -q "destroy-pipeline"; then
  success "Command 'destroy' works correctly"
else
  error "Command 'destroy' did not produce expected output"
  echo "Got:"
  echo "$output"
fi

echo_color "$GREEN" "All command tests passed! The fly.sh script handles all commands correctly."
exit 0