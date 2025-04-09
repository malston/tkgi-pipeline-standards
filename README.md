# CI/CD Standardization Guide for TKGi Repositories

This document defines the standards for CI/CD pipeline organization across all TKGi pipeline repositories.

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
   - Main pipeline: `<app>-main.yml`
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
# Script Name: task.sh
# Description: Brief description of what the script does
#
# Usage: ./task.sh [options] <required_arg>
#
# Options:
#   -h, --help          Show this help message
#   -v, --verbose       Increase verbosity

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source common functions if needed
# source "${__DIR}/../../../../scripts/helpers.sh"

# Default values
VERBOSE=false

# Function to display usage
function show_usage() {
    grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \{0,1\}//'
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            # Handle positional arguments
            if [[ -z "$REQUIRED_ARG" ]]; then
                REQUIRED_ARG="$1"
            else
                echo "Error: Unexpected argument: $1"
                show_usage
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REQUIRED_ARG" ]]; then
    echo "Error: Required argument missing"
    show_usage
fi

# Main script logic
function main() {
    # Script implementation
    echo "Script executed successfully"
}

main
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
   - Features a fully tested `fly.sh` script with all commands implemented
   - Includes a test framework for CI scripts

2. **Helm Template**: A reference for helm-based projects
   - Located at `/reference/templates/helm/`

The ns-mgmt repository serves as a real-world implementation of the standardized CI/CD structure. Key aspects of this implementation include:

1. **Task Organization**: Tasks are categorized into common, k8s, tkgi, and testing directories
2. **Task Definition**: Each task has both a task.yml (definition) and task.sh (implementation) file
3. **Pipeline Structure**: Pipeline files reference task.yml files instead of defining tasks inline
4. **Documentation**: The CI directory includes comprehensive documentation about its structure and usage
5. **Standardized fly.sh**: Implements the full command interface as specified in this guide