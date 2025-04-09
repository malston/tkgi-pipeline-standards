#!/usr/bin/env bash
#
# Simple test framework for bash scripts
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
__SCRIPTS_DIR="$(cd "${__TEST_DIR}/.." &>/dev/null && pwd)"

# Functions
function echo_color() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

function info() {
  echo_color "$YELLOW" "INFO: $1"
}

function success() {
  echo_color "$GREEN" "SUCCESS: $1"
}

function error() {
  echo_color "$RED" "ERROR: $1" >&2
}

function start_test() {
  local test_name="$1"
  echo
  echo_color "$YELLOW" "=== Running test: $test_name ==="
  ((TESTS_TOTAL++))
}

function test_pass() {
  local test_name="$1"
  success "Test passed: $test_name"
  ((TESTS_PASSED++))
}

function test_fail() {
  local test_name="$1"
  local message="$2"
  error "Test failed: $test_name"
  error "Reason: $message"
  ((TESTS_FAILED++))
}

function assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected' but got '$actual'}"
  
  if [[ "$expected" != "$actual" ]]; then
    test_fail "equals assertion" "$message"
    return 1
  fi
  return 0
}

function assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected '$haystack' to contain '$needle'"}"
  
  if ! echo "$haystack" | grep -q "$needle"; then
    test_fail "contains assertion" "$message"
    return 1
  fi
  return 0
}

function assert_exit_code() {
  local command="$1"
  local expected_code="$2"
  local message="${3:-Expected exit code $expected_code}"
  
  local exit_code=0
  eval "$command" >/dev/null 2>&1 || exit_code=$?
  
  if [[ "$exit_code" != "$expected_code" ]]; then
    test_fail "exit code assertion" "$message (got $exit_code)"
    return 1
  fi
  return 0
}

function report_results() {
  echo
  echo "=== Test Results ==="
  echo "Total tests: $TESTS_TOTAL"
  echo_color "$GREEN" "Passed: $TESTS_PASSED"
  if [[ "$TESTS_FAILED" -gt 0 ]]; then
    echo_color "$RED" "Failed: $TESTS_FAILED"
    return 1
  else
    echo_color "$GREEN" "All tests passed!"
    return 0
  fi
}

# Mock functions for testing
function mock_fly() {
  # Mock the fly CLI for testing
  # Usage: mock_fly <command> <expected_arguments> [exit_code]
  local command="$1"
  local expected_args="$2"
  local exit_code="${3:-0}"
  
  # Create a temporary mock script
  cat > "${__TEST_DIR}/.fly_mock" <<EOF
#!/usr/bin/env bash
# This is a temporary mock for fly

# Log the command and arguments
echo "\$@" > "${__TEST_DIR}/.fly_last_command"

# Check if this is the command we're expecting
if [[ "\$1" == "$command" ]]; then
  # Check if arguments match what we expect
  args="\${@:2}"
  if [[ "\$args" == *"$expected_args"* ]]; then
    exit $exit_code
  fi
fi

# For testing other commands or argument patterns
exit $exit_code
EOF
  
  chmod +x "${__TEST_DIR}/.fly_mock"
  
  # Override PATH to use our mock
  export PATH="${__TEST_DIR}:${PATH}"
  ln -sf "${__TEST_DIR}/.fly_mock" "${__TEST_DIR}/fly"
}

function cleanup_mocks() {
  # Remove any mock files
  rm -f "${__TEST_DIR}/.fly_mock" "${__TEST_DIR}/fly" "${__TEST_DIR}/.fly_last_command"
}

# Setup and teardown hooks
function test_setup() {
  # Called before each test
  :
}

function test_teardown() {
  # Called after each test
  cleanup_mocks
}

function run_test() {
  local test_func="$1"
  
  test_setup
  "$test_func"
  test_teardown
}

# Export functions
export -f echo_color info success error
export -f start_test test_pass test_fail
export -f assert_equals assert_contains assert_exit_code
export -f mock_fly cleanup_mocks
export -f test_setup test_teardown run_test
export TESTS_TOTAL TESTS_PASSED TESTS_FAILED
export __TEST_DIR __SCRIPTS_DIR