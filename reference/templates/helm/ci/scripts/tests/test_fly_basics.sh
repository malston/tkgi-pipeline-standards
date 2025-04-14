#!/usr/bin/env bash
#
# Test script for fly.sh command basics
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"

# Path to the fly.sh script we're testing
FLY_SCRIPT="${__SCRIPTS_DIR}/../fly.sh"
export TEST_MODE=true

# Test the help output
function test_help_output() {
  start_test "Help command displays usage"

  # Run the script with -h flag
  local output
  output=$("${FLY_SCRIPT}" -h 2>&1)

  # Verify output contains essential help information
  assert_contains "$output" "Usage:" "Help should include 'Usage:'"
  assert_contains "$output" "FOUNDATION" "Help should include foundation parameter"
  assert_contains "$output" "PIPELINE" "Help should include pipeline parameter"
  assert_contains "$output" "TARGET" "Help should include target parameter"

  test_pass "Help command displays usage correctly"
}

# Test exit code when required parameters are missing
function test_missing_params() {
  start_test "Script requires foundation parameter"

  # Run the script without params, should exit with error
  local exit_code=0
  "${FLY_SCRIPT}" >/dev/null 2>&1 || exit_code=$?
  assert_equals 1 "$exit_code" "Script should exit with error when no parameters are provided"

  # Run the script with incomplete params
  exit_code=0
  "${FLY_SCRIPT}" -t test-target >/dev/null 2>&1 || exit_code=$?
  assert_equals 1 "$exit_code" "Script should exit with error when foundation is missing"

  test_pass "Script correctly requires foundation parameter"
}

# Test foundation parsing
function test_foundation_parsing() {
  start_test "Script correctly parses foundation"

  # Mock fly command
  cat >"${__TEST_DIR}/fly" <<'EOF'
#!/usr/bin/env bash
echo "MOCK FLY CALLED WITH: $@" > "${__TEST_DIR}/fly_output.log"
exit 0
EOF
  chmod +x "${__TEST_DIR}/fly"
  export PATH="${__TEST_DIR}:${PATH}"

  # Run the script with a sample foundation
  "${FLY_SCRIPT}" -f cml-k8s-n-01 -t test-target >/dev/null 2>&1

  # Check if fly was called with correct parameters
  if [[ -f "${__TEST_DIR}/fly_output.log" ]]; then
    local output
    output=$(cat "${__TEST_DIR}/fly_output.log")

    # Check datacenter extraction
    assert_contains "$output" "cml" "Should extract datacenter from foundation"
    assert_contains "$output" "k8s" "Should extract datacenter type from foundation"
    assert_contains "$output" "foundation=cml-k8s-n-01" "Should set foundation parameter"
  else
    test_fail "fly command execution" "No fly command was executed"
  fi

  test_pass "Foundation parsing works correctly"
}

# Test pipeline file selection
function test_pipeline_file() {
  start_test "Script selects correct pipeline file"

  # Mock fly command
  cat >"${__TEST_DIR}/fly" <<'EOF'
#!/usr/bin/env bash
echo "MOCK FLY CALLED WITH: $@" > "${__TEST_DIR}/fly_output.log"
exit 0
EOF
  chmod +x "${__TEST_DIR}/fly"
  export PATH="${__TEST_DIR}:${PATH}"

  # Create test pipeline files
  mkdir -p "${__SCRIPTS_DIR}/../pipelines"
  touch "${__SCRIPTS_DIR}/../pipelines/main.yml"
  touch "${__SCRIPTS_DIR}/../pipelines/release.yml"

  # Run the script with main pipeline
  "${FLY_SCRIPT}" -f test-foundation -t test-target -p main >/dev/null 2>&1

  # Check if correct pipeline file was used
  if [[ -f "${__TEST_DIR}/fly_output.log" ]]; then
    local output
    output=$(cat "${__TEST_DIR}/fly_output.log")
    assert_contains "$output" "main.yml" "Should use main.yml for main pipeline"
  else
    test_fail "fly command execution" "No fly command was executed"
  fi

  # Run the script with release pipeline
  "${FLY_SCRIPT}" -f test-foundation -t test-target -p release >/dev/null 2>&1

  # Check if correct pipeline file was used
  if [[ -f "${__TEST_DIR}/fly_output.log" ]]; then
    local output
    output=$(cat "${__TEST_DIR}/fly_output.log")
    assert_contains "$output" "release.yml" "Should use release.yml for release pipeline"
  else
    test_fail "fly command execution" "No fly command was executed"
  fi

  test_pass "Pipeline file selection works correctly"
}

# Run all tests
run_test test_help_output
run_test test_missing_params
run_test test_foundation_parsing
run_test test_pipeline_file

# Report test results
report_results
