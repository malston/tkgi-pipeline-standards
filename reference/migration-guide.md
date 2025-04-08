# CI/CD Standardization Migration Guide

This guide provides step-by-step instructions for migrating an existing repository to the standardized CI/CD structure.

## Before You Begin

1. **Identify Component Type**
   - Determine whether your component uses Kustomize, Helm, or a CLI tool
   - Select the appropriate template based on your component type

2. **Backup Current Implementation**
   - Create a backup branch before beginning migration
   - Document any custom tasks or specialized functionality

3. **Review Dependencies**
   - Identify dependencies on other repositories
   - Note any specialized requirements for your component

## Migration Process

### Phase 1: Repository Structure Setup

1. **Create Feature Branch**

```bash
git checkout develop
git pull
git checkout -b feature/standardize-ci-structure
```

2. **Create Standard Directory Structure**

```bash
# Create standard directories
mkdir -p ci/scripts
mkdir -p ci/pipelines

# For Kustomize components
mkdir -p ci/tasks/common/{kapply,kustomize,make-git-commit,create-release-info}
mkdir -p ci/tasks/k8s/{create-namespace,validate-deployment}
mkdir -p ci/tasks/kustomize/{build-manifests,apply-manifests}
mkdir -p ci/tasks/tkgi/tkgi-login
mkdir -p ci/tasks/testing/validate-resources

# For Helm components
mkdir -p ci/tasks/common/{make-git-commit,create-release-info}
mkdir -p ci/tasks/k8s/{create-namespace,validate-deployment}
mkdir -p ci/tasks/helm/{helm-deploy,helm-test,helm-delete}
mkdir -p ci/tasks/tkgi/tkgi-login
mkdir -p ci/tasks/testing/validate-helm-release

# For CLI tool components
mkdir -p ci/tasks/common/{make-git-commit,create-release-info}
mkdir -p ci/tasks/k8s/{create-namespace,validate-deployment}
mkdir -p ci/tasks/cli-tool/{download-tool,deploy-component,validate-component}
mkdir -p ci/tasks/tkgi/tkgi-login
mkdir -p ci/tasks/testing/validate-resources
```

3. **Move Existing Pipeline Files**

If you already have pipeline files, move them to the standard location:

```bash
# Move existing pipeline files if they are in a different location
# Example:
mv pipeline.yml ci/pipelines/component-mgmt.yml
```

### Phase 2: Task Migration

1. **Identify Existing Tasks**

Catalog all task scripts currently used in your pipelines:

```bash
# Example: List all task scripts referenced in pipeline files
grep -r "path:" ci/pipelines/ | grep "\.sh" | awk -F: '{print $2}' | sort -u
```

2. **Categorize Tasks**

Categorize each task based on its function:
- Common tasks (git operations, release info)
- K8s tasks (namespace operations)
- Deployment tasks (kustomize, helm, cli-tool)
- TKGi tasks (login)
- Testing tasks (validation)

3. **Migrate Tasks to Standard Structure**

For each task:

a. Create the task.yml file:

```yaml
# Example for a Kustomize task
platform: linux
inputs:
  - name: component-repo
  - name: config-repo
outputs:
  - name: manifests
run:
  path: component-repo/ci/tasks/kustomize/build-manifests/task.sh
params:
  FOUNDATION: ((foundation))
  ENVIRONMENT: ((environment))
```

b. Create the task.sh file:

```bash
#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../../scripts/helpers.sh"

# Task implementation
```

c. If retaining existing scripts, create wrappers in standard locations:

```bash
# Create wrapper for the original task
cat > ci/tasks/original-location/original-task.sh << 'EOF'
#!/usr/bin/env bash
# This is a wrapper script that calls the standardized location
# Migrated as part of CI folder structure standardization
exec "$(dirname "${BASH_SOURCE[0]}")/../kustomize/build-manifests/task.sh" "$@"
EOF
chmod +x ci/tasks/original-location/original-task.sh
```

### Phase 3: Pipeline Updates

1. **Update Pipeline References**

For each pipeline file:

a. Update task references to use the new standard paths:

