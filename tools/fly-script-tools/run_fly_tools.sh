#!/usr/bin/env bash
# run_fly_tools.sh - Script to run the fly script tools

set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function show_usage() {
    cat <<EOF
Usage: $0 [command] [options]

Commands:
  generate   Generate a new fly.sh script
  validate   Validate an existing fly.sh script
  migrate    Migrate an existing fly.sh script
  test       Run tests for the tools

Options for generate:
  -t, --template TYPE     Template type (kustomize, helm, cli-tool) [default: kustomize]
  -o, --output DIR        Output directory
  -p, --pipeline NAME     Pipeline name
  --alternative-tests     Generate alternative tests

Options for validate:
  -d, --directory DIR     Directory containing fly.sh script
  -o, --output FILE       Output file for report
  -v, --verbose           Show detailed results

Options for migrate:
  -i, --input FILE        Path to existing fly.sh script
  -o, --output DIR        Output directory
  -b, --backup            Create backup of original script
  --alternative-tests     Generate alternative tests
  -v, --verbose           Show detailed steps

Options for test:
  -v, --verbose           Show detailed test output

Examples:
  $0 generate -t kustomize -o /path/to/scripts -p my-pipeline
  $0 validate -d /path/to/scripts -v
  $0 migrate -i /path/to/fly.sh -o /path/to/scripts-new -b
  $0 test
EOF
}

if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

COMMAND=$1
shift

case $COMMAND in
generate)
    python3 "$__DIR/generate_fly_script.py" "$@"
    ;;
validate)
    python3 "$__DIR/validate_fly_script.py" "$@"
    ;;
migrate)
    python3 "$__DIR/migrate_fly_script.py" "$@"
    ;;
test)
    echo "Running tests for fly script tools..."
    python3 -m unittest discover -s "$__DIR/tests"
    ;;
-h|--help)
    show_usage
    exit 0
    ;;
*)
    echo "Unknown command: $COMMAND"
    show_usage
    exit 1
    ;;
esac