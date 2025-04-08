# CI/CD Standardization Guide for TKGi Repositories

This document defines the standards for CI/CD pipeline organization across all TKGi pipeline repositories.

## 1. Folder Structure

All repositories should follow this standard structure:

```sh
repository-root/
├── ci/
│   ├── pipelines/            # Pipeline definition files
│   │   ├── <app>-mgmt.yml    # Main pipeline
│   │   ├── release.yml       # Release pipeline
│   │   └── set-pipeline.yml  # Pipeline setup pipeline
│   ├── scripts/              # Pipeline control scripts
│   │   ├── fly.sh            # Standardized pipeline management script
│   │   └── helpers.sh        # Helper functions (if needed)
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

### Special Commands

- `-r, --release [MESSAGE]`: Set the release pipeline
- `-s, --set [NAME]`: Set the set-pipeline pipeline

### Standard Options

```
-f, --foundation NAME     Foundation name (required)
-t, --target TARGET       Concourse target (default: <foundation>)
-e, --environment ENV     Environment type (lab|nonprod|prod)
-b, --branch BRANCH       Git branch for pipeline repository 
-c, --config-branch BRANCH Git branch for config repository
-n, --config-repo NAME    Config repository name
-d, --params-branch BRANCH Params git branch (default: master)
-p, --pipeline NAME       Custom pipeline name prefix
-o, --github-org ORG      GitHub organization 
-v, --version VERSION     Pipeline version
--dry-run                 Simulate without making changes
--verbose                 Increase output verbosity
--timer DURATION          Set timer trigger duration
-h, --help                Show help message
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
   - Main pipeline: `<app>-mgmt.yml`
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
- [ ] `fly.sh` implements the standard interface
- [ ] Task scripts are organized by function in task-specific directories
- [ ] Each task has both task.yml and task.sh files
- [ ] All scripts follow the documented standards
- [ ] Pipeline YAML files follow naming conventions
- [ ] Documentation is complete and up-to-date
- [ ] Backward compatibility is maintained (during transition)
- [ ] All tests pass

## Appendix: Implementation Across Repositories

| Repository | Current Status | Migration Plan | Target Date |
|------------|----------------|----------------|-------------|
| ns-mgmt    | Legacy         | See detailed plan | TBD |
| cluster-mgmt | Legacy      | To be developed | TBD |
| cert-mgmt  | Legacy         | To be developed | TBD |
| tkgi-release | Legacy       | To be developed | TBD |