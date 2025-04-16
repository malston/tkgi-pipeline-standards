#!/usr/bin/env bash

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
#
# test_framework.sh - Simple test framework for the fly.sh script
#

# Define colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counter for passed and failed tests
PASSED=0
FAILED=0

# Enable test mode to avoid actual fly commands
export TEST_MODE=true

# Define helpers for assertions
function assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "${expected}" == "${actual}" ]]; then
        echo -e "${GREEN}✓ ${message}${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${message}${NC}"
        echo -e "  Expected: ${expected}"
        echo -e "  Actual:   ${actual}"
        ((FAILED++))
        return 1
    fi
}

function assert_contains() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "${actual}" == *"${expected}"* ]]; then
        echo -e "${GREEN}✓ ${message}${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${message}${NC}"
        echo -e "  Expected to contain: ${expected}"
        echo -e "  Actual: ${actual}"
        ((FAILED++))
        return 1
    fi
}

function assert_true() {
    local condition="$1"
    local message="$2"

    if [[ "${condition}" == "true" ]]; then
        echo -e "${GREEN}✓ ${message}${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${message}${NC}"
        echo -e "  Expected: true"
        echo -e "  Actual:   ${condition}"
        ((FAILED++))
        return 1
    fi
}

function assert_false() {
    local condition="$1"
    local message="$2"

    if [[ "${condition}" == "false" ]]; then
        echo -e "${GREEN}✓ ${message}${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${message}${NC}"
        echo -e "  Expected: false"
        echo -e "  Actual:   ${condition}"
        ((FAILED++))
        return 1
    fi
}

function describe() {
    local description="$1"
    echo -e "\n${BLUE}${description}${NC}"
}

function it() {
    local description="$1"
    echo -e "${YELLOW}  ${description}${NC}"
}

# Print test summary
function print_summary() {
    echo -e "\n${BLUE}Test Summary:${NC}"
    echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
    echo -e "  ${RED}Failed: ${FAILED}${NC}"

    if [[ ${FAILED} -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        return 1
    fi
}
