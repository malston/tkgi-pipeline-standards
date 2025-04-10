#!/usr/bin/env bash
#
# Basic test suite for helper functions
#

# Set -e to fail fast, but only in the top level
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
export -f get_latest_version

# Function to run a test and display result
run_test() {
  local test_name="$1"
  local actual="$2"
  local expected="$3"
  
  echo -e "${YELLOW}Running test: ${test_name}${NC}"
  
  if [ "$actual" == "$expected" ]; then
    echo -e "${GREEN}PASS:${NC} $test_name"
    return 0
  else
    echo -e "${RED}FAIL:${NC} $test_name"
    echo "  Expected: '$expected'"
    echo "  Got:      '$actual'"
    return 1
  fi
}

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# Test wrapper to count results
test() {
  if run_test "$1" "$2" "$3"; then
    ((PASS_COUNT++))
  else
    ((FAIL_COUNT++))
  fi
  echo ""
}

# Environment helper tests
test "configure_environment lab" \
     "$(configure_environment "lab" "" "" "")" \
     "develop:Utilities-tkgieng:config-lab"

test "configure_environment nonprod" \
     "$(configure_environment "nonprod" "" "" "")" \
     "master:Utilities-tkgiops:config-nonprod"

test "configure_environment prod" \
     "$(configure_environment "prod" "" "" "")" \
     "master:Utilities-tkgiops:config-prod"

test "configure_environment with custom values" \
     "$(configure_environment "lab" "custom-branch" "custom-org" "custom-config")" \
     "custom-branch:custom-org:custom-config"

# Version helper tests
test "normalize_version normal" \
     "$(normalize_version "1.2.3")" \
     "1.2.3"

test "normalize_version with v prefix" \
     "$(normalize_version "v1.2.3")" \
     "1.2.3"

test "normalize_version with release-v prefix" \
     "$(normalize_version "release-v1.2.3")" \
     "1.2.3"

test "normalize_version with latest" \
     "$(normalize_version "latest")" \
     "1.0.0"

# Foundation helper tests
test "determine_foundation_environment cml" \
     "$(determine_foundation_environment "cml" "" "" "")" \
     "lab:Utilities-tkgieng:config-lab"

test "determine_foundation_environment cic" \
     "$(determine_foundation_environment "cic" "" "" "")" \
     "lab:Utilities-tkgieng:config-lab"

test "determine_foundation_environment temr" \
     "$(determine_foundation_environment "temr" "" "" "")" \
     "nonprod:Utilities-tkgiops:config-nonprod" 

test "determine_foundation_environment tmpe" \
     "$(determine_foundation_environment "tmpe" "" "" "")" \
     "nonprod:Utilities-tkgiops:config-nonprod"

test "determine_foundation_environment oxdc" \
     "$(determine_foundation_environment "oxdc" "" "" "")" \
     "prod:Utilities-tkgiops:config-prod"

test "determine_foundation_environment svdc" \
     "$(determine_foundation_environment "svdc" "" "" "")" \
     "prod:Utilities-tkgiops:config-prod"

test "determine_foundation_environment with explicit environment" \
     "$(determine_foundation_environment "cml" "nonprod" "" "")" \
     "nonprod:Utilities-tkgiops:config-nonprod"

# Integration test
DC="cml"
ENVIRONMENT=""
GITHUB_ORG=""
CONFIG_REPO_NAME=""
GIT_RELEASE_TAG=""

FOUNDATION_RESULT=$(determine_foundation_environment "$DC" "$ENVIRONMENT" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<< "$FOUNDATION_RESULT"

ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$GIT_RELEASE_TAG" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
IFS=':' read -r GIT_RELEASE_TAG GITHUB_ORG CONFIG_REPO_NAME <<< "$ENV_RESULT"

test "Integration - environment" "$ENVIRONMENT" "lab"
test "Integration - branch" "$GIT_RELEASE_TAG" "develop"
test "Integration - github org" "$GITHUB_ORG" "Utilities-tkgieng"
test "Integration - config repo" "$CONFIG_REPO_NAME" "config-lab"

# Print summary
echo "========================================"
echo "SUMMARY:"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "Total:  $((PASS_COUNT + FAIL_COUNT))"
echo "========================================"

# Return non-zero exit code if any tests failed
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
else
  exit 0
fi