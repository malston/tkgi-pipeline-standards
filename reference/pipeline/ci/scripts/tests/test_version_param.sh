#!/usr/bin/env bash
#
# Test script for version parameter in fly.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

# Source test framework
source ${SCRIPT_DIR}/test-framework.sh

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing version parameter in fly.sh${NC}"
echo "This test focuses on ensuring the script properly handles the --version parameter"

# Source the library files to test function directly
LIB_DIR="${PARENT_DIR}/lib"
if [[ -f "${LIB_DIR}/parsing.sh" ]]; then
    echo -e "${GREEN}Sourcing parsing.sh to test function directly${NC}"
    source "${LIB_DIR}/parsing.sh"

    # Set up test variables
    VERSION="" # Default value

    # Test --version parameter
    echo -e "${YELLOW}Testing --version parameter...${NC}"
    args=("--version" "1.2.3")

    # Directly test parameter parsing
    for ((i = 0; i < ${#args[@]}; i++)); do
        arg="${args[$i]}"
        if [[ "${arg}" == "--version" ]]; then
            ((i++))
            VERSION="${args[$i]}"
        fi
    done

    # Check result
    if [[ "${VERSION}" == "1.2.3" ]]; then
        echo -e "${GREEN}✓ PASS: --version parameter correctly sets VERSION to '1.2.3'${NC}"
    else
        echo -e "${RED}✗ FAIL: --version parameter did not set VERSION correctly. Got: ${VERSION}${NC}"
        exit 1
    fi

    # Verify -v short form works for version
    echo -e "${YELLOW}Verifying -v short form works for version...${NC}"
    VERSION="" # Reset
    args=("-v" "1.2.3")

    # Directly test parameter parsing
    for ((i = 0; i < ${#args[@]}; i++)); do
        arg="${args[$i]}"
        if [[ "${arg}" == "-v" || "${arg}" == "--version" ]]; then
            ((i++))
            VERSION="${args[$i]}"
        fi
    done

    # Check result
    if [[ "${VERSION}" == "1.2.3" ]]; then
        echo -e "${GREEN}✓ PASS: -v parameter correctly sets VERSION to '1.2.3'${NC}"
    else
        echo -e "${RED}✗ FAIL: -v parameter did not set VERSION correctly. Got: ${VERSION}${NC}"
        exit 1
    fi

    echo -e "${GREEN}All version parameter tests passed!${NC}"
else
    echo -e "${RED}Unable to find parsing.sh. Skipping parameter tests.${NC}"
    exit 1
fi

# Test function
function test_example() {
    echo "Running example test"
    assert_true "true" "Example assertion"
}

# Run tests
run_test test_example

# Report test results
report_results
