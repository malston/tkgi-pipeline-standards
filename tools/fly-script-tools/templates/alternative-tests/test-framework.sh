#!/usr/bin/env bash
# test-framework.sh - Easy-to-understand test framework for fly.sh

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Print a test header
function test_header() {
    echo "==== TEST: $1 ===="
}

# Assert that two values are equal
function assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo "✅ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $message"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        ((TESTS_FAILED++))
    fi
}

# Assert that a value contains a substring
function assert_contains() {
    local string="$1"
    local substring="$2"
    local message="$3"
    
    if [[ "$string" == *"$substring"* ]]; then
        echo "✅ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $message"
        echo "   String:    '$string'"
        echo "   Not found: '$substring'"
        ((TESTS_FAILED++))
    fi
}

# Assert that a command exits with expected code
function assert_exit_code() {
    local command="$1"
    local expected_code="$2"
    local message="$3"
    
    # Run command in subshell to capture exit code
    eval "$command" > /dev/null 2>&1
    local actual_code=$?
    
    if [[ $actual_code -eq $expected_code ]]; then
        echo "✅ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $message"
        echo "   Expected exit code: $expected_code"
        echo "   Actual exit code:   $actual_code"
        ((TESTS_FAILED++))
    fi
}

# Print summary of test results
function print_test_summary() {
    echo ""
    echo "==== TEST SUMMARY ===="
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "===================="
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "❌ Some tests failed!"
        return 1
    else
        echo "✅ All tests passed!"
        return 0
    fi
}