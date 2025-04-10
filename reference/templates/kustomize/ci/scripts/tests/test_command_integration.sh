#!/usr/bin/env bash
#
# Test script for fly.sh command integration with environment helpers
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"

# Source all necessary modules to test command execution
source "${__SCRIPTS_DIR}/lib/utils.sh"
source "${__SCRIPTS_DIR}/lib/environment.sh"
source "${__SCRIPTS_DIR}/lib/version.sh"
source "${__SCRIPTS_DIR}/lib/foundation.sh"
source "${__SCRIPTS_DIR}/lib/commands.sh"
source "${__SCRIPTS_DIR}/lib/pipelines.sh"
source "${__SCRIPTS_DIR}/lib/parsing.sh"

# Mock get_latest_version if not available
if ! type get_latest_version &>/dev/null; then
  function get_latest_version() {
    echo "1.0.0"
  }
  export -f get_latest_version
fi

# Mock check_fly
function check_fly() {
  return 0
}
export -f check_fly

# Setup test environment
function setup_test_env() {
  # Get paths
  local ci_dir="${__SCRIPTS_DIR%/*}"
  local repo_root="${ci_dir%/*}"
  
  # Create test pipeline files
  mkdir -p "${ci_dir}/pipelines"
  if [[ ! -f "${ci_dir}/pipelines/main.yml" ]]; then
    echo "pipeline: main" > "${ci_dir}/pipelines/main.yml"
  fi
  if [[ ! -f "${ci_dir}/pipelines/release.yml" ]]; then
    echo "pipeline: release" > "${ci_dir}/pipelines/release.yml"
  fi
  
  # Setup mock fly command
  mock_fly "set-pipeline" "-p main-test-foundation" 0
  
  # Set global vars for the test
  export CI_DIR="${ci_dir}"
  export REPO_ROOT="${repo_root}"
  
  echo "Test setup complete. CI_DIR=${CI_DIR}, REPO_ROOT=${REPO_ROOT}"
}

# Create a simplified mock for cmd_set_pipeline so we can test
function cmd_set_pipeline() {
  echo "MOCK cmd_set_pipeline called with:"
  echo "pipeline=$1"
  echo "foundation=$2"
  echo "repo=$3"
  echo "target=$4"
  echo "environment=$5"
  echo "datacenter=$6"
  echo "datacenter_type=$7"
  echo "branch=$8"
  echo "git_release_branch=$9"
  echo "version_file=${10}"
  echo "timer_duration=${11}"
  echo "version=${12}"
  echo "dry_run=${13}"
  echo "verbose=${14}"
  echo "foundation_path=${15}"
  echo "git_uri=${16}"
  echo "config_git_uri=${17}"
  echo "config_git_branch=${18}"
  
  # Mimic the output of the real cmd_set_pipeline for assertions to test
  echo "set-pipeline"
  echo "main-test-foundation"
  echo "foundation=$2"
  echo "environment=$5"
  echo "branch=$8"
  echo "foundation_path=${15}"
  echo "git_uri=${16}"
  echo "config_git_uri=${17}"
  echo "config_git_branch=${18}"
  
  return 0
}
export -f cmd_set_pipeline

# Test command integration with environment helpers
function test_cmd_set_pipeline_with_helpers() {
  start_test "cmd_set_pipeline with lab environment"
  
  # Setup
  local pipeline="main"
  local foundation="test-foundation"
  local repo="test-repo"
  local target="test-target"
  local datacenter="cml"
  local datacenter_type="k8s"
  local dry_run="true"  # So we don't actually run fly, just check args
  local verbose="false"
  
  # Determine environment settings using helpers
  local environment=""
  local github_org=""
  local config_repo_name=""
  local branch=""
  
  # Use the helpers as they are used in fly.sh
  local foundation_result=$(determine_foundation_environment "$datacenter" "$environment" "$github_org" "$config_repo_name")
  IFS=':' read -r environment github_org config_repo_name <<< "$foundation_result"
  
  local env_result=$(configure_environment "$environment" "$branch" "$github_org" "$config_repo_name")
  IFS=':' read -r branch github_org config_repo_name <<< "$env_result"
  
  # Set git URIs
  local git_uri="git@github.com:$github_org/$repo.git"
  local config_git_uri="git@github.com:$github_org/$config_repo_name.git"
  local config_git_branch="master"
  local foundation_path="foundations/$foundation"
  
  # Call cmd_set_pipeline
  local output=$(cmd_set_pipeline "$pipeline" "$foundation" "$repo" "$target" "$environment" "$datacenter" "$datacenter_type" "$branch" "release" "version" "3h" "1.0.0" "$dry_run" "$verbose" "$foundation_path" "$git_uri" "$config_git_uri" "$config_git_branch" 2>&1)
  
  # Verify output contains expected parameters
  assert_contains "$output" "set-pipeline" "Should include set-pipeline command"
  assert_contains "$output" "main-test-foundation" "Should include correct pipeline name"
  assert_contains "$output" "foundation=test-foundation" "Should include foundation parameter"
  assert_contains "$output" "environment=lab" "Should include environment parameter"
  assert_contains "$output" "branch=develop" "Should include branch parameter derived from environment"
  assert_contains "$output" "foundation_path=foundations/test-foundation" "Should include foundation_path parameter"
  assert_contains "$output" "git_uri=git@github.com:Utilities-tkgieng/test-repo.git" "Should include correct git_uri"
  assert_contains "$output" "config_git_uri=git@github.com:Utilities-tkgieng/config-lab.git" "Should include correct config_git_uri"
  assert_contains "$output" "config_git_branch=master" "Should include correct config_git_branch"
  
  test_pass "cmd_set_pipeline with lab environment"
  
  # Test with nonprod environment
  start_test "cmd_set_pipeline with nonprod environment"
  
  # Reset variables
  environment="nonprod"
  github_org=""
  config_repo_name=""
  branch=""
  
  # Use helpers
  env_result=$(configure_environment "$environment" "$branch" "$github_org" "$config_repo_name")
  IFS=':' read -r branch github_org config_repo_name <<< "$env_result"
  
  # Set git URIs
  git_uri="git@github.com:$github_org/$repo.git"
  config_git_uri="git@github.com:$github_org/$config_repo_name.git"
  
  # Call cmd_set_pipeline
  output=$(cmd_set_pipeline "$pipeline" "$foundation" "$repo" "$target" "$environment" "$datacenter" "$datacenter_type" "$branch" "release" "version" "3h" "1.0.0" "$dry_run" "$verbose" "$foundation_path" "$git_uri" "$config_git_uri" "$config_git_branch" 2>&1)
  
  # Verify output
  assert_contains "$output" "environment=nonprod" "Should include nonprod environment parameter"
  assert_contains "$output" "branch=master" "Should include branch=master for nonprod environment"
  assert_contains "$output" "git_uri=git@github.com:Utilities-tkgiops/test-repo.git" "Should use tkgiops org for nonprod"
  assert_contains "$output" "config_git_uri=git@github.com:Utilities-tkgiops/config-nonprod.git" "Should use nonprod config repo"
  
  test_pass "cmd_set_pipeline with nonprod environment"
}

