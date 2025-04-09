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

# Test function for command-specific help
function test_command_help() {
  local command="$1"
  local expected_text="$2"
  
  echo "Testing help for command: $command"
  
  # Run fly.sh with --help and the command
  local output
  output=$(${FLY_SCRIPT} --help "$command" 2>&1)
  
  # Check if the output contains the expected text
  if echo "$output" | grep -q "$expected_text"; then
    success "Help for '$command' command contains expected text."
    return 0
  else
    error "Help for '$command' command does not contain expected text."
    echo "Expected to find: $expected_text"
    echo "Output was:"
    echo "$output"
    return 1
  fi
}

# Test general help
echo "Testing general help"
${FLY_SCRIPT} --help | grep "For more detailed help on a specific command" || {
  error "General help does not include instruction for command-specific help"
}

# Test specific command help
test_command_help "set" "Command: set"
test_command_help "unpause" "Command: unpause"
test_command_help "destroy" "Command: destroy"
test_command_help "validate" "Command: validate"
test_command_help "release" "Command: release"

# Test with -h flag instead of --help
echo "Testing help with -h flag"
${FLY_SCRIPT} -h set | grep "Command: set" || {
  error "Short-form help (-h set) for 'set' command doesn't work"
}

# Test with command followed by help flag
echo "Testing command followed by help flag"
${FLY_SCRIPT} set --help | grep "Command: set" || {
  error "Command followed by help flag (set --help) doesn't work"
}

# Test with command followed by short-form help flag
echo "Testing command followed by short-form help flag"
${FLY_SCRIPT} set -h | grep "Command: set" || {
  error "Command followed by short-form help (set -h) doesn't work"
}

echo_color "$GREEN" "All command-specific help tests passed!"
exit 0