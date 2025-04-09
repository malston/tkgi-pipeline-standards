# CI/CD Standardization Guide for TKGi Repositories

This document defines the standards for CI/CD pipeline organization across all TKGi pipeline repositories.

## Repository Structure

This repository contains:

1. **Standards Documentation**: This guide defines the standards for CI/CD pipeline structure
2. **Reference Templates**: Example implementations of standardized CI/CD patterns for different project types
3. **Migration Plans**: Guides for migrating existing repositories to follow these standards
4. **Scripts**: Utility scripts for creating and validating standardized repositories

### Repository Relationships

This repository works together with the following related repositories:

- **params**: Contains environment-specific parameters (symlinked in `reference/templates/params`)
- **ns-mgmt**: Reference implementation of these standards
- **config-lab**: Configuration for lab environment

### Symlinks

This repository uses symlinks to reference related repositories:

- `reference/templates/params` → `../../../params`: Points to the params repository at the same level as this repository. This allows reference implementations to access foundation-specific configuration parameters without duplicating files.

For this symlink to work correctly, the `params` repository should be cloned at the same level as this repository:

```
git-root/
├── tkgi-pipeline-standards/
└── params/
```

## 1. Folder Structure

All repositories should follow this standard structure:

```sh
repository-root/
├── ci/
│   ├── pipelines/            # Pipeline definition files
│   │   ├── main.yml          # Main pipeline
│   │   ├── release.yml       # Release pipeline
│   │   └── set-pipeline.yml  # Pipeline setup pipeline
│   ├── scripts/              # Pipeline control scripts
│   │   ├── fly.sh            # Standardized pipeline management script
│   │   ├── helpers.sh        # Helper functions (if needed)
│   │   └── tests/            # Test scripts for CI scripts
│   ├── tasks/                # Task definitions organized by category
│   │   ├── common/           # Common/shared tasks
│   │   │   ├── kapply/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   ├── kustomize/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── ...
│   │   ├── k8s/              # Kubernetes-specific tasks
│   │   │   ├── create-namespaces/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   ├── validate-namespaces/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── ...
│   │   ├── tkgi/             # TKGi-specific tasks
│   │   │   ├── tkgi-login/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── ...
│   │   └── testing/          # Testing tasks
│   │       ├── run-unit-tests/
│   │       │   ├── task.yml
│   │       │   └── task.sh
│   │       └── ...
│   └── README.md             # Documentation for CI process
└── scripts/                  # Repository-level scripts
    ├── apply.sh
    ├── build.sh
    └── ...
```

## 2. `fly.sh` Command Interface

All repositories should use a standardized `fly.sh` script with a consistent interface:

```sh
./ci/scripts/fly.sh [options] [command] [pipeline_name]
```

### Standard Commands

- `set`: Set pipeline (default)
- `unpause`: Set and unpause pipeline
- `destroy`: Destroy specified pipeline
- `validate`: Validate pipeline YAML without setting
- `release`: Create a release pipeline

### Command-Specific Help

The `fly.sh` script provides detailed help for each specific command. You can get command-specific help using any of these formats:

```sh
./fly.sh --help [command]     # Example: ./fly.sh --help set
./fly.sh -h [command]         # Example: ./fly.sh -h unpause
./fly.sh [command] --help     # Example: ./fly.sh destroy --help
./fly.sh [command] -h         # Example: ./fly.sh validate -h
```

This provides more detailed usage information specific to each command, rather than the general usage help.

### Standard Options

```
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
--timer DURATION           Set timer trigger duration
--enable-validation-testing Enable validation testing
-h, --help                 Show help message
--help [command]           Show help for specific command (e.g., --help set)
```

## 3. Task Organization

Tasks are organized by functional category with consistent structure:

1. **Task Directory**: Each task has its own directory named after the task function
2. **Task Files**: Each task directory contains:
   - `task.yml`: Task YAML definition
   - `task.sh`: Task implementation script
3. **Common Tasks**: Reusable tasks are stored in `ci/tasks/common/` until they can be moved to a shared repository

### Common Tasks
Place reusable utility tasks and general-purpose operations:
- `common/kapply/`: Kubernetes resource application task
- `common/kubectl-apply/`: Kubernetes resource application task (kustomize template)
- `common/kustomize/`: Kustomize resource generation task
- `common/make-git-commit/`: Git commit creation task
- `common/prepare-kustomize/`: Kustomize preparation task
- `common/create-release-info/`: Generate release information for GitHub releases

