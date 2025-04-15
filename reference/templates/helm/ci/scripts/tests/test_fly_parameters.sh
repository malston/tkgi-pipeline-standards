#!/usr/bin/env bash
#
# Test script for fly.sh parameters and pipeline setting
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/test-framework.sh"

# Path to the fly.sh script we're testing
FLY_SCRIPT="${__SCRIPTS_DIR}/../fly.sh"
export TEST_MODE=true

# Create a temp directory for our tests
TEST_TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

# Test pipeline setting with different parameter combinations
function test_pipeline_params() {
    start_test "Pipeline parameters handling"

    # Mock fly command
    cat >"${TEST_TMP_DIR}/fly" <<EOF
#!/usr/bin/env bash
echo "MOCK FLY CALLED WITH: \$@" > "${TEST_TMP_DIR}/fly_output.log"
exit 0
EOF
    chmod +x "${TEST_TMP_DIR}/fly"
    export PATH="${TEST_TMP_DIR}:${PATH}"

    # Create test pipeline files
    mkdir -p "${__SCRIPTS_DIR}/../pipelines"
    touch "${__SCRIPTS_DIR}/../pipelines/main.yml"
    touch "${__SCRIPTS_DIR}/../pipelines/custom.yml"

    # Run the script with custom pipeline parameter
    "${FLY_SCRIPT}" -f test-foundation -t test-target -p custom >/dev/null 2>&1

    # Check if correct fly command was executed with custom pipeline
    if [[ -f "${TEST_TMP_DIR}/fly_output.log" ]]; then
        local output=$(cat "${TEST_TMP_DIR}/fly_output.log")
        if ! echo "$output" | grep -q -- "-p custom-test-foundation"; then
            test_fail "pipeline parameter" "Command should set pipeline with custom name, but got: $output"
        fi
        if ! echo "$output" | grep -q -- "custom.yml"; then
            test_fail "pipeline file" "Command should use custom pipeline file, but got: $output"
        fi
    else
        test_fail "custom pipeline execution" "No fly command was executed"
    fi

    test_pass "Pipeline parameters handled correctly"
}

# Test branch parameter
function test_branch_param() {
    start_test "Branch parameter handling"

    # Mock fly command
    cat >"${TEST_TMP_DIR}/fly" <<EOF
#!/usr/bin/env bash
echo "MOCK FLY CALLED WITH: \$@" > "${TEST_TMP_DIR}/fly_output.log"
exit 0
EOF
    chmod +x "${TEST_TMP_DIR}/fly"
    export PATH="${TEST_TMP_DIR}:${PATH}"

    # Create test directory and files
    mkdir -p "${__SCRIPTS_DIR}/../pipelines"
    touch "${__SCRIPTS_DIR}/../pipelines/main.yml"

    # Run the script with custom branch parameter
    "${FLY_SCRIPT}" -f test-foundation -t test-target -b feature-branch >/dev/null 2>&1

    # Check if correct branch parameter was passed
    if [[ -f "${TEST_TMP_DIR}/fly_output.log" ]]; then
        local output=$(cat "${TEST_TMP_DIR}/fly_output.log")
        if ! echo "$output" | grep -q -- "branch=feature-branch"; then
            test_fail "branch parameter" "Command should set custom branch, but got: $output"
        fi
    else
        test_fail "branch parameter" "No fly command was executed"
    fi

    test_pass "Branch parameter handled correctly"
}

# Test params branch parameter
function test_params_repo() {
    start_test "Params branch parameter handling"

    # Mock fly command
    cat >"${TEST_TMP_DIR}/fly" <<EOF
#!/usr/bin/env bash
echo "MOCK FLY CALLED WITH: \$@" > "${TEST_TMP_DIR}/fly_output.log"
exit 0
EOF
    chmod +x "${TEST_TMP_DIR}/fly"
    export PATH="${TEST_TMP_DIR}:${PATH}"

    # Create test directory and files
    mkdir -p "${__SCRIPTS_DIR}/../pipelines"
    touch "${__SCRIPTS_DIR}/../pipelines/main.yml"

    # Run the script with custom params branch
    "${FLY_SCRIPT}" -f test-foundation -t test-target -d custom-branch >/dev/null 2>&1

    # Check if params_git_branch is set correctly
    if [[ -f "${TEST_TMP_DIR}/fly_output.log" ]]; then
        local output=$(cat "${TEST_TMP_DIR}/fly_output.log")
        if ! echo "$output" | grep -q -- "params_git_branch=custom-branch"; then
            test_fail "params repo parameter" "Command should use custom params branch, but got: $output"
        fi
    else
        test_fail "params repo parameter" "No fly command was executed"
    fi

    test_pass "Params branch parameter handled correctly"
}

# Note: Verbose parameter testing is now in a separate file: test_verbose_param.sh

# Run all tests
run_test test_pipeline_params
run_test test_branch_param
run_test test_params_repo
# Verbose parameter is tested in a separate file (test_verbose_param.sh)

# Report test results
report_results
