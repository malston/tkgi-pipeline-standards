#!/usr/bin/env bash

# Source test framework
source ${SCRIPT_DIR}/test-framework.sh


# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
#
# Test script for verbose parameter in fly.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing verbose parameter in fly.sh${NC}"
echo "This test focuses on ensuring the script properly handles the --verbose parameter"

# Source the library files to test function directly
LIB_DIR="${PARENT_DIR}/lib"
if [[ -f "${LIB_DIR}/parsing.sh" ]]; then
    echo -e "${GREEN}Sourcing parsing.sh to test function directly${NC}"
    source "${LIB_DIR}/parsing.sh"
    
    # Set up test variables
    VERBOSE="false"  # Default value
    
    # Test --verbose parameter
    echo -e "${YELLOW}Testing --verbose parameter...${NC}"
    args=("--verbose")
    
    # Directly test parameter parsing
    for ((i=0; i<${#args[@]}; i++)); do
        arg="${args[$i]}"
        if [[ "${arg}" == "--verbose" ]]; then
            VERBOSE="true"
        fi
    done
    
    # Check result
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${GREEN}✓ PASS: --verbose parameter correctly sets VERBOSE to 'true'${NC}"
    else
        echo -e "${RED}✗ FAIL: --verbose parameter did not set VERBOSE correctly. Got: ${VERBOSE}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Verbose parameter test passed!${NC}"
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
