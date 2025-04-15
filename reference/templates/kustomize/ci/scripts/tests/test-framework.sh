#!/usr/bin/env bash
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

# Initialize test variables
__TESTS_DIR="$(mktemp -d)"
__SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
__CURRENT_TEST=""
__TEST_RESULTS=()

# Mark the start of a test
function start_test() {
    local test_name="$1"
    __CURRENT_TEST="$test_name"
    echo -e "\n${YELLOW}Starting test: ${test_name}${NC}"
}

# Mark a test as passed
function test_pass() {
    local message="$1"
    echo -e "${GREEN}✓ ${message}${NC}"
    __TEST_RESULTS+=("PASS: ${__CURRENT_TEST}")
    ((PASSED++))
}

# Mark a test as failed
function test_fail() {
    local where="$1"
    local message="$2"
    echo -e "${RED}✗ FAIL in ${where}: ${message}${NC}"
    __TEST_RESULTS+=("FAIL: ${__CURRENT_TEST} - ${where}: ${message}")
    ((FAILED++))
}

# Run a test function
function run_test() {
    local test_function="$1"
    
    # Reset counters for this test
    PASSED_BEFORE=${PASSED}
    FAILED_BEFORE=${FAILED}
    
    if declare -f "$test_function" >/dev/null; then
        # Run the test function
        if "$test_function"; then
            if [[ ${FAILED} -eq ${FAILED_BEFORE} ]]; then
                echo -e "${GREEN}Test function ${test_function} completed successfully${NC}"
            else
                echo -e "${RED}Test function ${test_function} had failures${NC}"
            fi
        else
            echo -e "${RED}Test function ${test_function} failed to run${NC}"
            ((FAILED++))
        fi
    else
        echo -e "${RED}Test function ${test_function} not found${NC}"
        ((FAILED++))
    fi
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

# Report test results
function report_results() {
    print_summary
    
    # Clean up temp directory
    if [[ -d "${__TESTS_DIR}" ]]; then
        rm -rf "${__TESTS_DIR}"
    fi
    
    # Exit with failure if any tests failed
    if [[ ${FAILED} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}
