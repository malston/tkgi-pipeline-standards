#!/usr/bin/env bash
#
# Mock functions for testing fly.sh
#

# Mock fly command function
function mock_fly() {
  local command="$1"
  local pipeline_name="$2"
  local exit_code="${3:-0}"

  echo "Creating mock fly function that returns $exit_code for 'fly $command $pipeline_name'"
  
  # Create global fly function to capture calls
  function fly() {
    echo "MOCK FLY CALLED: fly $*" >> "${SCRIPT_DIR}/fly_output.log"
    return "$exit_code"
  }
  export -f fly
}