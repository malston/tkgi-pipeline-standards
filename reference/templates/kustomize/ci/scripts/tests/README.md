# Tests for CI Scripts

This directory contains tests for the CI scripts in the kustomize template. The tests help ensure that the scripts work correctly and continue to do so after changes.

## Test Structure

- `test_framework.sh`: Core testing utilities and helpers
- `test_fly.sh`: Tests for the fly.sh script
- `run_tests.sh`: Script to run all tests

## Running Tests

To run all tests:

```bash
./run_tests.sh
```

To run a specific test file:

```bash
./test_fly.sh
```

## Test Coverage

The tests for fly.sh cover:

1. Basic functionality:
   - Help command displays usage
   - Exit code when required parameters are missing
   - Basic set pipeline command
   
2. Advanced functionality:
   - Environment determination from foundation name
   - Command-based interface (set, destroy, validate)
   - Legacy flag behavior (-r for release)
   - Advanced options (--dry-run)
   
3. Commands:
   - set
   - destroy
   - validate
   - release

## Adding New Tests

To add a new test for an existing script:

1. Add a new test function to the appropriate test file:

```bash
function test_new_feature() {
  start_test "Description of the test"
  
  # Test code
  
  test_pass "Description of the test"
}
```

2. Add the test to the list of tests to run at the end of the file:

```bash
run_test test_new_feature
```

To add tests for a new script:

1. Create a new test file named `test_script_name.sh`
2. Follow the pattern in existing test files
3. Make sure to source the test framework at the beginning