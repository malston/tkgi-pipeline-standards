#!/usr/bin/env bash
#
# Test script for environment helper functions
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source the helper functions we want to test
source "${LIB_DIR}/environment.sh"
source "${LIB_DIR}/version.sh"
source "${LIB_DIR}/foundation.sh"
source "${LIB_DIR}/utils.sh" # for get_latest_version

# Mock get_latest_version if not available
if ! type get_latest_version &>/dev/null; then
  function get_latest_version() {
    echo "1.0.0"
  }
  export -f get_latest_version
fi

# Test the environment helper function
function test_environment_helper() {
  start_test "configure_environment for lab"
  local result=$(configure_environment "lab" "" "" "")
  echo "TEST RESULT: $result"
  local expected="develop:Utilities-tkgieng:config-lab"
  if [[ "$result" == "$expected" ]]; then
    test_pass "configure_environment for lab"
  else
    test_fail "configure_environment for lab" "Expected '$expected' but got '$result'"
  fi

  start_test "configure_environment for nonprod"
  result=$(configure_environment "nonprod" "" "" "")
  expected="master:Utilities-tkgiops:config-nonprod"
  assert_equals "$expected" "$result" "Nonprod environment should use master branch with tkgiops org"
  test_pass "configure_environment for nonprod"

  start_test "configure_environment for prod"
  result=$(configure_environment "prod" "" "" "")
  expected="master:Utilities-tkgiops:config-prod"
  assert_equals "$expected" "$result" "Prod environment should use master branch with tkgiops org"
  test_pass "configure_environment for prod"

  start_test "configure_environment with custom values"
  result=$(configure_environment "lab" "custom-branch" "custom-org" "custom-config")
  expected="custom-branch:custom-org:custom-config"
  assert_equals "$expected" "$result" "Should respect custom values when provided"
  test_pass "configure_environment with custom values"
}

# Test the version normalizer function
function test_version_normalizer() {
  start_test "normalize_version with normal version"
  local result=$(normalize_version "1.2.3")
  local expected="1.2.3"
  assert_equals "$expected" "$result" "Normal version should remain unchanged"
  test_pass "normalize_version with normal version"

  start_test "normalize_version with v prefix"
  result=$(normalize_version "v1.2.3")
  expected="1.2.3"
  assert_equals "$expected" "$result" "Should strip 'v' prefix"
  test_pass "normalize_version with v prefix"

  start_test "normalize_version with release-v prefix"
  result=$(normalize_version "release-v1.2.3")
  expected="1.2.3"
  assert_equals "$expected" "$result" "Should strip 'release-v' prefix"
  test_pass "normalize_version with release-v prefix"

  start_test "normalize_version with 'latest'"
  result=$(normalize_version "latest")
  expected="1.0.0" # This is what our mock returns
  assert_equals "$expected" "$result" "Should resolve 'latest' to actual version"
  test_pass "normalize_version with 'latest'"
}

# Test the foundation environment helper
function test_foundation_helper() {
  start_test "determine_foundation_environment for cml datacenter"
  local result
  result=$(determine_foundation_environment "cml" "" "" "")
  local expected="lab:Utilities-tkgieng:config-lab"
  assert_equals "$expected" "$result" "CML datacenter should map to lab environment"
  test_pass "determine_foundation_environment for cml datacenter"

  start_test "determine_foundation_environment for cic datacenter"
  result=$(determine_foundation_environment "cic" "" "" "")
  expected="lab:Utilities-tkgieng:config-lab"
  assert_equals "$expected" "$result" "CIC datacenter should map to lab environment"
  test_pass "determine_foundation_environment for cic datacenter"

  start_test "determine_foundation_environment for temr datacenter"
  result=$(determine_foundation_environment "temr" "" "" "")
  expected="nonprod:Utilities-tkgiops:config-nonprod"
  assert_equals "$expected" "$result" "TEMR datacenter should map to nonprod environment"
  test_pass "determine_foundation_environment for temr datacenter"

  start_test "determine_foundation_environment for tmpe datacenter"
  result=$(determine_foundation_environment "tmpe" "" "" "")
  expected="nonprod:Utilities-tkgiops:config-nonprod"
  assert_equals "$expected" "$result" "TMPE datacenter should map to nonprod environment"
  test_pass "determine_foundation_environment for tmpe datacenter"

  start_test "determine_foundation_environment for oxdc datacenter"
  result=$(determine_foundation_environment "oxdc" "" "" "")
  expected="prod:Utilities-tkgiops:config-prod"
  assert_equals "$expected" "$result" "OXDC datacenter should map to prod environment"
  test_pass "determine_foundation_environment for oxdc datacenter"

  start_test "determine_foundation_environment for svdc datacenter"
  result=$(determine_foundation_environment "svdc" "" "" "")
  expected="prod:Utilities-tkgiops:config-prod"
  assert_equals "$expected" "$result" "SVDC datacenter should map to prod environment"
  test_pass "determine_foundation_environment for svdc datacenter"

  start_test "determine_foundation_environment with explicit environment"
  result=$(determine_foundation_environment "cml" "nonprod" "" "")
  expected="nonprod:Utilities-tkgiops:config-nonprod"
  assert_equals "$expected" "$result" "Should respect explicit environment when provided"
  test_pass "determine_foundation_environment with explicit environment"

  start_test "determine_foundation_environment with custom values"
  result=$(determine_foundation_environment "cml" "prod" "custom-org" "custom-config")
  expected="prod:custom-org:custom-config"
  assert_equals "$expected" "$result" "Should respect custom values when provided"
  test_pass "determine_foundation_environment with custom values"
}

# Test integration of environment helpers with fly.sh
function test_environment_integration() {
  start_test "Integration of environment helpers"

  # Setup test variables
  local DC="cml"
  local ENVIRONMENT=""
  local GITHUB_ORG=""
  local CONFIG_REPO_NAME=""
  local GIT_RELEASE_TAG=""

  # Use the helpers as they are used in fly.sh
  local FOUNDATION_RESULT=$(determine_foundation_environment "$DC" "$ENVIRONMENT" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
  IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<<"$FOUNDATION_RESULT"

  local ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$GIT_RELEASE_TAG" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
  IFS=':' read -r GIT_RELEASE_TAG GITHUB_ORG CONFIG_REPO_NAME <<<"$ENV_RESULT"

  # Check results
  assert_equals "lab" "$ENVIRONMENT" "Environment should be 'lab' for CML datacenter"
  assert_equals "develop" "$GIT_RELEASE_TAG" "Git branch should be 'develop' for lab environment"
  assert_equals "Utilities-tkgieng" "$GITHUB_ORG" "GitHub org should be 'Utilities-tkgieng' for lab environment"
  assert_equals "config-lab" "$CONFIG_REPO_NAME" "Config repo should be 'config-lab' for lab environment"

  test_pass "Integration of environment helpers"
}

# Run all tests
run_test test_environment_helper
run_test test_version_normalizer
run_test test_foundation_helper
run_test test_environment_integration

# Report test results
report_results
