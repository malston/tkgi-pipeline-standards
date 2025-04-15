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

```sh
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
│   │   ├── lib/              # Modular components for the fly.sh script
│   │   ├── fly.sh            # Standardized pipeline management script
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
|── scripts/                  # Repository-level scripts
│   ├── apply.sh
│   ├── build.sh
│   └── ...
└── tests/                     # Repository-level tests
    ├── test_apply.sh
    ├── test_build.sh
    ├── ...
    └── run_tests.sh
```

## 2. `fly.sh` Command Interface

All repositories should use a standardized `fly.sh` script with a consistent interface:

```sh
./ci/scripts/fly.sh [options] [command] [pipeline_name]
```

### Standard Commands

- `set`: Set the [main](./reference/templates/kustomize/ci/pipelines/main.yml) pipeline (default)
- `unpause`: Set and unpause pipeline
- `destroy`: Destroy specified pipeline
- `validate`: Validate pipeline YAML without setting
- `release`: Create a [release](./reference/templates/kustomize/ci/pipelines/release.yml) pipeline
- `set-pipeline`: Create the [set-pipeline](./reference/templates/kustomize/ci/pipelines/set-pipeline.yml) pipeline that `set` the [main](./reference/templates/kustomize/ci/pipelines/main.yml) with a given `release` tag.

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

```sh
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
--timer DURATION           Set timer trigger duration

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
2. **Test Framework**: Use the common test framework provided in `test-framework.sh`
3. **Test Runner**: Include a `run_tests.sh` script to execute all tests
4. **Test Coverage**: Each script should have corresponding test cases
5. **Mock Functions**: Use mock functions to simulate dependencies
6. **Assertions**: Use assertions to validate script behavior

Example test framework usage:

```bash
# Source test framework
source "$(dirname "${BASH_SOURCE[0]}")/test-framework.sh"

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
# Description: Example script that follows our standards
#
# Usage: ./example.sh [options] [command] [arguments...]
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
#   -h, --help           Show this help message
#
# Examples:
#   ./example.sh command1 -f VALUE --option1
#   ./example.sh command2 -f VALUE
#   ./example.sh command3 -o VALUE1 -f VALUE2 --option1
#   ./example.sh -f VALUE1 --option1 command1 -o VALUE2

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
OPTION1=false

# Function to display usage
function show_usage() {
    cat <<USAGE
Script: example.sh
Description: Example script that follows our standards

Usage: $0 [options] [command] [argument]

Commands:
  command1    First command description
  command2    Second command description
  command3    Third command description

Options:
  -f, --flag1 VALUE    First flag description (required)
  -o, --flag2 VALUE    Second flag description
  --option1            Boolean option description
  -h, --help           Show this help message

Examples:
  $0 command1 -f VALUE --option1
  $0 command2 -f VALUE
  $0 command3 -o VALUE1 -f VALUE2 --option1
  $0 -f VALUE1 --option1 command1 -o VALUE2
USAGE
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

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Global options
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_usage
        exit 0
        ;;
    -f | --flag1)
        if [[ -z "$2" || "$2" == -* ]]; then
            error "Option $1 requires an argument"
            show_usage 1
        fi
        FLAG1="$2"
        shift 2
        ;;
    -o | --flag2)
        FLAG2="$2"
        shift 2
        ;;
    --option1)
        OPTION1=true
        shift
        ;;
    --)
        shift
        non_flags+=("$@")
        break
        ;;
    # Commands and non-flag arguments
    *)
        if [[ "$1" =~ ^(command1|command2|command3)$ ]]; then
            COMMAND="$1"
        elif [[ ! "$1" =~ ^- ]]; then
            # Assume this is a pipeline name
            non_flags+=("$1")
        else
            error "Unknown option: $1"
            show_usage 1
        fi
        shift
        ;;
    esac
done

# Implementation of command1
function cmd_command1() {
    local flag1=$1
    local flag2=$2
    local option="${3:-false}"

    info "Executing command1 with flag1='${flag1}' and flag2='${flag2}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "Would execute option1 here"
    fi
    # Actual command implementation
    success "Command1 executed successfully"
}

# Implementation of command2
function cmd_command2() {
    local flag1=$1
    local flag2=$2
    local option="${3:-false}"

    info "Executing command2 with flag1='${flag1}' and flag2='${flag2}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "Would execute option1 here"
    fi
    # Actual command implementation
    success "Command2 executed successfully"
}

# Implementation of command3
function cmd_command3() {
    local flag1=$1
    local flag2=$2
    local option="${3:-false}"

    info "Executing command3 with flag1='${flag1}' and flag2='${flag2}' and option='${option}'"

    if [[ "${option}" == "true" ]]; then
        info "Would execute option1 here"
    fi
    # Actual command implementation
    success "Command3 executed successfully"
}

# Execute the requested command
case "${COMMAND}" in
command1)
    cmd_command1 "${FLAG1}" "${FLAG2}" "${OPTION1}"
    ;;
command2)
    cmd_command2 "${FLAG1}" "${FLAG2}" "${OPTION1}"
    ;;
command3)
    cmd_command3 "${FLAG1}" "${FLAG2}" "${OPTION1}"
    ;;
*)
    error "Unknown command: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
```

For a more advanced example see [here](./reference/scripts/advanced-example.sh).

## 7. Implementation Process

Follow this process for standardizing each repository:

1. **Assessment**: Review current structure and identify changes needed
2. **Planning**: Create a detailed [migration plan](reference/migration-plans/README.md)
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

This repository contains reference implementations for several CI/CD patterns, including:

- **Kustomize Template**: For kustomize-based Kubernetes projects
- **Helm Template**: For Helm chart repositories
- **CLI Tool Template**: For command-line tool management

For detailed information about available templates and usage instructions, see the [Reference Templates documentation](./reference/TEMPLATES.md).

For instructions on using the template generator tool, see the [template generator quick start guide](./template-generator/QUICK-START.md).
