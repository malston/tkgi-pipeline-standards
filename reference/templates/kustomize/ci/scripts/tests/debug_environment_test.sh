#!/usr/bin/env bash
#
# Debug script for environment helpers test
#

set -e

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"

# Source the helper functions we want to test
source "${__SCRIPTS_DIR}/lib/environment.sh"
source "${__SCRIPTS_DIR}/lib/version.sh"
source "${__SCRIPTS_DIR}/lib/foundation.sh"

# Mock get_latest_version if needed
if ! type get_latest_version &>/dev/null; then
  function get_latest_version() {
    echo "1.0.0"
  }
  export -f get_latest_version
fi

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# Run each test with detailed output
echo -e "${YELLOW}Testing environment.sh functions:${RESET}"

lab_result=$(configure_environment "lab" "" "" "")
echo "configure_environment(lab) = $lab_result"
expected="develop:Utilities-tkgieng:config-lab"
if [[ "$lab_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} lab environment"
else
  echo -e "${RED}FAIL:${RESET} lab environment"
  echo "Expected: $expected"
  echo "Got:      $lab_result"
fi

nonprod_result=$(configure_environment "nonprod" "" "" "")
echo "configure_environment(nonprod) = $nonprod_result"
expected="master:Utilities-tkgiops:config-nonprod"
if [[ "$nonprod_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} nonprod environment"
else
  echo -e "${RED}FAIL:${RESET} nonprod environment"
  echo "Expected: $expected"
  echo "Got:      $nonprod_result"
fi

prod_result=$(configure_environment "prod" "" "" "")
echo "configure_environment(prod) = $prod_result"
expected="master:Utilities-tkgiops:config-prod"
if [[ "$prod_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} prod environment"
else
  echo -e "${RED}FAIL:${RESET} prod environment"
  echo "Expected: $expected"
  echo "Got:      $prod_result"
fi

custom_result=$(configure_environment "lab" "custom-branch" "custom-org" "custom-config")
echo "configure_environment(custom) = $custom_result"
expected="custom-branch:custom-org:custom-config"
if [[ "$custom_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} custom values"
else
  echo -e "${RED}FAIL:${RESET} custom values"
  echo "Expected: $expected"
  echo "Got:      $custom_result"
fi

echo -e "\n${YELLOW}Testing version.sh functions:${RESET}"
version_result=$(normalize_version "v1.2.3")
echo "normalize_version(v1.2.3) = $version_result"
expected="1.2.3"
if [[ "$version_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} normalize_version"
else
  echo -e "${RED}FAIL:${RESET} normalize_version"
  echo "Expected: $expected"
  echo "Got:      $version_result"
fi

echo -e "\n${YELLOW}Testing foundation.sh functions:${RESET}"
cml_result=$(determine_foundation_environment "cml" "" "" "")
echo "determine_foundation_environment(cml) = $cml_result"
expected="lab:Utilities-tkgieng:config-lab"
if [[ "$cml_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} cml foundation"
else
  echo -e "${RED}FAIL:${RESET} cml foundation"
  echo "Expected: $expected"
  echo "Got:      $cml_result"
fi

temr_result=$(determine_foundation_environment "temr" "" "" "")
echo "determine_foundation_environment(temr) = $temr_result"
expected="nonprod:Utilities-tkgiops:config-nonprod"
if [[ "$temr_result" == "$expected" ]]; then
  echo -e "${GREEN}PASS:${RESET} temr foundation"
else
  echo -e "${RED}FAIL:${RESET} temr foundation"
  echo "Expected: $expected"
  echo "Got:      $temr_result"
fi

echo -e "\n${YELLOW}Testing integration:${RESET}"
DC="cml"
ENVIRONMENT=""
GITHUB_ORG=""
CONFIG_REPO_NAME=""
GIT_RELEASE_TAG=""

echo "Using datacenter: $DC"
FOUNDATION_RESULT=$(determine_foundation_environment "$DC" "$ENVIRONMENT" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
echo "determine_foundation_environment result = $FOUNDATION_RESULT"
IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<< "$FOUNDATION_RESULT"

ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$GIT_RELEASE_TAG" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
echo "configure_environment result = $ENV_RESULT"
IFS=':' read -r GIT_RELEASE_TAG GITHUB_ORG CONFIG_REPO_NAME <<< "$ENV_RESULT"

echo "Final values:"
echo "ENVIRONMENT=$ENVIRONMENT"
echo "GIT_RELEASE_TAG=$GIT_RELEASE_TAG" 
echo "GITHUB_ORG=$GITHUB_ORG"
echo "CONFIG_REPO_NAME=$CONFIG_REPO_NAME"

if [[ "$ENVIRONMENT" == "lab" && 
     "$GIT_RELEASE_TAG" == "develop" && 
     "$GITHUB_ORG" == "Utilities-tkgieng" && 
     "$CONFIG_REPO_NAME" == "config-lab" ]]; then
  echo -e "${GREEN}PASS:${RESET} Integration test"
else
  echo -e "${RED}FAIL:${RESET} Integration test"
fi

echo -e "\n${GREEN}Tests completed.${RESET}"