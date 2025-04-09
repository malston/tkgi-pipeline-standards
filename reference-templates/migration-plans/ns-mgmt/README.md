# NS-MGMT: CI Structure Migration Guide

This document serves as a comprehensive guide for migrating the ns-mgmt repository to the standardized CI/CD structure. It provides a detailed step-by-step approach that can be used as a reference for similar migrations in other repositories.

## Repository Overview

The ns-mgmt repository manages Kubernetes namespace creation, configuration, and resource quotas across TKGi clusters. It uses Concourse pipelines to:

- Create and configure namespaces
- Apply resource limits and quotas
- Create network policies
- Manage RBAC resources
- Validate namespace configurations

## Initial Structure Assessment

### Original Structure

```sh
ci/
├── fly.sh
├── pipelines/
│   ├── ns-mgmt.yml
│   ├── release.yml
│   └── set-pipeline.yml
└── tasks/
    ├── create-legacy-netpol.sh
    ├── create-legacy-rbac.sh
    ├── create-limits-quotas.sh
    ├── create-namespaces.sh
    ├── create-release-info.sh
    ├── delete-namespaces.sh
    ├── kapply.sh
    ├── kustomize.sh
    ├── make-git-commit.sh
    ├── prepare-kustomize.sh
    ├── test.sh
    ├── tkgi-login.sh
    └── validate-namespaces.sh
```

### Analysis of Original Structure

The original structure had several limitations:

1. **Flat Organization**: All task scripts were in a single directory with no logical categorization
2. **No Task YAML Files**: Tasks were defined inline in pipeline YAML files rather than in separate task.yml files
3. **Inconsistent Naming**: Task scripts used inconsistent naming conventions
4. **Limited Documentation**: The CI directory lacked comprehensive documentation

## Migration Approach

The migration followed a comprehensive and systematic approach:

### 1. Feature Branch Creation

Created a dedicated feature branch to safely implement and test changes:

```bash
git checkout develop
git pull
git checkout -b feature/standardize-ci-structure
```

### 2. Directory Structure Creation

Created a categorized directory structure following the standardized pattern:

```bash
# Create task directories for common tasks
mkdir -p ci/tasks/common/kubectl-apply
mkdir -p ci/tasks/common/kustomize
mkdir -p ci/tasks/common/make-git-commit
mkdir -p ci/tasks/common/prepare-kustomize
mkdir -p ci/tasks/common/create-release-info

# Create task directories for k8s tasks
mkdir -p ci/tasks/k8s/create-legacy-netpol
mkdir -p ci/tasks/k8s/create-legacy-rbac
mkdir -p ci/tasks/k8s/create-limits-quotas
mkdir -p ci/tasks/k8s/create-namespaces
mkdir -p ci/tasks/k8s/delete-namespaces
mkdir -p ci/tasks/k8s/validate-namespaces

# Create task directories for tkgi tasks
mkdir -p ci/tasks/tkgi/tkgi-login

# Create task directories for testing tasks
mkdir -p ci/tasks/testing/run-unit-tests
```

### 3. Task Script Migration

Migrated task scripts to their appropriate categorized directories and updated path references:

```bash
# Example for common tasks
cp ci/tasks/kapply.sh ci/tasks/common/kubectl-apply/task.sh
cp ci/tasks/kustomize.sh ci/tasks/common/kustomize/task.sh
cp ci/tasks/make-git-commit.sh ci/tasks/common/make-git-commit/task.sh
cp ci/tasks/prepare-kustomize.sh ci/tasks/common/prepare-kustomize/task.sh
cp ci/tasks/create-release-info.sh ci/tasks/common/create-release-info/task.sh

# Example for k8s tasks
cp ci/tasks/create-namespaces.sh ci/tasks/k8s/create-namespaces/task.sh
cp ci/tasks/validate-namespaces.sh ci/tasks/k8s/validate-namespaces/task.sh
# ...additional scripts

# Example for tkgi tasks
cp ci/tasks/tkgi-login.sh ci/tasks/tkgi/tkgi-login/task.sh

# Example for testing tasks
cp ci/tasks/test.sh ci/tasks/testing/run-unit-tests/task.sh
```

