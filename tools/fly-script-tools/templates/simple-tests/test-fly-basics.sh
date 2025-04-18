#!/usr/bin/env bash
# test-fly-basics.sh - Basic tests for fly.sh

# Source the test framework
source "$(dirname "$0")/simple-test-framework.sh"

# Path to the fly.sh script being tested
FLY_SCRIPT="../fly.sh"

# Test 1: Check that script exists
test_header "Script exists"
if [[ -f "$FLY_SCRIPT" ]]; then
    echo "✅ PASS: fly.sh script exists"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: fly.sh script not found at $FLY_SCRIPT"
    ((TESTS_FAILED++))
    exit 1  # No point continuing if script doesn't exist
fi

# Test 2: Check that script is executable
test_header "Script is executable"
if [[ -x "$FLY_SCRIPT" ]]; then
    echo "✅ PASS: fly.sh script is executable"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: fly.sh script is not executable"
    ((TESTS_FAILED++))
fi

# Test 3: Check usage output
test_header "Usage output"
OUTPUT=$("$FLY_SCRIPT" -h 2>&1)
assert_contains "$OUTPUT" "Usage:" "Help output should contain 'Usage:'"
assert_contains "$OUTPUT" "-f, --foundation" "Help should mention foundation parameter"

# Test 4: Check error for missing foundation
test_header "Error for missing foundation"
OUTPUT=$("$FLY_SCRIPT" 2>&1 || true)
assert_contains "$OUTPUT" "Missing -f <foundation>" "Should error when foundation is missing"

# Print test summary
print_test_summary
exit $?