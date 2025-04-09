#!/usr/bin/env bash
#
# Basic validation script for fly.sh
#

set -e

# Path to the script being tested
SCRIPT_PATH="../fly.sh"

# Make sure the script exists and is executable
if [[ ! -x "${SCRIPT_PATH}" ]]; then
  echo "Script not found or not executable: ${SCRIPT_PATH}"
  exit 1
fi

# Basic test - help flag should return usage
echo "Testing help flag..."
output=$("${SCRIPT_PATH}" -h 2>&1 || true)
if echo "$output" | grep -q "Usage: ./fly.sh"; then
  echo "✓ Help flag works"
else
  echo "✗ Help flag doesn't show usage"
  exit 1
fi

# Check command-line parsing
echo "Testing command parsing..."
output=$("${SCRIPT_PATH}" -h 2>&1 || true)
if echo "$output" | grep -q "Commands:" && 
   echo "$output" | grep -q "set" && 
   echo "$output" | grep -q "unpause" && 
   echo "$output" | grep -q "destroy" && 
   echo "$output" | grep -q "validate" && 
   echo "$output" | grep -q "release"; then
  echo "✓ All commands are listed in help"
else
  echo "✗ Not all commands are listed in help"
  exit 1
fi

# Test for required parameters
echo "Testing required parameters..."
output=$("${SCRIPT_PATH}" 2>&1 || true)
if echo "$output" | grep -q "Foundation not specified"; then
  echo "✓ Script correctly requires foundation parameter"
else
  echo "✗ Script doesn't check for required foundation parameter"
  exit 1
fi

echo "All basic validation tests passed!"
exit 0