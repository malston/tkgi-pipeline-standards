#!/usr/bin/env bash
#
# Test script to verify the command-specific help functionality in fly.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Allow overriding the script path via env var (for testing modular version)
if [[ -z "${ORIG_SCRIPT}" ]]; then
  FLY_SCRIPT="${SCRIPT_DIR}/../fly.sh"
else
  # Check if path is relative or absolute
  if [[ "${ORIG_SCRIPT}" == /* ]]; then
    FLY_SCRIPT="${ORIG_SCRIPT}"
  else
    FLY_SCRIPT="${SCRIPT_DIR}/../${ORIG_SCRIPT}"
  fi
fi

# Verify the script exists
if [[ ! -f "${FLY_SCRIPT}" ]]; then
  echo "Error: Script not found at ${FLY_SCRIPT}"
  exit 1
fi

# Source test helpers if available
if [[ -f "${SCRIPT_DIR}/helpers.sh" ]]; then
  source "${SCRIPT_DIR}/helpers.sh"
fi

# Test function
function test_command_help() {
  local command="$1"
  local expected_text="$2"
  
  echo "Testing help for command: $command"
  
  # Run fly.sh with --help and the command
  local output
  output=$(${FLY_SCRIPT} --help "$command" 2>&1)
  
  # Check if the output contains the expected text
  if echo "$output" | grep -q "$expected_text"; then
    echo "✅ Success: Help for '$command' command contains expected text."
    return 0
  else
    echo "❌ Failure: Help for '$command' command does not contain expected text."
    echo "Expected to find: $expected_text"
    echo "Output was:"
    echo "$output"
    return 1
  fi
}

# Test general help
echo "Testing general help"
${FLY_SCRIPT} --help | grep "For more detailed help on a specific command" || {
  echo "❌ Failure: General help does not include instruction for command-specific help"
  exit 1
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
  echo "❌ Failure: Short-form help (-h set) for 'set' command doesn't work"
  exit 1
}

# Test with command followed by help flag
echo "Testing command followed by help flag"
${FLY_SCRIPT} set --help | grep "Command: set" || {
  echo "❌ Failure: Command followed by help flag (set --help) doesn't work"
  exit 1
}

# Test with command followed by short-form help flag
echo "Testing command followed by short-form help flag"
${FLY_SCRIPT} set -h | grep "Command: set" || {
  echo "❌ Failure: Command followed by short-form help (set -h) doesn't work"
  exit 1
}

echo "All command-specific help tests passed ✅"
exit 0