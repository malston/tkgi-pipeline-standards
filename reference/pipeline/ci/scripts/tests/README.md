# Tests for Pipeline CI Scripts

This directory contains tests for the CI scripts in the reference pipeline implementation. These tests help ensure that the scripts work correctly.

## Test Structure

- `test-framework.sh`: Core testing utilities and helpers  
- `test_fly_basics.sh`: Tests for basic functionality of the fly.sh script  
- `test_fly_parameters.sh`: Simple test for parameter handling, focusing on `--params-branch`
- `test_verbose_param.sh`: Dedicated test for the `--verbose` parameter
- `test_version_param.sh`: Dedicated test for the `--version` parameter

## Running Tests

To run the tests:

```bash
# Run basic fly functionality tests
./test_fly_basics.sh

# Test parameter handling
./test_fly_parameters.sh

# Test verbose parameter handling
./test_verbose_param.sh

# Test version parameter handling
./test_version_param.sh
```
