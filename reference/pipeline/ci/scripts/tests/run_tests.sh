#!/usr/bin/env bash
#
# run_tests.sh - Run all tests for the fly.sh script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Ensure test directory exists
echo -e "${BLUE}Running all tests for fly.sh...${NC}"

# First, validate that the required files exist
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
CI_DIR="$(cd "${PARENT_DIR}/.." &>/dev/null && pwd)"
FLY_SCRIPT="${PARENT_DIR}/fly.sh"

if [[ ! -f "${FLY_SCRIPT}" ]]; then
    echo -e "${RED}Error: fly.sh script not found at ${FLY_SCRIPT}${NC}"
    exit 1
fi

# Create necessary directories for testing
PIPELINE_DIR="${CI_DIR}/pipelines"
if [[ ! -d "${PIPELINE_DIR}" ]]; then
    echo -e "${YELLOW}Creating pipelines directory at ${PIPELINE_DIR}${NC}"
    mkdir -p "${PIPELINE_DIR}"
fi

# Create dummy pipeline files if they don't exist
MAIN_PIPELINE="${PIPELINE_DIR}/main.yml"
if [[ ! -f "${MAIN_PIPELINE}" ]]; then
    echo -e "${YELLOW}Creating dummy main pipeline file at ${MAIN_PIPELINE}${NC}"
    echo "# Dummy pipeline file for testing" >"${MAIN_PIPELINE}"
fi

# Execute all test_*.sh files
FAILED=0
for test_file in "${SCRIPT_DIR}"/test_*.sh; do
    if [[ -f "${test_file}" ]]; then
        echo -e "${BLUE}Running test: $(basename "${test_file}")${NC}"

        # Make the test file executable if it's not already
        chmod +x "${test_file}"

        # Run the test
        if "${test_file}"; then
            echo -e "${GREEN}Test $(basename "${test_file}") passed${NC}"
        else
            echo -e "${RED}Test $(basename "${test_file}") failed${NC}"
            ((FAILED++))
        fi
        echo ""
    fi
done

# Summary
if [[ ${FAILED} -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${FAILED} test(s) failed!${NC}"
    exit 1
fi