```yaml
# From
task: deploy-component
config:
  platform: linux
  inputs:
    - name: component-repo
  run:
    path: component-repo/scripts/deploy.sh

# To
task: deploy-component
file: component-repo/ci/tasks/helm/helm-deploy/task.yml
```

b. Ensure resource names and job patterns match the standard conventions

2. **Create fly.sh Script**

Create the standardized fly.sh script in the ci/scripts directory:

```bash
# Copy the standardized fly.sh template
cp /path/to/templates/fly.sh ci/scripts/
chmod +x ci/scripts/fly.sh

# Create a wrapper in the original location if needed
if [[ -f fly.sh ]]; then
  cat > fly.sh << 'EOF'
#!/usr/bin/env bash
# This is a wrapper script that calls the standardized location
exec "$(dirname "${BASH_SOURCE[0]}")/ci/scripts/fly.sh" "$@"
EOF
  chmod +x fly.sh
fi
```

### Phase 4: Documentation

1. **Create CI README**

Create a README.md file in the ci directory:

```markdown
# CI Directory Structure

This directory contains all CI/CD pipeline configurations and scripts for the [Component Name].

## Structure

- `pipelines/`: Contains all pipeline definition YAML files
- `scripts/`: Control scripts for the pipelines
- `tasks/`: Tasks organized by function

## Using fly.sh

The `fly.sh` script provides a consistent interface for setting and managing pipelines.

For details on all options, run:

\\```bash
./ci/scripts/fly.sh --help
\\```

## Pipelines

- `component-mgmt.yml`: Main component management pipeline
- `release.yml`: Release pipeline
- `set-pipeline.yml`: Pipeline setup pipeline
```

2. **Update Main README**

Update the main README.md to reference the CI documentation:

```markdown
## CI/CD Pipelines

This repository uses standardized CI/CD pipelines. For details, see the [CI documentation](./ci/README.md).

### Setting up pipelines

\```bash
# Set the main pipeline
./ci/scripts/fly.sh -f <foundation>

# Create a release
./ci/scripts/fly.sh -f <foundation> -r "Release notes"
\```
```

### Phase 5: Testing and Validation

1. **Validate Pipelines**

```bash
# Validate all pipeline definitions
./ci/scripts/fly.sh validate all
```

2. **Test with Dry Run**

```bash
# Test setting the pipeline with dry run
./ci/scripts/fly.sh -f <foundation> --dry-run
```

3. **Deploy in Lab Environment**

```bash
# Set the pipeline in a lab environment
./ci/scripts/fly.sh -f cml-k8s-n-01
```

4. **Test Complete Flow**

- Trigger the pipeline with a configuration change
- Verify all jobs complete successfully
- Test the release process in a lab environment

### Phase 6: Cleanup and Finalization

1. **Remove Unnecessary Files**

After confirming everything works:

```bash
# Remove backup files if no longer needed
git clean -fd
```

2. **Commit Changes**

```bash
git add .
git commit -m "Standardize CI folder structure and pipeline definition"
```

3. **Create Pull Request**

Create a detailed pull request explaining the changes and migration.

## Troubleshooting

### Common Issues

1. **Missing Paths**

- **Symptom**: Errors about missing files or directories
- **Fix**: Check that all paths in task references are correct relative to the repository root

2. **Parameter Errors**

- **Symptom**: Tasks fail due to missing parameters
- **Fix**: Ensure all required parameters are defined in task.yml files and passed from pipelines

3. **Script Permission Issues**

- **Symptom**: "Permission denied" errors when running scripts
- **Fix**: Ensure all .sh files have execute permissions: `chmod +x ci/tasks/**/*.sh`

4. **Path References in Scripts**

- **Symptom**: Scripts cannot find referenced files
- **Fix**: Update relative paths in scripts to account for new directory structure

### Rollback Procedure

If you encounter issues that cannot be resolved quickly:

1. Restore from your backup branch
2. Document the issues encountered
3. Revisit the migration with adjusted approach

## Post-Migration

After successfully migrating to the standardized structure:

1. Update any documentation or wiki pages that reference the old structure
2. Update any external scripts or automation that might reference the old paths
3. Share lessons learned to improve the migration process for other repositories