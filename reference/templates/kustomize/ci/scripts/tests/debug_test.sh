#!/usr/bin/env bash
#
# Debug test for command integration
#

set -e

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" &>/dev/null && pwd)"

echo "Loading helper functions..."
# Source the required modules
source "${LIB_DIR}/environment.sh"
source "${LIB_DIR}/version.sh"
source "${LIB_DIR}/foundation.sh"
source "${LIB_DIR}/utils.sh"

# Colors for output
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# Create a simple mock cmd_set_pipeline function
function cmd_set_pipeline() {
  echo "MOCK: cmd_set_pipeline called"
  echo "Args: $*"
  echo "environment=$5"
  echo "branch=$8"
  echo "git_uri=${16}"
  echo "config_git_uri=${17}"
  return 0
}

echo -e "${YELLOW}Testing environment selection...${RESET}"

# Test lab environment
dc="cml"
environment=""
github_org=""
config_repo_name=""
branch=""

echo "Determining environment for datacenter: $dc"
foundation_result=$(determine_foundation_environment "$dc" "$environment" "$github_org" "$config_repo_name")
echo "Foundation result: $foundation_result"
IFS=':' read -r environment github_org config_repo_name <<< "$foundation_result"

echo "Configuring environment settings for: $environment"
env_result=$(configure_environment "$environment" "$branch" "$github_org" "$config_repo_name")
echo "Environment result: $env_result"
IFS=':' read -r branch github_org config_repo_name <<< "$env_result"

echo "Final values:"
echo "  environment: $environment"
echo "  branch: $branch"
echo "  github_org: $github_org"
echo "  config_repo_name: $config_repo_name"

# Set git URIs
repo="test-repo"
git_uri="git@github.com:$github_org/$repo.git"
config_git_uri="git@github.com:$github_org/$config_repo_name.git"
foundation="test-foundation"
foundation_path="foundations/$foundation"

echo -e "\n${YELLOW}Testing cmd_set_pipeline with environment values...${RESET}"
pipeline="main"
target="test-target"
datacenter="cml"
datacenter_type="k8s"
dry_run="true"
verbose="false"
config_git_branch="master"

output=$(cmd_set_pipeline "$pipeline" "$foundation" "$repo" "$target" "$environment" "$datacenter" "$datacenter_type" "$branch" "release" "version" "3h" "1.0.0" "$dry_run" "$verbose" "$foundation_path" "$git_uri" "$config_git_uri" "$config_git_branch")

echo -e "\n${YELLOW}Output from cmd_set_pipeline:${RESET}"
echo "$output"

echo -e "\n${GREEN}Tests completed.${RESET}"