### K8s Tasks
Place Kubernetes-specific operational tasks:
- `k8s/create-legacy-netpol/`: Legacy network policy creation task
- `k8s/create-legacy-rbac/`: Legacy RBAC resource creation task
- `k8s/create-limits-quotas/`: Resource limits and quotas creation task
- `k8s/create-namespaces/`: Namespace creation task
- `k8s/delete-namespaces/`: Namespace deletion task
- `k8s/validate-namespaces/`: Namespace validation task
- `k8s/create-resources/`: Creates Kubernetes resources (kustomize template)
- `k8s/validate-resources/`: Validates Kubernetes resources (kustomize template)

### TKGi Tasks
Place TKGi-specific operations:
- `tkgi/tkgi-login/`: TKGi authentication task

### Testing Tasks
Place testing tasks:
- `testing/run-unit-tests/`: Execute unit tests
- `testing/run-integration-tests/`: Execute integration tests
- `testing/run-tests/`: Execute tests (kustomize template)

## 4. Task YAML Standards

Each task.yml file should follow this structure:

```yaml
platform: linux
inputs:
  - name: repo-name   # Repository containing the task script
  - name: input1      # Other inputs as needed
outputs:
  - name: output1     # Outputs as needed
run:
  path: repo-name/ci/tasks/<category>/<task-name>/task.sh
  args:
    - arg1
    - arg2
params:
  PARAM1: ((param1))
  PARAM2: ((param2))
```

## 5. Pipeline YAML Standards

1. **Naming Convention**:
   - Main pipeline: `main.yml`
   - Release pipeline: `release.yml`
   - Pipeline setup: `set-pipeline.yml`

2. **Structure**:
   - Use groups to organize jobs logically
   - Include descriptive job and task names
   - Use consistent resource naming

3. **Task Reference**:
   - Reference task YAML files rather than defining tasks inline
   - Example: `file: repo-name/ci/tasks/common/kustomize/task.yml`
   - For inline tasks that still need to be converted, use paths relative to the repository root:
     ```yaml
     task: kustomize
     config:
       platform: linux
       inputs:
         - name: repo-name
       run:
         path: repo-name/ci/tasks/common/kustomize/task.sh
     ```

## 6. Script Standards

All scripts should follow these standards:

1. **Shebang**: Start with `#!/usr/bin/env bash`
2. **Strict Mode**: Include `set -o errexit` and `set -o pipefail`
3. **Script Directory**: Use `__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"`
4. **Help Documentation**: Include usage information
5. **Error Handling**: Implement proper error handling and validation
6. **Exit Codes**: Use meaningful exit codes
7. **Logging**: Include clear logging with error/success messaging
8. **Testing**: Include automated tests for all scripts

### Testing Standards

All critical scripts should be tested using the included test framework:

1. **Test Directory**: Each scripts directory should include a `tests/` subdirectory
2. **Test Framework**: Use the common test framework provided in `test_framework.sh`
3. **Test Runner**: Include a `run_tests.sh` script to execute all tests
4. **Test Coverage**: Each script should have corresponding test cases
5. **Mock Functions**: Use mock functions to simulate dependencies
6. **Assertions**: Use assertions to validate script behavior

Example test framework usage:

```bash
# Source test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Define test functions
function test_command_execution() {
  start_test "Command execution"

  # Mock command
  mock_command "expected_args"

  # Execute script
  "../my_script.sh" -f test_arg

  # Assert expectations
  assert_contains "$(get_last_command)" "expected_args"

  test_pass "Command execution test"
}

# Run tests
run_test test_command_execution
report_results
```

### Example Script Template

