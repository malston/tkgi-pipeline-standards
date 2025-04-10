#!/usr/bin/env bash
#
# Simple direct test of the helper functions
#

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../lib" &>/dev/null && pwd)"

echo "Loading environment.sh..."
source "${HELPERS_DIR}/environment.sh"
echo "Loading version.sh..."
source "${HELPERS_DIR}/version.sh"
echo "Loading foundation.sh..."
source "${HELPERS_DIR}/foundation.sh"

# Mock get_latest_version
function get_latest_version() {
  echo "1.0.0"
}
export -f get_latest_version

echo "Testing configure_environment..."
result=$(configure_environment "lab" "" "" "")
echo "Result: $result"
expected="develop:Utilities-tkgieng:config-lab"
if [[ "$result" == "$expected" ]]; then
  echo "PASS: configure_environment lab"
else
  echo "FAIL: configure_environment lab. Expected: $expected, Got: $result"
fi

echo "Testing normalize_version..."
result=$(normalize_version "v1.2.3")
echo "Result: $result"
expected="1.2.3"
if [[ "$result" == "$expected" ]]; then
  echo "PASS: normalize_version v1.2.3"
else
  echo "FAIL: normalize_version v1.2.3. Expected: $expected, Got: $result"
fi

echo "Testing determine_foundation_environment..."
result=$(determine_foundation_environment "cml" "" "" "")
echo "Result: $result"
expected="lab:Utilities-tkgieng:config-lab"
if [[ "$result" == "$expected" ]]; then
  echo "PASS: determine_foundation_environment cml"
else
  echo "FAIL: determine_foundation_environment cml. Expected: $expected, Got: $result"
fi

echo "All tests completed."