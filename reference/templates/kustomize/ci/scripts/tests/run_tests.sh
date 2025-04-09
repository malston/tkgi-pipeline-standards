#!/usr/bin/env bash
#
# Run all tests for the scripts
#

set -e

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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

function info() {
  echo_color "$YELLOW" "INFO: $1"
}

function success() {
  echo_color "$GREEN" "SUCCESS: $1"
}

function error() {
  echo_color "$RED" "ERROR: $1" >&2
}

function run_test_file() {
  local test_file="$1"
  local test_name=$(basename "$test_file" .sh)

  echo_color "$YELLOW" "=============================="
  echo_color "$YELLOW" "Running tests: $test_name"
  echo_color "$YELLOW" "=============================="

  # Make sure the file is executable
  chmod +x "$test_file"

  # Run the test
  if "$test_file"; then
    success "All tests passed in $test_name"
    return 0
  else
    error "Some tests failed in $test_name"
    return 1
  fi
}

# Find all test files
TEST_FILES=("$__DIR"/test_*.sh)

# Check if there are any test files
if [ ${#TEST_FILES[@]} -eq 0 ]; then
  error "No test files found!"
  exit 1
fi

# Run each test file
FAILURES=0

for test_file in "${TEST_FILES[@]}"; do
  if ! run_test_file "$test_file"; then
    ((FAILURES++))
  fi
  echo
done

# Report overall results
echo_color "$YELLOW" "=============================="
echo_color "$YELLOW" "Overall Test Results"
echo_color "$YELLOW" "=============================="
echo "Total test files: ${#TEST_FILES[@]}"

if [ "$FAILURES" -eq 0 ]; then
  success "All test files passed!"
  exit 0
else
  error "$FAILURES test file(s) had failures"
  exit 1
fi