```bash
#!/usr/bin/env bash
#
# Script: example.sh
# Description: Enhanced script template that follows our standards
#
# Usage: ./example.sh [options] [command] [argument]
#
# Commands:
#   command1    First command description
#   command2    Second command description
#   command3    Third command description
#
# Options:
#   -f, --flag1 VALUE    First flag description (required)
#   -o, --flag2 VALUE    Second flag description
#   --option1            Boolean option description
#   --dry-run            Simulate without making changes
#   --verbose            Increase output verbosity
#   -h, --help           Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions if available
if [[ -f "${__DIR}/helpers.sh" ]]; then
  source "${__DIR}/helpers.sh"
fi

# Default values
COMMAND="command1"
DRY_RUN=false
VERBOSE=false

# Function to display usage
function show_usage() {
  cat << USAGE
Script: example.sh
Description: Enhanced script template that follows our standards

Usage: ./example.sh [options] [command] [argument]

Commands:
  command1    First command description
  command2    Second command description
  command3    Third command description

Options:
  -f, --flag1 VALUE    First flag description (required)
  -o, --flag2 VALUE    Second flag description
  --option1            Boolean option description
  --dry-run            Simulate without making changes
  --verbose            Increase output verbosity
  -h, --help           Show this help message
USAGE
  exit 1
}

# Function to log info messages
function info() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[INFO] [${timestamp}] $1"
}

# Function to log error messages
function error() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[ERROR] [${timestamp}] $1" >&2
}

# Function to log success messages
function success() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[SUCCESS] [${timestamp}] $1"
}

# Parse arguments - supporting both getopt and traditional argument parsing
SUPPORTED_OPTIONS="f:o:h"
SUPPORTED_LONG_OPTIONS="flag1:,flag2:,option1,dry-run,verbose,help"

# Try to use getopt for enhanced option parsing
if getopt -T &>/dev/null && [[ $? -eq 4 ]]; then
  # Enhanced getopt is available
  TEMP=$(getopt -o "$SUPPORTED_OPTIONS" --long "$SUPPORTED_LONG_OPTIONS" -n "$0" -- "$@" 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    eval set -- "$TEMP"
    # Parse using getopt
    while true; do
      case "$1" in
        -f|--flag1)
          FLAG1="$2"
          shift 2
          ;;
        -o|--flag2)
          FLAG2="$2"
          shift 2
          ;;
        --option1)
          OPTION1=true
          shift
          ;;
        --dry-run)
          DRY_RUN=true
          shift
          ;;
        --verbose)
          VERBOSE=true
          shift
          ;;
        -h|--help)
          show_usage
          ;;
        --)
          shift
          break
          ;;
      esac
    done
    
    # Check for additional arguments (command and argument)
    if [[ $# -gt 0 ]]; then
      if [[ "$1" =~ ^(command1|command2|command3)$ ]]; then
        COMMAND="$1"
        shift
      fi
      
      if [[ $# -gt 0 ]]; then
        ARGUMENT="$1"
        shift
      fi
    fi
  fi
else
  # Fall back to traditional option parsing
  while getopts ":f:o:h" opt; do
    case ${opt} in
      f)
        FLAG1=$OPTARG
        ;;
      o)
        FLAG2=$OPTARG
        ;;
      h)
        show_usage
        ;;
      \?)
        error "Invalid option: $OPTARG"
        show_usage
        ;;
      :)
        error "Invalid option: $OPTARG requires an argument"
        show_usage
        ;;
    esac
  done
  shift $((OPTIND - 1))
  
  # Check for command and argument
  if [[ $# -gt 0 ]]; then
    if [[ "$1" =~ ^(command1|command2|command3)$ ]]; then
      COMMAND="$1"
      shift
    fi
    
    if [[ $# -gt 0 ]]; then
      ARGUMENT="$1"
      shift
    fi
  fi
  
  # Handle legacy flags that would otherwise be dropped
  for arg in "$@"; do
    case "$arg" in
      --option1)
        OPTION1=true
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      --verbose)
        VERBOSE=true
        ;;
    esac
  done
fi

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

# Validate required parameters
if [[ -z "${FLAG1}" ]]; then
  error "Flag1 not specified. Use -f or --flag1 option."
  show_usage
fi

# Implementation of command1
function cmd_command1() {
  info "Executing command1 with flag1='${FLAG1}'"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute command1 here"
  else
    # Actual command implementation
    success "Command1 executed successfully"
  fi
}

# Implementation of command2
function cmd_command2() {
  info "Executing command2 with flag1='${FLAG1}'"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute command2 here"
  else
    # Actual command implementation
    success "Command2 executed successfully"
  fi
}

# Implementation of command3
function cmd_command3() {
  info "Executing command3 with flag1='${FLAG1}'"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute command3 here"
  else
    # Actual command implementation
    success "Command3 executed successfully"
  fi
}

# Execute the requested command
case "${COMMAND}" in
  command1)
    cmd_command1
    ;;
  command2)
    cmd_command2
    ;;
  command3)
    cmd_command3
    ;;
  *)
    error "Unknown command: ${COMMAND}"
    show_usage
    ;;
esac
```

