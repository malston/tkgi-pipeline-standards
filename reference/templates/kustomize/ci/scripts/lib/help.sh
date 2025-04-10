#!/usr/bin/env bash
#
# Help command module for fly.sh
# Contains functions related to displaying help messages
#

# Function to display command-specific usage
function show_command_usage() {
  local command="$1"
  
  case "$command" in
    set)
      cat << USAGE_SET
Command: set
Description: Set a pipeline in Concourse

Usage: ./fly.sh [options] set [pipeline_name]

Sets a pipeline configuration to Concourse. This is the default command when none is specified.

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -e, --environment ENV      Environment type (lab|nonprod|prod)
  -p, --pipeline NAME        Pipeline name to set (default: main)
  --dry-run                  Show what would be executed without making changes

Example:
  ./fly.sh -f cml-k8s-n-01 set main
  ./fly.sh -f cml-k8s-n-01 -e lab set main --dry-run
USAGE_SET
      ;;
    unpause)
      cat << USAGE_UNPAUSE
Command: unpause
Description: Set and unpause a pipeline in Concourse

Usage: ./fly.sh [options] unpause [pipeline_name]

Sets a pipeline and immediately unpauses it so it starts running.

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -e, --environment ENV      Environment type (lab|nonprod|prod)
  -p, --pipeline NAME        Pipeline name to unpause (default: main)
  --dry-run                  Show what would be executed without making changes

Example:
  ./fly.sh -f cml-k8s-n-01 unpause main
  ./fly.sh -f cml-k8s-n-01 -e lab unpause main --dry-run
USAGE_UNPAUSE
      ;;
    destroy)
      cat << USAGE_DESTROY
Command: destroy
Description: Destroy a pipeline in Concourse

Usage: ./fly.sh [options] destroy [pipeline_name]

Permanently deletes a pipeline from Concourse. 
Will prompt for confirmation unless pipe input is detected.

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -p, --pipeline NAME        Pipeline name to destroy (default: main)
  --dry-run                  Show what would be executed without making changes

Example:
  ./fly.sh -f cml-k8s-n-01 destroy main
  ./fly.sh -f cml-k8s-n-01 destroy main --dry-run
USAGE_DESTROY
      ;;
    validate)
      cat << USAGE_VALIDATE
Command: validate
Description: Validate a pipeline YAML without setting it

Usage: ./fly.sh [options] validate [pipeline_name|all]

Validates the syntax of a pipeline YAML file without setting it in Concourse.
Specify 'all' to validate all pipelines in the pipelines directory.

Options:
  -f, --foundation NAME      Foundation name (required for some validations)
  -p, --pipeline NAME        Pipeline name to validate (default: main)
  --dry-run                  Show what would be executed without making changes

Example:
  ./fly.sh -f cml-k8s-n-01 validate main
  ./fly.sh validate all
USAGE_VALIDATE
      ;;
    release)
      cat << USAGE_RELEASE
Command: release
Description: Create a release pipeline

Usage: ./fly.sh [options] release

Sets up a release pipeline for creating and managing software releases.
This is equivalent to setting the pipeline named 'release'.

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -e, --environment ENV      Environment type (lab|nonprod|prod)
  -v, --version VERSION      Pipeline version
  --dry-run                  Show what would be executed without making changes

Example:
  ./fly.sh -f cml-k8s-n-01 release
  ./fly.sh -f cml-k8s-n-01 -e lab release --dry-run
USAGE_RELEASE
      ;;
    *)
      # If no specific command is given, show the general usage
      show_general_usage "${1:-1}"
      ;;
  esac
}

# Function to display general usage
function show_general_usage() {
  cat << USAGE
Script: fly.sh
Description: Enhanced pipeline management script that combines simple usage with advanced commands

Usage: ./fly.sh [options] [command] [pipeline_name]

Commands:
  set          Set pipeline (default)
  unpause      Set and unpause pipeline
  destroy      Destroy specified pipeline
  validate     Validate pipeline YAML without setting
  release      Create a release pipeline

Options:
  -f, --foundation NAME      Foundation name (required)
  -t, --target TARGET        Concourse target (default: <foundation>)
  -e, --environment ENV      Environment type (lab|nonprod|prod)
  -b, --branch BRANCH        Git branch for pipeline repository
  -c, --config-branch BRANCH Git branch for config repository
  -d, --params-branch BRANCH Params git branch (default: master)
  -p, --pipeline NAME        Custom pipeline name prefix
  -o, --github-org ORG       GitHub organization
  -v, --version VERSION      Pipeline version
  --release                  Create a release pipeline
  --set-release-pipeline     Set the release pipeline
  --dry-run                  Simulate without making changes
  --verbose                  Increase output verbosity
  --debug                    Show line numbers in log messages
  --timer DURATION           Set timer trigger duration
  --enable-validation-testing Enable validation testing
  -h, --help                 Show this help message and exit
  
For more detailed help on a specific command, use any of these formats:
  ./fly.sh --help [command]   Example: ./fly.sh --help set
  ./fly.sh -h [command]       Example: ./fly.sh -h unpause
  ./fly.sh [command] --help   Example: ./fly.sh destroy --help
  ./fly.sh [command] -h       Example: ./fly.sh validate -h
USAGE
  exit "${1:-1}"
}

# Function to display usage (maintains backward compatibility)
function show_usage() {
  # Default to general usage
  show_general_usage "${1:-1}"
}