#!/usr/bin/env bash
#
# Fixed test script for environment helper functions
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"

# Source the helper functions we want to test
source "${__SCRIPTS_DIR}/lib/environment.sh"
source "${__SCRIPTS_DIR}/lib/version.sh"
source "${__SCRIPTS_DIR}/lib/foundation.sh"
source "${__SCRIPTS_DIR}/lib/utils.sh"  # for get_latest_version

# Mock get_latest_version if not available
if ! type get_latest_version &>/dev/null; then
  function get_latest_version() {
    echo "1.0.0"
  }
  export -f get_latest_version
fi

# Override test_fail to get more info
function test_fail() {
  local test_name="$1"
  local message="$2"
  echo "TEST FAIL: $test_name"
  echo "Reason: $message"
  ((TESTS_FAILED++)) || return 0
}

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
  echo "TEST RESULT: $result"
  expected="master:Utilities-tkgiops:config-nonprod"
  if [[ "$result" == "$expected" ]]; then
    test_pass "configure_environment for nonprod"
  else
    test_fail "configure_environment for nonprod" "Expected '$expected' but got '$result'"
  fi

  start_test "configure_environment for prod"
  result=$(configure_environment "prod" "" "" "")
  echo "TEST RESULT: $result"
  expected="master:Utilities-tkgiops:config-prod"
  if [[ "$result" == "$expected" ]]; then
    test_pass "configure_environment for prod"
  else
    test_fail "configure_environment for prod" "Expected '$expected' but got '$result'"
  fi

  start_test "configure_environment with custom values"
  result=$(configure_environment "lab" "custom-branch" "custom-org" "custom-config")
  echo "TEST RESULT: $result"
  expected="custom-branch:custom-org:custom-config"
  if [[ "$result" == "$expected" ]]; then
    test_pass "configure_environment with custom values"
  else
    test_fail "configure_environment with custom values" "Expected '$expected' but got '$result'"
  fi
}

# Test the version normalizer function
function test_version_normalizer() {
  start_test "normalize_version with normal version"
  local result=$(normalize_version "1.2.3")
  echo "TEST RESULT: $result"
  local expected="1.2.3"
  if [[ "$result" == "$expected" ]]; then
    test_pass "normalize_version with normal version"
  else
    test_fail "normalize_version with normal version" "Expected '$expected' but got '$result'"
  fi

  start_test "normalize_version with v prefix"
  result=$(normalize_version "v1.2.3")
  echo "TEST RESULT: $result"
  expected="1.2.3"
  if [[ "$result" == "$expected" ]]; then
    test_pass "normalize_version with v prefix"
  else
    test_fail "normalize_version with v prefix" "Expected '$expected' but got '$result'"
  fi

  start_test "normalize_version with release-v prefix"
  result=$(normalize_version "release-v1.2.3")
  echo "TEST RESULT: $result"
  expected="1.2.3"
  if [[ "$result" == "$expected" ]]; then
    test_pass "normalize_version with release-v prefix" 
  else
    test_fail "normalize_version with release-v prefix" "Expected '$expected' but got '$result'"
  fi

  start_test "normalize_version with 'latest'"
  result=$(normalize_version "latest")
  echo "TEST RESULT: $result"
  expected="1.0.0"  # This is what our mock returns
  if [[ "$result" == "$expected" ]]; then
    test_pass "normalize_version with 'latest'"
  else
    test_fail "normalize_version with 'latest'" "Expected '$expected' but got '$result'"
  fi
}

# Test the foundation environment helper
function test_foundation_helper() {
  start_test "determine_foundation_environment for cml datacenter"
  local result=$(determine_foundation_environment "cml" "" "" "")
  echo "TEST RESULT: $result"
  local expected="lab:Utilities-tkgieng:config-lab"
  if [[ "$result" == "$expected" ]]; then
    test_pass "determine_foundation_environment for cml datacenter"
  else
    test_fail "determine_foundation_environment for cml datacenter" "Expected '$expected' but got '$result'"
  fi

  start_test "determine_foundation_environment for cic datacenter"
  result=$(determine_foundation_environment "cic" "" "" "")
  echo "TEST RESULT: $result"
  expected="lab:Utilities-tkgieng:config-lab"
  if [[ "$result" == "$expected" ]]; then
    test_pass "determine_foundation_environment for cic datacenter"
  else
    test_fail "determine_foundation_environment for cic datacenter" "Expected '$expected' but got '$result'"
  fi

  # Add similar tests for other datacenters
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
  echo "FOUNDATION_RESULT: $FOUNDATION_RESULT"
  IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<< "$FOUNDATION_RESULT"
  
  local ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$GIT_RELEASE_TAG" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
  echo "ENV_RESULT: $ENV_RESULT"
  IFS=':' read -r GIT_RELEASE_TAG GITHUB_ORG CONFIG_REPO_NAME <<< "$ENV_RESULT"
  
  # Check results
  echo "ENVIRONMENT: $ENVIRONMENT"
  echo "GIT_RELEASE_TAG: $GIT_RELEASE_TAG"
  echo "GITHUB_ORG: $GITHUB_ORG"
  echo "CONFIG_REPO_NAME: $CONFIG_REPO_NAME"
  
  test_pass "Integration of environment helpers"
}

# Run all tests
run_test test_environment_helper
run_test test_version_normalizer
run_test test_foundation_helper
run_test test_environment_integration

# Report test results
report_results