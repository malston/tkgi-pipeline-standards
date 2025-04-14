#!/usr/bin/env bash
#
# test_fly_basics.sh - Basic tests for the fly.sh script
# Organization: ${org_name}
# Repository: ${repo_name}
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
CI_DIR="$(cd "${PARENT_DIR}/.." &>/dev/null && pwd)"

# Source test framework
source "${SCRIPT_DIR}/test-framework.sh"

# Source fly.sh script
source "${PARENT_DIR}/fly.sh"

# Reset global variables before tests
function setup() {
    COMMAND="set"
    PIPELINE="${default_pipeline}"
    FOUNDATION=""
    TARGET=""
    BRANCH="${default_branch}"
    VERBOSE="false"
    DRY_RUN="false"
}

# Mock functions to capture calls instead of executing them
function fly() {
    echo "fly $*" >>"${SCRIPT_DIR}/fly_output.log"
    return 0
}

# Clear output log before tests
if [[ -f "${SCRIPT_DIR}/fly_output.log" ]]; then
    rm "${SCRIPT_DIR}/fly_output.log"
fi
touch "${SCRIPT_DIR}/fly_output.log"

# Test parsing of command line arguments
describe "Argument Parsing"

it "should parse foundation flag"
setup
ARGS=("-f" "${default_foundation}")
process_args "${SUPPORTED_COMMANDS}" "${ARGS[@]}"
assert_equals "${default_foundation}" "${FOUNDATION}" "Foundation should be set correctly"

it "should parse verbose flag"
setup
ARGS=("-f" "${default_foundation}" "-v")
process_args "${SUPPORTED_COMMANDS}" "${ARGS[@]}"
assert_equals "true" "${VERBOSE}" "Verbose flag should be set to true"

it "should parse pipeline flag"
setup
ARGS=("-f" "${default_foundation}" "-p" "custom")
process_args "${SUPPORTED_COMMANDS}" "${ARGS[@]}"
assert_equals "custom" "${PIPELINE}" "Pipeline should be set correctly"

it "should parse branch flag"
setup
ARGS=("-f" "${default_foundation}" "-b" "main")
process_args "${SUPPORTED_COMMANDS}" "${ARGS[@]}"
assert_equals "main" "${BRANCH}" "Branch should be set correctly"

it "should parse command as positional argument"
setup
ARGS=("-f" "${default_foundation}" "unpause")
process_args "${SUPPORTED_COMMANDS}" "${ARGS[@]}"
assert_equals "unpause" "${COMMAND}" "Command should be set correctly"

it "should set default command to 'set' if not specified"
setup
ARGS=("-f" "${default_foundation}")
process_args "${SUPPORTED_COMMANDS}" "${ARGS[@]}"
assert_equals "set" "${COMMAND}" "Default command should be 'set'"

# Test datacenter extraction functions
describe "Foundation parsing"

it "should extract datacenter from foundation name"
DC=$(get_datacenter "${default_foundation}")
assert_equals "${default_foundation%%-*}" "${DC}" "Datacenter should be extracted correctly"

it "should extract datacenter type from foundation name"
DCTYPE=$(get_datacenter_type "${default_foundation}")
foundation_parts=(${default_foundation//-/ })
expected_dctype="${foundation_parts[1]}"
assert_equals "${expected_dctype}" "${DCTYPE}" "Datacenter type should be extracted correctly"

# Print test summary
print_summary
if [[ ${FAILED} -gt 0 ]]; then
    exit 1
fi
