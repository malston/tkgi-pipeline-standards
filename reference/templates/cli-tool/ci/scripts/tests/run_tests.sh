#!/usr/bin/env bash
#
# run_tests.sh - Run all tests for the fly.sh script
#

# Enable strict mode
set -o errexit
set -o pipefail

# Disable strict mode for more resilient testing
set +e

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
CI_DIR="$(cd "${PARENT_DIR}/.." &>/dev/null && pwd)"
FLY_SCRIPT="${PARENT_DIR}/fly.sh"
PIPELINE_DIR="${CI_DIR}/pipelines"

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Functions for output
function echo_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

function info() {
    echo_color "$YELLOW" "INFO: $1"
}

function success() {
    echo_color "$GREEN" "SUCCESS: $1"
}

function error() {
    echo_color "$RED" "ERROR: $1" >&2
}

# Setup common test environment
function setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Validate that the required files exist
    if [[ ! -f "${FLY_SCRIPT}" ]]; then
        echo -e "${RED}Error: fly.sh script not found at ${FLY_SCRIPT}${NC}"
        exit 1
    fi
    
    # Create necessary directories for testing
    if [[ ! -d "${PIPELINE_DIR}" ]]; then
        echo -e "${YELLOW}Creating pipelines directory at ${PIPELINE_DIR}${NC}"
        mkdir -p "${PIPELINE_DIR}"
    fi
    
    # Create dummy pipeline files if they don't exist
    MAIN_PIPELINE="${PIPELINE_DIR}/main.yml"
    if [[ ! -f "${MAIN_PIPELINE}" ]]; then
        echo -e "${YELLOW}Creating dummy main pipeline file at ${MAIN_PIPELINE}${NC}"
        echo "# Dummy pipeline file for testing" > "${MAIN_PIPELINE}"
    fi
    
    # Create release pipeline if needed
    RELEASE_PIPELINE="${PIPELINE_DIR}/release.yml"
    if [[ ! -f "${RELEASE_PIPELINE}" ]]; then
        echo -e "${YELLOW}Creating dummy release pipeline file at ${RELEASE_PIPELINE}${NC}"
        echo "# Dummy release pipeline file for testing" > "${RELEASE_PIPELINE}"
    fi
}

# Cleanup function to remove files created during tests
function cleanup_test_files() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    
    # Remove temporary log files
    if [[ -f "${SCRIPT_DIR}/fly_output.log" ]]; then
        rm -f "${SCRIPT_DIR}/fly_output.log"
    fi
    
    # Only remove files we created if they contain our test content
    if [[ -f "${PIPELINE_DIR}/main.yml" && "$(cat "${PIPELINE_DIR}/main.yml" 2>/dev/null)" == "# Dummy pipeline file for testing" ]]; then
        rm -f "${PIPELINE_DIR}/main.yml"
    fi
    
    if [[ -f "${PIPELINE_DIR}/release.yml" && "$(cat "${PIPELINE_DIR}/release.yml" 2>/dev/null)" == "# Dummy release pipeline file for testing" ]]; then
        rm -f "${PIPELINE_DIR}/release.yml"
    fi
    
    # Only remove the directory if it's empty and we created it
    if [[ -d "${PIPELINE_DIR}" && -z "$(ls -A "${PIPELINE_DIR}" 2>/dev/null)" ]]; then
        rmdir "${PIPELINE_DIR}" 2>/dev/null || true
    fi
}

# Set up trap to clean up on exit
trap cleanup_test_files EXIT

# Main test runner function
function run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    echo -e "${BLUE}Running test: ${test_name}${NC}"
    
    # Make the test file executable if it's not already
    chmod +x "${test_file}"
    
    # Run the test
    if "${test_file}"; then
        echo -e "${GREEN}Test ${test_name} passed${NC}"
        return 0
    else
        echo -e "${RED}Test ${test_name} failed${NC}"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}Running all tests for fly.sh...${NC}"

# Setup test environment
setup_test_env

# Find and execute all test_*.sh files
TEST_FILES=("${SCRIPT_DIR}"/test_*.sh)

# Check if there are any test files
if [ ${#TEST_FILES[@]} -eq 0 ]; then
    error "No test files found!"
    exit 1
fi

# Run each test file
FAILED=0
for test_file in "${TEST_FILES[@]}"; do
    if [[ -f "${test_file}" ]]; then
        if ! run_test_file "${test_file}"; then
            ((FAILED++))
        fi
        echo ""
    fi
done

# Summary
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}============${NC}"
echo "Total tests: ${#TEST_FILES[@]}"

if [[ ${FAILED} -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${FAILED} test(s) failed!${NC}"
    exit 1
fi
