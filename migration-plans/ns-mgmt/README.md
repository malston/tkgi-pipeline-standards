# Migration Plan for ns-mgmt Repository

Based on a thorough analysis of the current pipeline structure, task scripts, and the interactions, this plan provides a detailed approach to standardize the CI folder structure while ensuring minimal disruption to existing workflows.

## Current Structure

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

## Target Structure

```sh
ci/
├── fly.sh
├── pipelines/
│   ├── ns-mgmt.yml
│   ├── release.yml
│   └── set-pipeline.yml
└── tasks/
    ├── common/
    │   ├── create-release-info/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── kubectl-apply/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── kustomize/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── make-git-commit/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   └── prepare-kustomize/
    │       ├── task.yml
    │       └── task.sh
    ├── k8s/
    │   ├── create-legacy-netpol/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── create-legacy-rbac/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── create-limits-quotas/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── create-namespaces/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   ├── delete-namespaces/
    │   │   ├── task.yml
    │   │   └── task.sh
    │   └── validate-namespaces/
    │       ├── task.yml
    │       └── task.sh
    ├── tkgi/
    │   └── tkgi-login/
    │       ├── task.yml
    │       └── task.sh
    └── testing/
        └── run-unit-tests/
            ├── task.yml
            └── task.sh
```

## Implementation Status

This migration plan has been **implemented** in the `feature/standardize-ci-structure` branch of the `ns-mgmt` repository. The implementation followed the approach outlined below.

### Key Implementation Details

1. **Directory Structure**: Created the categorized directory structure as outlined in the target structure section.

2. **Task Migration**: Moved all task scripts from the flat structure to their respective category directories, creating both task.sh and task.yml files for each.

3. **Pipeline Updates**: Updated all pipeline YAML files to reference the new task.yml files instead of using inline task definitions.

4. **Path References**: Updated script path references in all task scripts to account for the deeper directory structure, changing `$__DIR/../../scripts/` to `$__DIR/../../../../scripts/`.

5. **fly.sh Script**: Created a new fly.sh script in the ci directory with updated functionality to support the new structure.

6. **Documentation**: Updated the ci/README.md to explain the new structure and provide usage instructions.

## Implementation Approach

The implementation took a direct approach with the following major steps:

### 1. Create Feature Branch

```bash
git checkout develop
git pull
git checkout -b feature/standardize-ci-structure
```

### 2. Create Task Directories

Created the directory structure for all task categories (common, k8s, tkgi, testing) with subdirectories for each specific task.

### 3. Migrate Task Scripts

Copied each task script to its new location as task.sh and updated all path references to account for the deeper directory structure.

### 4. Create Task YAML Files

Created task.yml definitions for each task, defining the appropriate inputs, outputs, and parameters.

### 5. Update Pipeline Files

Modified all pipeline YAML files to reference the new task.yml files instead of using inline task definitions.

### 6. Documentation

Created comprehensive documentation in the ci/README.md file explaining the new structure and how to use it.

## Pipeline Structure Updates

The pipelines were updated to use the new task files with the following pattern:

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

This approach simplifies pipeline definitions and ensures consistency across all tasks.

## Benefits of the Migration

1. **Improved Organization**: Tasks are now logically organized by category, making it easier to find and understand related tasks.

2. **Standardized Structure**: Each task follows the same structure with separate task.yml and task.sh files.

3. **Simplified Pipelines**: Pipeline definitions are cleaner and more maintainable as they reference external task files instead of defining tasks inline.

4. **Better Documentation**: The CI directory now includes comprehensive documentation about its structure and usage.

5. **Consistency**: The ns-mgmt repository now follows the standardized CI structure defined in the tkgi-pipeline-standards repository.

## Testing and Verification

The implementation has been tested to ensure:

1. All scripts can locate their dependencies correctly with the updated paths.
2. All pipeline files correctly reference the new task.yml files.
3. The new fly.sh script works correctly for setting pipelines.

## Next Steps

To complete the integration of this work:

1. **Review and Test**: Review the feature branch implementation and test with a real pipeline run.

2. **Merge the Branch**: After successful testing, merge the feature branch into the develop branch.

3. **Update User Documentation**: Inform users of the new structure and provide guidance on how to interact with it.

4. **Apply to Other Repositories**: Use this implementation as a reference for applying similar changes to other repositories.

## Reference Implementation

This implementation serves as a reference for standardizing CI structures in other repositories. It demonstrates how to:

1. Organize tasks by category for better maintainability.
2. Create standardized task.yml and task.sh files for each task.
3. Update pipeline references to use the new standardized structure.
4. Provide clear documentation for developers working with the CI system.

## Appendix: Mapping of Original to New Files

| Original Location | New Location |
|-------------------|--------------|
| ci/tasks/kapply.sh | ci/tasks/common/kubectl-apply/task.sh |
| ci/tasks/kustomize.sh | ci/tasks/common/kustomize/task.sh |
| ci/tasks/make-git-commit.sh | ci/tasks/common/make-git-commit/task.sh |
| ci/tasks/prepare-kustomize.sh | ci/tasks/common/prepare-kustomize/task.sh |
| ci/tasks/create-release-info.sh | ci/tasks/common/create-release-info/task.sh |
| ci/tasks/create-legacy-netpol.sh | ci/tasks/k8s/create-legacy-netpol/task.sh |
| ci/tasks/create-legacy-rbac.sh | ci/tasks/k8s/create-legacy-rbac/task.sh |
| ci/tasks/create-limits-quotas.sh | ci/tasks/k8s/create-limits-quotas/task.sh |
| ci/tasks/create-namespaces.sh | ci/tasks/k8s/create-namespaces/task.sh |
| ci/tasks/delete-namespaces.sh | ci/tasks/k8s/delete-namespaces/task.sh |
| ci/tasks/validate-namespaces.sh | ci/tasks/k8s/validate-namespaces/task.sh |
| ci/tasks/tkgi-login.sh | ci/tasks/tkgi/tkgi-login/task.sh |
| ci/tasks/test.sh | ci/tasks/testing/run-unit-tests/task.sh |