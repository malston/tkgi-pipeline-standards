# Tests for Helm CI Scripts

This directory contains tests for the CI scripts in the Helm template. The tests help ensure that the scripts work correctly and continue to do so after changes.

## Test Structure

- `test-framework.sh`: Core testing utilities and helpers
- `test_fly_basics.sh`: Tests for basic functionality of the fly.sh script
- `test_fly_parameters.sh`: Tests for parameter handling in fly.sh
- `test_verbose_param.sh`: Dedicated test for the `--verbose` parameter
- `test_version_param.sh`: Dedicated test for the `--version` parameter
- `run_tests.sh`: Script to run all tests

## Running Tests

To run all tests:

```bash
./run_tests.sh
```

To run specific test files:

```bash
# Test basic fly functionality
./test_fly_basics.sh

# Test parameter handling
./test_fly_parameters.sh

# Test verbose parameter handling
./test_verbose_param.sh

# Test version parameter handling
./test_version_param.sh
```

## Test Coverage

The tests for fly.sh cover:

1. Basic functionality:
   - Help command displays usage
   - Exit code when required parameters are missing
   - Basic set pipeline command
   - Foundation parsing

2. Advanced functionality:
   - Custom pipeline names
   - Branch parameter handling
   - Custom params repository branch (`-d/--params-branch`)
   - Verbose mode handling (`--verbose`)
   - Version parameter handling (`-v/--version`)

Note: Verbose and version parameters are now tested in dedicated test files for better maintainability.

## Adding New Tests

To add a new test for the fly.sh script:

1. Create a new test file named `test_feature_name.sh`
2. Source the test framework at the beginning: `source "${SCRIPT_DIR}/test-framework.sh"`
3. Add test functions for each aspect you want to test
4. Call `run_test` for each test function
5. End with `report_results` to show test summary

Example:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"

function test_new_feature() {
  start_test "Description of the test"
  
  # Test code
  
  test_pass "Description of the test"
}

run_test test_new_feature

report_results
```
