#!/usr/bin/env bash
#
# Tests for ns-mgmt-refactored.sh script
#

# Source test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Path to the script being tested
SCRIPT_PATH="${__SCRIPTS_DIR}/fly.sh"

# Make sure the script exists and is executable
if [[ ! -x "${SCRIPT_PATH}" ]]; then
  error "Script not found or not executable: ${SCRIPT_PATH}"
  exit 1
fi

# Tests

# Test 1: Check help command displays usage
function test_help_command() {
  start_test "Help command displays usage"
  
  # Run the script with -h flag
  local output
  output=$("${SCRIPT_PATH}" -h 2>&1 || true)
  
  # Verify output contains usage information
  assert_contains "$output" "Usage:"
  assert_contains "$output" "Commands:"
  assert_contains "$output" "Options:"
  
  test_pass "Help command displays usage"
}

# Test 2: Check exit code when required parameters are missing
function test_missing_required_params() {
  start_test "Exit code when foundation is missing"
  
  # Run without foundation parameter
  assert_exit_code "${SCRIPT_PATH}" 1
  
  test_pass "Exit code when foundation is missing"
}

# Test 3: Test basic set pipeline command
function test_basic_set_pipeline() {
  start_test "Basic set pipeline command"
  
  # Mock the fly command
  mock_fly "set-pipeline" "tkgi-ns-mgmt-cml-k8s-n-01"
  
  # Run the script with minimal params
  "${SCRIPT_PATH}" -f "cml-k8s-n-01" -t "test-target" >/dev/null 2>&1
  
  # Verify fly was called with the right arguments
  local last_command
  last_command=$(cat "${__TEST_DIR}/.fly_last_command")
  
  assert_contains "$last_command" "set-pipeline"
  assert_contains "$last_command" "tkgi-ns-mgmt-cml-k8s-n-01"
  
  test_pass "Basic set pipeline command"
}

# Test 4: Test environment determination
function test_environment_determination() {
  start_test "Environment determination from foundation name"
  
  # Mock the fly command
  mock_fly "set-pipeline" "environment=lab"
  
  # Run the script with lab foundation
  "${SCRIPT_PATH}" -f "cml-k8s-n-01" -t "test-target" >/dev/null 2>&1
  
  # Verify correct environment was determined
  local last_command
  last_command=$(cat "${__TEST_DIR}/.fly_last_command")
  
  assert_contains "$last_command" "environment=lab"
  
  # Now test with nonprod foundation
  mock_fly "set-pipeline" "environment=nonprod"
  
  "${SCRIPT_PATH}" -f "cml-k8s-d-01" -t "test-target" >/dev/null 2>&1
  
  last_command=$(cat "${__TEST_DIR}/.fly_last_command")
  assert_contains "$last_command" "environment=nonprod"
  
  test_pass "Environment determination from foundation name"
}

# Test 5: Test command-based interface
function test_command_interface() {
  start_test "Command-based interface"
  
  # Mock the fly command for destroy
  mock_fly "destroy-pipeline" "tkgi-ns-mgmt-cml-k8s-n-01"
  
  # Set up input for confirmation
  echo "yes" > "${__TEST_DIR}/.test_input"
  
  # Run the script with destroy command
  ${SCRIPT_PATH} destroy tkgi-ns-mgmt -f "cml-k8s-n-01" -t "test-target" < "${__TEST_DIR}/.test_input" >/dev/null 2>&1
  
  # Verify fly was called with the right arguments
  local last_command
  last_command=$(cat "${__TEST_DIR}/.fly_last_command")
  
  assert_contains "$last_command" "destroy-pipeline"
  assert_contains "$last_command" "tkgi-ns-mgmt-cml-k8s-n-01"
  
  # Clean up
  rm -f "${__TEST_DIR}/.test_input"
  
  test_pass "Command-based interface"
}

# Test 6: Test legacy flag behavior (-r for release)
function test_legacy_release_flag() {
  start_test "Legacy release flag behavior"
  
  # Mock the fly command
  mock_fly "set-pipeline" "tkgi-ns-mgmt-release-cml-k8s-n-01"
  
  # Run the script with -r flag
  "${SCRIPT_PATH}" -f "cml-k8s-n-01" -t "test-target" -r >/dev/null 2>&1
  
  # Verify fly was called with the right arguments for release pipeline
  local last_command
  last_command=$(cat "${__TEST_DIR}/.fly_last_command")
  
  assert_contains "$last_command" "set-pipeline"
  assert_contains "$last_command" "tkgi-ns-mgmt-release-cml-k8s-n-01"
  
  test_pass "Legacy release flag behavior"
}

# Test 7: Test advanced options (dry-run)
function test_dry_run_option() {
  start_test "Dry run option"
  
  # Mock fly but shouldn't be called in dry-run mode
  mock_fly "set-pipeline" "" 1 # Will fail if called
  
  # Run with dry-run option
  output=$("${SCRIPT_PATH}" -f "cml-k8s-n-01" -t "test-target" --dry-run 2>&1)
  
  # Verify output contains dry run message
  assert_contains "$output" "DRY RUN"
  
  test_pass "Dry run option"
}

# Test 8: Test validation command
function test_validate_command() {
  start_test "Validate command"
  
  # Mock the fly command for validate-pipeline
  mock_fly "validate-pipeline" ""
  
  # Run the script with validate command
  "${SCRIPT_PATH}" validate main -f "cml-k8s-n-01" -t "test-target" >/dev/null 2>&1
  
  # Verify fly was called with validate-pipeline
  local last_command
  last_command=$(cat "${__TEST_DIR}/.fly_last_command")
  
  assert_contains "$last_command" "validate-pipeline"
  
  test_pass "Validate command"
}

# Run all tests
run_test test_help_command
run_test test_missing_required_params
run_test test_basic_set_pipeline
run_test test_environment_determination
run_test test_command_interface
run_test test_legacy_release_flag
run_test test_dry_run_option
run_test test_validate_command

# Report results
report_results