### 4. Path Reference Updates

Updated script path references to account for the deeper directory structure:

```bash
# Find and replace path references in task scripts
sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' ci/tasks/common/*/task.sh
sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' ci/tasks/k8s/*/task.sh
sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' ci/tasks/tkgi/*/task.sh
sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' ci/tasks/testing/*/task.sh

# Update specific path in test.sh
sed -i 's|__DIR/../../test/tests.sh|__DIR/../../../../test/tests.sh|g' ci/tasks/testing/run-unit-tests/task.sh
```

### 5. Task YAML File Creation

Created YAML definition files for each task with appropriate inputs, outputs, and parameters:

```yaml
# Example for kubectl-apply task
platform: linux
inputs:
  - name: ns-mgmt
  - name: pks-config
  - name: config
  - name: manifests
outputs:
  - name: manifests
run:
  path: ns-mgmt/ci/tasks/common/kubectl-apply/task.sh
params:
  FOUNDATION: ((foundation))
  PKS_PASSWORD: ((pks_api_admin_pw))
  KINDS: ((kinds))
  NAMESPACE_LIMIT: 0
  VERBOSE: ((verbose))

# Similar YAML files were created for all other tasks
```

### 6. Pipeline File Updates

Updated pipeline YAML files to reference the new task.yml files instead of defining tasks inline:

```yaml
# Old style:
- task: kustomize
  config:
    platform: linux
    inputs:
      - name: config
      - name: ns-mgmt
    outputs:
      - name: manifests
    run:
      path: ns-mgmt/ci/tasks/kustomize.sh
    params:
      FOUNDATION: ((foundation))
      FOUNDATION_PATH: ((foundation_path))

# New style:
- task: kustomize
  file: ns-mgmt/ci/tasks/common/kustomize/task.yml
  params:
    FOUNDATION: ((foundation))
    FOUNDATION_PATH: ((foundation_path))
```

### 7. Documentation Creation

Created comprehensive documentation in ci/README.md to explain the new structure:

```markdown
# CI Directory Structure

This directory contains all CI/CD pipeline configurations and scripts for the ns-mgmt repository.

## Structure

- `pipelines/`: Contains all pipeline definition YAML files
  - `ns-mgmt.yml`: Main namespace management pipeline
  - `release.yml`: Release pipeline for creating GitHub releases
  - `set-pipeline.yml`: Pipeline for setting other pipelines

- `fly.sh`: Standardized script for setting and managing pipelines

- `tasks/`: Tasks organized by functional category
  - `common/`: Common/shared tasks
    - `kubectl-apply/`: Kubernetes apply resource task
    - `kustomize/`: Kustomize resource generation task
    - `make-git-commit/`: Git commit creation task
    - `prepare-kustomize/`: Kustomize preparation task
    - `create-release-info/`: Release information generation task
  - `k8s/`: Kubernetes-specific tasks
    - `create-legacy-netpol/`: Legacy network policy creation task
    - `create-legacy-rbac/`: Legacy RBAC resource creation task
    - `create-limits-quotas/`: Resource limits and quotas creation task
    - `create-namespaces/`: Namespace creation task
    - `delete-namespaces/`: Namespace deletion task
    - `validate-namespaces/`: Namespace validation task
  - `tkgi/`: TKGi-specific tasks
    - `tkgi-login/`: TKGi login task
  - `testing/`: Testing tasks
    - `run-unit-tests/`: Test task

Each task directory contains both a `task.yml` file (the task definition) and a `task.sh` file (the task implementation).
```

### 8. fly.sh Script Update

Updated the fly.sh script to support the new structure:

```bash
#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="${SCRIPT_DIR}/pipelines"

source "${SCRIPT_DIR}/../scripts/helpers.sh"

# Script implementation with parameters for foundation, pipeline, etc.
# ...
```

## Migration Challenges and Solutions

### 1. Path Reference Management

