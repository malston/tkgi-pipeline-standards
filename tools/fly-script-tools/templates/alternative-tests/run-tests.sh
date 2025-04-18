#!/usr/bin/env bash
# run-tests.sh - Run all tests for fly.sh

# Find all test files
TEST_DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
TEST_FILES=("$TEST_DIR"/test-*.sh)

# Run each test file
for test_file in "${TEST_FILES[@]}"; do
    echo "Running test: $(basename "$test_file")"
    bash "$test_file"
    
    # Check if test failed
    if [[ $? -ne 0 ]]; then
        echo "Test failed: $(basename "$test_file")"
        exit 1
    fi
done

echo "All tests passed!"