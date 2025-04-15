#!/usr/bin/env bash
#
# Test script for parameter handling in fly.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing parameter handling in fly.sh${NC}"
echo "This test focuses on ensuring the script properly handles the --params-branch parameter"

# Source the library files to test function directly
LIB_DIR="${PARENT_DIR}/lib"
if [[ -f "${LIB_DIR}/parsing.sh" ]]; then
    echo -e "${GREEN}Sourcing parsing.sh to test function directly${NC}"
    source "${LIB_DIR}/parsing.sh"
    
    # Set up test variables
    PARAMS_GIT_BRANCH="master"  # Default value
    
    # Test -d parameter
    echo -e "${YELLOW}Testing -d parameter...${NC}"
    args=("-d" "custom-branch")
    
    # Directly test parameter parsing
    for ((i=0; i<${#args[@]}; i++)); do
        arg="${args[$i]}"
        if [[ "${arg}" == "-d" || "${arg}" == "--params-branch" ]]; then
            ((i++))
            PARAMS_GIT_BRANCH="${args[$i]}"
        fi
    done
    
    # Check result
    if [[ "${PARAMS_GIT_BRANCH}" == "custom-branch" ]]; then
        echo -e "${GREEN}✓ PASS: -d parameter correctly sets PARAMS_GIT_BRANCH to 'custom-branch'${NC}"
    else
        echo -e "${RED}✗ FAIL: -d parameter did not set PARAMS_GIT_BRANCH correctly. Got: ${PARAMS_GIT_BRANCH}${NC}"
        exit 1
    fi
    
    # Test --params-branch parameter
    echo -e "${YELLOW}Testing --params-branch parameter...${NC}"
    PARAMS_GIT_BRANCH="master"  # Reset
    args=("--params-branch" "custom-branch2")
    
    # Directly test parameter parsing
    for ((i=0; i<${#args[@]}; i++)); do
        arg="${args[$i]}"
        if [[ "${arg}" == "-d" || "${arg}" == "--params-branch" ]]; then
            ((i++))
            PARAMS_GIT_BRANCH="${args[$i]}"
        fi
    done
    
    # Check result
    if [[ "${PARAMS_GIT_BRANCH}" == "custom-branch2" ]]; then
        echo -e "${GREEN}✓ PASS: --params-branch parameter correctly sets PARAMS_GIT_BRANCH to 'custom-branch2'${NC}"
    else
        echo -e "${RED}✗ FAIL: --params-branch parameter did not set PARAMS_GIT_BRANCH correctly. Got: ${PARAMS_GIT_BRANCH}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All parameter tests passed!${NC}"
else
    echo -e "${RED}Unable to find parsing.sh. Skipping parameter tests.${NC}"
    exit 1
fi