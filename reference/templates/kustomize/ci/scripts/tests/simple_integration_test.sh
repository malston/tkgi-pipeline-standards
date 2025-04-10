#!/usr/bin/env bash
#
# Simple integration test for environment helpers
#

set -e

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" &>/dev/null && pwd)"

# Load helper functions
source "${LIB_DIR}/environment.sh"
source "${LIB_DIR}/version.sh"
source "${LIB_DIR}/foundation.sh"

# Colors 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Mock get_latest_version
function get_latest_version() {
  echo "1.0.0"
}

# Simple test function
function test_helpers() {
  echo -e "${YELLOW}Testing environment.sh...${NC}"
  
  local lab_result=$(configure_environment "lab" "" "" "")
  echo "lab result: $lab_result"
  if [[ "$lab_result" == "develop:Utilities-tkgieng:config-lab" ]]; then
    echo -e "${GREEN}PASS:${NC} lab environment"
  else
    echo -e "${RED}FAIL:${NC} lab environment"
    echo "  Expected: develop:Utilities-tkgieng:config-lab"
    echo "  Got:      $lab_result"
    exit 1
  fi
  
  local nonprod_result=$(configure_environment "nonprod" "" "" "")
  echo "nonprod result: $nonprod_result"
  if [[ "$nonprod_result" == "master:Utilities-tkgiops:config-nonprod" ]]; then
    echo -e "${GREEN}PASS:${NC} nonprod environment"
  else
    echo -e "${RED}FAIL:${NC} nonprod environment"
    echo "  Expected: master:Utilities-tkgiops:config-nonprod"
    echo "  Got:      $nonprod_result"
    exit 1
  fi
  
  echo -e "${YELLOW}Testing foundation.sh...${NC}"
  
  local foundation_result=$(determine_foundation_environment "cml" "" "" "")
  echo "cml result: $foundation_result"
  if [[ "$foundation_result" == "lab:Utilities-tkgieng:config-lab" ]]; then
    echo -e "${GREEN}PASS:${NC} foundation cml"
  else
    echo -e "${RED}FAIL:${NC} foundation cml"
    echo "  Expected: lab:Utilities-tkgieng:config-lab"
    echo "  Got:      $foundation_result"
    exit 1
  fi
  
  echo -e "${YELLOW}Testing version.sh...${NC}"
  
  local version_result=$(normalize_version "v1.2.3")
  echo "version result: $version_result"
  if [[ "$version_result" == "1.2.3" ]]; then
    echo -e "${GREEN}PASS:${NC} normalize_version"
  else
    echo -e "${RED}FAIL:${NC} normalize_version"
    echo "  Expected: 1.2.3"
    echo "  Got:      $version_result"
    exit 1
  fi
  
  # Integration test
  echo -e "${YELLOW}Testing integration...${NC}"
  
  local DC="cml"
  local ENVIRONMENT=""
  local GITHUB_ORG=""
  local CONFIG_REPO_NAME=""
  local GIT_RELEASE_TAG=""
  
  local FOUNDATION_RESULT=$(determine_foundation_environment "$DC" "$ENVIRONMENT" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
  IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<< "$FOUNDATION_RESULT"
  
  local ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$GIT_RELEASE_TAG" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
  IFS=':' read -r GIT_RELEASE_TAG GITHUB_ORG CONFIG_REPO_NAME <<< "$ENV_RESULT"
  
  echo "Integration results:"
  echo "ENVIRONMENT=$ENVIRONMENT"
  echo "GIT_RELEASE_TAG=$GIT_RELEASE_TAG"
  echo "GITHUB_ORG=$GITHUB_ORG"
  echo "CONFIG_REPO_NAME=$CONFIG_REPO_NAME"
  
  if [[ "$ENVIRONMENT" == "lab" && 
        "$GIT_RELEASE_TAG" == "develop" && 
        "$GITHUB_ORG" == "Utilities-tkgieng" && 
        "$CONFIG_REPO_NAME" == "config-lab" ]]; then
    echo -e "${GREEN}PASS:${NC} integration test"
  else
    echo -e "${RED}FAIL:${NC} integration test"
    exit 1
  fi
  
  echo -e "${GREEN}All tests passed!${NC}"
}

# Run the tests
test_helpers