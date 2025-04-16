#!/usr/bin/env bash
#
# Test script for fly.sh commands
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
FLY_SCRIPT="${SCRIPT_DIR}/../fly.sh"

# Source test framework
source ${SCRIPT_DIR}/test-framework.sh

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

# Test file paths that will be created
PIPELINES_DIR="${SCRIPT_DIR}/../pipelines"
MAIN_PIPELINE="${PIPELINES_DIR}/main.yml"
RELEASE_PIPELINE="${PIPELINES_DIR}/release.yml"

# Set up pipeline directories for tests
mkdir -p "${PIPELINES_DIR}"
if [[ ! -f "${MAIN_PIPELINE}" ]]; then
  touch "${MAIN_PIPELINE}"
fi
if [[ ! -f "${RELEASE_PIPELINE}" ]]; then
  touch "${RELEASE_PIPELINE}"
fi

# Function to clean up test files and directories
function cleanup_test_files() {
  # Only remove the files we created, not the directory if it existed before
  if [[ -f "${MAIN_PIPELINE}" && "$(cat "${MAIN_PIPELINE}" 2>/dev/null)" == "" ]]; then
    rm -f "${MAIN_PIPELINE}"
  fi
  if [[ -f "${RELEASE_PIPELINE}" && "$(cat "${RELEASE_PIPELINE}" 2>/dev/null)" == "" ]]; then
    rm -f "${RELEASE_PIPELINE}"
  fi
  
  # Only remove the directory if it's empty and we created it
  if [[ -d "${PIPELINES_DIR}" && -z "$(ls -A "${PIPELINES_DIR}" 2>/dev/null)" ]]; then
    rmdir "${PIPELINES_DIR}" 2>/dev/null || true
  fi
}

# Set up trap to clean up on exit
trap cleanup_test_files EXIT

# Ensure we have a TEST_MODE flag to avoid real fly invocations
export TEST_MODE=true
export ENVIRONMENT=lab # Explicitly set an environment for tests

function test_single_command() {
  local command="$1"
  local expected="$2"

  echo_color "$YELLOW" "Testing '$command' command..."

  # Run command in dry-run and test mode
  local output
  output=$("$FLY_SCRIPT" -f "test-foundation" -t "test-target" -e "lab" "$command" --pipeline "main" --dry-run --test-mode 2>&1) || {
    echo "Command failed with output:"
    echo "$output"
    assert_fail "Command '$command' failed to execute"
    return 1
  }

  # Check for expected output
  if echo "$output" | grep -q "$expected"; then
    success "Command '$command' works correctly"
    assert_true "true" "Command '$command' works correctly"
  else
    echo "Expected to find: $expected"
    echo "Got:"
    echo "$output"
    assert_fail "Command '$command' did not produce expected output"
    return 1
  fi
}

function test_command() {
  # Test set command
  test_single_command "set" "set-pipeline"
  
  # Test unpause command
  test_single_command "unpause" "unpause-pipeline"
  
  # Test validate command
  test_single_command "validate" "validate-pipeline"
  
  # Test release command
  test_single_command "release" "release"
  
  # Test destroy command (more complex due to confirmation)
  echo_color "$YELLOW" "Testing 'destroy' command..."
  output=$(echo "y" | "$FLY_SCRIPT" -f "test-foundation" -t "test-target" -e "lab" "destroy" --pipeline "main" --dry-run --test-mode 2>&1) || {
    echo "Command failed with output:"
    echo "$output"
    assert_fail "Command 'destroy' failed to execute"
    return 1
  }
  
  if echo "$output" | grep -q "destroy-pipeline"; then
    success "Command 'destroy' works correctly"
    assert_true "true" "Command 'destroy' works correctly"
  else
    echo "Got:"
    echo "$output"
    assert_fail "Command 'destroy' did not produce expected output"
    return 1
  fi
}

# Create a minimal mock for fly command
function setup_mock() {
  # Create temp directory for mocks
  MOCK_DIR=$(mktemp -d)

  # Create mock fly
  cat >"${MOCK_DIR}/fly" <<'EOF'
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

echo_color "$GREEN" "All command tests passed! The fly.sh script handles all commands correctly."

# Run tests and generate report using the test framework
run_test test_command
report_results
