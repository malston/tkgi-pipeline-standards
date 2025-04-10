#!/usr/bin/env bash

# Run and capture all output
cd /Users/markalston/git
./tkgi-pipeline-standards/reference/templates/kustomize/ci/scripts/tests/basic_test_suite.sh \
  | (while IFS= read -r line; do echo "$line"; done) \
  > /tmp/test_full_output.txt 2>&1 || true

# Display output
echo "=== FULL TEST OUTPUT ==="
cat /tmp/test_full_output.txt
echo "=== END TEST OUTPUT ==="

# Check exit code
tail -n 1 /tmp/test_full_output.txt | grep -q "ALL TESTS PASSED"
if [ $? -eq 0 ]; then
  echo "TESTS PASSED!"
else
  echo "TESTS FAILED!"
fi