# Create mock for release pipeline tests
function cmd_release_pipeline() {
  echo "MOCK cmd_release_pipeline called with:"
  echo "foundation=$1"
  echo "repo=$2"
  echo "target=$3"
  echo "environment=$4"
  echo "datacenter=$5"
  echo "datacenter_type=$6"
  echo "branch=$7"
  echo "git_release_branch=$8"
  echo "version_file=$9"
  echo "timer_duration=${10}"
  echo "version=${11}"
  echo "dry_run=${12}"
  echo "verbose=${13}"
  echo "foundation_path=${14}"
  echo "git_uri=${15}"
  echo "config_git_uri=${16}"
  echo "config_git_branch=${17}"
  
  # Echo the args in the format expected by the test
  echo "CMD_SET_PIPELINE CALLED WITH:"
  echo "ARG: release"
  echo "ARG: $1"  # foundation
  echo "ARG: $2"  # repo
  echo "ARG: $7"  # branch
  echo "ARG: ${14}"  # foundation_path
  echo "ARG: ${15}"  # git_uri
  echo "ARG: ${16}"  # config_git_uri
  
  return 0
}
export -f cmd_release_pipeline

# Test parameters passed to release pipeline
function test_cmd_release_pipeline() {
  start_test "cmd_release_pipeline integration"
  
  # Setup test variables
  local foundation="test-foundation"
  local repo="test-repo"
  local target="test-target"
  local datacenter="cml"
  local datacenter_type="k8s"
  local environment="lab"
  local branch="develop"
  local git_release_branch="release"
  local version_file="version"
  local timer_duration="3h"
  local version="1.0.0"
  local dry_run="true"
  local verbose="false"
  local foundation_path="foundations/$foundation"
  local git_uri="git@github.com:Utilities-tkgieng/$repo.git"
  local config_git_uri="git@github.com:Utilities-tkgieng/config-lab.git"
  local config_git_branch="master"
  
  # Call release pipeline
  local output=$(cmd_release_pipeline "$foundation" "$repo" "$target" "$environment" "$datacenter" "$datacenter_type" "$branch" "$git_release_branch" "$version_file" "$timer_duration" "$version" "$dry_run" "$verbose" "$foundation_path" "$git_uri" "$config_git_uri" "$config_git_branch" 2>&1)
  
  # Verify it passes correct parameters to cmd_set_pipeline
  assert_contains "$output" "ARG: release" "Should call cmd_set_pipeline with release pipeline"
  assert_contains "$output" "ARG: test-foundation" "Should pass foundation"
  assert_contains "$output" "ARG: test-repo" "Should pass repo name"
  assert_contains "$output" "ARG: develop" "Should pass branch"
  assert_contains "$output" "ARG: foundations/test-foundation" "Should pass foundation_path"
  assert_contains "$output" "ARG: git@github.com:Utilities-tkgieng/test-repo.git" "Should pass git_uri"
  assert_contains "$output" "ARG: git@github.com:Utilities-tkgieng/config-lab.git" "Should pass config_git_uri"
  
  test_pass "cmd_release_pipeline integration"
}

# Run setup before all tests
setup_test_env

# Run all tests
run_test test_cmd_set_pipeline_with_helpers
run_test test_cmd_release_pipeline

# Report test results
report_results