## 7. Implementation Process

Follow this process for standardizing each repository:

1. **Assessment**: Review current structure and identify changes needed
2. **Planning**: Create a detailed migration plan
3. **Testing**: Test changes in a branch before merging
4. **Gradual Migration**: Implement changes in phases to minimize disruption
5. **Documentation**: Update documentation to reflect the new structure

## 8. Documentation Requirements

Each repository's CI directory should include a README.md that documents:

1. **Directory Structure**: Description of the CI directory structure
2. **Tasks**: Documentation of task purposes and usage
3. **Pipelines**: Description of each pipeline's purpose and behavior
4. **Usage Examples**: Common usage examples for the fly.sh script

## 9. Compliance Checklist

Use this checklist to verify compliance with the standardization:

- [ ] Folder structure follows the standard layout
- [ ] `fly.sh` implements the standard interface with all commands
- [ ] Task scripts are organized by function in task-specific directories
- [ ] Each task has both task.yml and task.sh files
- [ ] All scripts follow the documented standards
- [ ] Pipeline YAML files follow naming conventions
- [ ] Documentation is complete and up-to-date
- [ ] Test framework is implemented for critical scripts
- [ ] All script commands are tested with automated tests
- [ ] Test coverage includes error conditions
- [ ] Backward compatibility is maintained (during transition)
- [ ] All tests pass when run with the test framework

## Appendix: Implementation Across Repositories

| Repository | Current Status | Notes |
|------------|----------------|-------|
| ns-mgmt    | Migrated       | Fully compliant with CI/CD standardization |
| tkgi-pipeline-standards | Reference Templates | Contains template implementations of standardized CI structure |
| cluster-mgmt | To be migrated | Migration planned for future sprint |
| cert-mgmt  | To be migrated | Migration planned for future sprint |
| trident    | To be migrated | Migration planned for future sprint |

### Reference Implementation Templates

The tkgi-pipeline-standards repository contains reference implementations for several CI/CD patterns:

1. **Kustomize Template**: A complete reference for kustomize-based projects
   - Located at `/reference/templates/kustomize/`
   - Features a hybrid approach with two fly.sh scripts:
     - Simple version in `ci/fly.sh` (similar to ns-mgmt)
     - Advanced version in `ci/scripts/fly.sh` with modular architecture
   - Includes a sophisticated modular architecture in `ci/scripts/lib/` with dedicated files:
     - `commands.sh`: Command implementations
     - `help.sh`: Help text and documentation
     - `parsing.sh`: Argument parsing functions
     - `pipelines.sh`: Pipeline management functions
     - `utils.sh`: Utility and helper functions
   - Comprehensive test framework in `ci/scripts/tests/` for CI scripts
   - Makefile in `ci/scripts/` for build and test automation

2. **Helm Template**: A reference for helm-based projects
   - Located at `/reference/templates/helm/`

The ns-mgmt repository serves as a real-world implementation of the standardized CI/CD structure. Key aspects of this implementation include:

1. **Task Organization**: Tasks are categorized into common, k8s, tkgi, and testing directories
2. **Task Definition**: Each task has both a task.yml (definition) and task.sh (implementation) file
3. **Pipeline Structure**: Pipeline files reference task.yml files instead of defining tasks inline
4. **Documentation**: The CI directory includes comprehensive documentation about its structure and usage
5. **Standardized fly.sh**: Implements the full command interface as specified in this guide

### Using the Reference Templates

To use these reference templates for a new project:

1. **Create a new repository**: Set up the basic repository structure
2. **Copy template structure**: Copy the appropriate template from `/reference/templates/` to your repository
3. **Update configuration**:
   - Rename files and update references to match your project
   - Update pipeline files to reference your repositories
   - Configure foundation-specific parameters
4. **Test the implementation**: Run the included tests to validate your setup
   - For kustomize template, use `cd ci/scripts/tests && ./run_tests.sh`
   - These tests validate command handling, option parsing, environment determination, and flag behavior
5. **Deploy pipelines**: Use the provided `fly.sh` script to deploy your pipelines

The reference templates are designed to be used with minimal modifications while providing a
fully-functional CI/CD implementation that follows these standards.
