#!/usr/bin/env bash
#
# Mock testing for fly.sh commands
#

set -e

# Create test directory
TEST_DIR=$(mktemp -d)
echo "Creating temporary test directory: ${TEST_DIR}"

# Create mock fly command
cat > "${TEST_DIR}/fly" <<EOF
#!/usr/bin/env bash
# Log the command
echo "\$@" > "${TEST_DIR}/fly_command.log"
# Always succeed
exit 0
EOF

chmod +x "${TEST_DIR}/fly"

# Mock the targets command
cat > "${TEST_DIR}/fly_targets_output" <<EOF
name  url                       team  expiry
----  ------------------------  ----  -----
test  https://test.concourse/   main  n/a
EOF

# Modify the fly command to handle the targets subcommand
cat > "${TEST_DIR}/fly" <<EOF
#!/usr/bin/env bash
# If targets command, return mock output
if [[ "\$1" == "targets" ]]; then
  cat "${TEST_DIR}/fly_targets_output"
  exit 0
fi

# Log other commands
echo "\$@" > "${TEST_DIR}/fly_command.log"
# Always succeed
exit 0
EOF

chmod +x "${TEST_DIR}/fly"

# Add test dir to PATH
export PATH="${TEST_DIR}:${PATH}"

# Go to the scripts directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Mock find command for pipelines
mkdir -p "${TEST_DIR}/ci/pipelines"
touch "${TEST_DIR}/ci/pipelines/main.yml"
touch "${TEST_DIR}/ci/pipelines/release.yml"

# Test each command
function test_command() {
  local command="$1"
  local expected="$2"
  local args="$3"
  
  echo "Testing command: ${command}"
  
  # Reset log
  rm -f "${TEST_DIR}/fly_command.log"
  
  # Run command
  ./fly.sh ${args} -f "test-foundation" -t "test" ${command} main >/dev/null 2>&1 || true
  
  # Check if command was executed
  if [[ -f "${TEST_DIR}/fly_command.log" ]]; then
    local output=$(cat "${TEST_DIR}/fly_command.log")
    if echo "$output" | grep -q "$expected"; then
      echo "✓ ${command} command executed correctly"
      return 0
    else
      echo "✗ ${command} command failed to execute correctly"
      echo "Expected: ${expected}"
      echo "Got: ${output}"
      return 1
    fi
  else
    echo "✗ No fly command was executed"
    return 1
  fi
}

# Test all commands
echo "Testing all commands in fly.sh..."
test_command "set" "set-pipeline" "--dry-run"
test_command "unpause" "unpause-pipeline" "--dry-run"
test_command "validate" "validate-pipeline" "--dry-run"
test_command "release" "set-pipeline" "--dry-run"

# Clean up
echo "Cleaning up test environment"
rm -rf "${TEST_DIR}"

echo "All mock tests completed successfully!"
exit 0