**Challenge**: Task scripts referenced helper functions and other scripts using relative paths that needed to be updated for the new directory structure.

**Solution**: 
- Systematically updated all path references with the correct deeper path
- Tested each script to ensure it could still find its dependencies
- Used a consistent approach for path construction based on the `__DIR` variable

### 2. Pipeline Update Strategy

**Challenge**: Updating pipeline YAML files to reference task.yml files instead of inline definitions.

**Solution**:
- Created temporary versions of pipeline files for testing
- Verified each task reference was correctly pointing to the new structure
- Ensured all parameters were properly passed from pipeline to task
- Replaced original files only after validation

### 3. Maintaining Consistency

**Challenge**: Ensuring all tasks followed the same structural pattern and naming conventions.

**Solution**:
- Used a systematic approach for creating task directories and files
- Applied a consistent naming convention across all task files
- Organized tasks into logical categories based on their function
- Created documentation to explain the structure and conventions

## Testing Strategy

The migration was thoroughly tested to ensure all functionality remained intact:

1. **Path Verification**: Checked all scripts could locate their dependencies with the new paths
2. **Task YAML Validation**: Used `fly validate-pipeline` to validate task YAML files
3. **Pipeline Validation**: Verified pipeline YAML files correctly referenced the new task locations
4. **Script Execution Testing**: Verified task scripts could be executed directly
5. **End-to-End Testing**: Tested the entire pipeline execution to ensure all steps worked together

## Benefits Achieved

The migration delivered several key benefits:

1. **Improved Organization**: Tasks are now logically organized by category, making it easier to find and maintain related tasks.

2. **Standardized Structure**: Each task follows the same structure with separate task.yml and task.sh files, improving consistency.

3. **Simplified Pipelines**: Pipeline definitions are cleaner and more maintainable as they reference external task files.

4. **Better Documentation**: The CI directory now includes comprehensive documentation explaining its structure and usage.

5. **Consistency with Standards**: The ns-mgmt repository now follows the standardized CI structure defined in the tkgi-pipeline-standards repository.

## Lessons Learned

Several valuable lessons emerged during this migration:

1. **Incremental Approach**: An incremental approach with feature branches provided a safe way to implement and test changes.

2. **Documentation Importance**: Creating comprehensive documentation helped clarify the new structure and ease adoption.

3. **Path Management**: Careful path reference management was critical to ensuring scripts continued to function in their new locations.

4. **Categorization Benefits**: Logically categorizing tasks improved organization and maintainability.

5. **Standardization Value**: Following a standardized approach improved consistency and made the repository easier to understand.

## Recommendations for Future Migrations

For repositories undertaking similar migrations, we recommend:

1. **Thorough Analysis**: Start with a comprehensive analysis of the current structure and task dependencies.

2. **Detailed Plan**: Create a detailed migration plan with clear steps and fallback options.

3. **Feature Branch**: Implement changes in a feature branch to enable safe testing.

4. **Systematic Approach**: Follow a systematic approach for creating directories, migrating scripts, and updating references.

5. **Early Testing**: Test each component early and often to catch issues before they become more complex.

6. **Clear Documentation**: Create clear documentation explaining the new structure and usage patterns.

7. **Gradual Integration**: Consider a phased approach for larger repositories to minimize disruption.

## Reference Implementation 

The ns-mgmt repository's `feature/standardize-ci-structure` branch serves as a reference implementation for standardizing CI structures. Key elements include:

1. **Categorized Tasks**: Tasks organized by function (common, k8s, tkgi, testing)
2. **Standardized Files**: Each task with task.yml and task.sh files
3. **Updated Pipelines**: Pipeline YAMLs referencing task files instead of inline definitions
4. **Comprehensive Documentation**: Clear documentation explaining the structure and usage

This reference implementation demonstrates how to successfully migrate to the standardized CI structure while maintaining full functionality.

## Conclusion

The migration of the ns-mgmt repository to the standardized CI structure was successfully completed, providing a template for future migrations of other repositories. The new structure improves organization, maintainability, and consistency with the defined standards in the tkgi-pipeline-standards repository.