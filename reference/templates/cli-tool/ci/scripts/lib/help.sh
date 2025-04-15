#!/usr/bin/env bash
#
# Help text and documentation for fly.sh
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Function to show usage information
function show_usage() {
  local exit_code=${1:-0}

  cat <<EOF
Usage: $0 [options] [command] [pipeline_name]

Commands:
  set               Set the main pipeline (default)
  unpause           Set and unpause pipeline
  destroy           Destroy specified pipeline
  validate          Validate pipeline YAML without setting
  release           Create a release pipeline
  set-pipeline      Create the set-pipeline pipeline

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -e, --environment ENV      Environment type (lab|nonprod|prod)
  -b, --branch BRANCH        Git branch for pipeline repository (default: develop)
  -c, --config-branch BRANCH Git branch for config repository (default: master)
  -d, --params-branch BRANCH Params git branch (default: master)
  -p, --pipeline NAME        Custom pipeline name
  -o, --github-org ORG       GitHub organization or Owner
  -v, --version VERSION      Pipeline version

  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity
  --timer DURATION           Set timer trigger duration (default: 3h)

  -h, --help                 Show this help message
  --help [command]           Show help for specific command

Examples:
  $0 -f cml-k8s-n-01
  $0 -f cml-k8s-n-01 unpause
  $0 -f cml-k8s-n-01 -e prod release

For more help, run: $0 --help [command]
EOF

  exit "$exit_code"
}

# Function to show command-specific help
function show_command_help() {
  local command=$1
  local exit_code=${2:-0}

  case "$command" in
    set)
      cat <<EOF
Command: set - Set the main pipeline

Usage: $0 [options] set [pipeline_name]

This command sets the main pipeline in Concourse. If no pipeline name is provided,
the default pipeline name (main-<foundation>) will be used.

Options:
  -f, --foundation NAME      Foundation name (required)
  -b, --branch BRANCH        Git branch for pipeline repository (default: develop)
  -c, --config-branch BRANCH Git branch for config repository (default: master)
  -p, --pipeline NAME        Custom pipeline name
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity

Examples:
  $0 -f cml-k8s-n-01 set
  $0 -f cml-k8s-n-01 -b feature/new-feature set custom-pipeline
EOF
      ;;
    unpause)
      cat <<EOF
Command: unpause - Set and unpause pipeline

Usage: $0 [options] unpause [pipeline_name]

This command sets the pipeline in Concourse and then unpauses it so it starts running
immediately. If no pipeline name is provided, the default pipeline name will be used.

Options:
  -f, --foundation NAME      Foundation name (required)
  -b, --branch BRANCH        Git branch for pipeline repository (default: develop)
  -c, --config-branch BRANCH Git branch for config repository (default: master)
  -p, --pipeline NAME        Custom pipeline name
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity

Examples:
  $0 -f cml-k8s-n-01 unpause
  $0 -f cml-k8s-n-01 -b feature/new-feature unpause custom-pipeline
EOF
      ;;
    destroy)
      cat <<EOF
Command: destroy - Destroy specified pipeline

Usage: $0 [options] destroy <pipeline_name>

This command destroys (removes) the specified pipeline from Concourse.
The pipeline name is required for this command.

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity

Examples:
  $0 -f cml-k8s-n-01 destroy my-pipeline
EOF
      ;;
    validate)
      cat <<EOF
Command: validate - Validate pipeline YAML without setting

Usage: $0 [options] validate [pipeline_name|all]

This command validates the pipeline YAML syntax without setting the pipeline
in Concourse. If 'all' is specified, it validates all pipeline YAML files.

Options:
  -f, --foundation NAME      Foundation name (required for non-local validation)
  -b, --branch BRANCH        Git branch for pipeline repository (default: develop)
  -c, --config-branch BRANCH Git branch for config repository (default: master)
  --verbose                  Increase output verbosity

Examples:
  $0 validate all
  $0 -f cml-k8s-n-01 validate main
EOF
      ;;
    release)
      cat <<EOF
Command: release - Create a release pipeline

Usage: $0 [options] release [version]

This command sets the release pipeline in Concourse. If a version is provided,
it will be used in the pipeline configuration.

Options:
  -f, --foundation NAME      Foundation name (required)
  -e, --environment ENV      Environment type (lab|nonprod|prod, default: lab)
  -v, --version VERSION      Pipeline version
  -p, --pipeline NAME        Custom pipeline name
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity

Examples:
  $0 -f cml-k8s-n-01 release
  $0 -f cml-k8s-n-01 -e prod release 1.2.3
EOF
      ;;
    set-pipeline)
      cat <<EOF
Command: set-pipeline - Create the set-pipeline pipeline

Usage: $0 [options] set-pipeline

This command sets up a pipeline that will automatically update the main pipeline
when changes are pushed to the repository.

Options:
  -f, --foundation NAME      Foundation name (required)
  -b, --branch BRANCH        Git branch for pipeline repository (default: develop)
  -p, --pipeline NAME        Custom pipeline name
  --timer DURATION           Set timer trigger duration (default: 3h)
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity

Examples:
  $0 -f cml-k8s-n-01 set-pipeline
  $0 -f cml-k8s-n-01 --timer 6h set-pipeline
EOF
      ;;
    *)
      show_usage "$exit_code"
      ;;
  esac

  exit "$exit_code"
}

# Function to check help flags and handle them
function check_help_flags() {
  local supported_commands="$1"
  shift
  local args=("$@")

  # Check for help flag
  for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
      -h|--help)
        # Check if next arg is a command
        if (( i+1 < ${#args[@]} )) && [[ "${args[$i+1]}" =~ ^($supported_commands)$ ]]; then
          show_command_help "${args[$i+1]}" 0
        else
          show_usage 0
        fi
        ;;
      --help=*)
        local cmd="${args[$i]#*=}"
        if [[ "$cmd" =~ ^($supported_commands)$ ]]; then
          show_command_help "$cmd" 0
        else
          show_usage 0
        fi
        ;;
    esac
  done
}
