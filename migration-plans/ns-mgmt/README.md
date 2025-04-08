# Migration Plan for ns-mgmt Repository

Based on a thorough analysis of your current pipeline structure, task scripts, and their interactions, this plan provides a detailed approach to standardize the CI folder structure while ensuring minimal disruption to your existing workflows.

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
├── pipelines/
│   ├── ns-mgmt.yml
│   ├── release.yml
│   └── set-pipeline.yml
├── scripts/
│   ├── fly.sh
│   └── helpers.sh (optional)
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

## Migration Steps

### 1. Create Feature Branch

```bash
git checkout develop
git pull
git checkout -b feature/standardize-ci-structure
```

### 2. Create New Folder Structure

```bash
# Create task directories for common tasks
mkdir -p ci/scripts
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

### 3. Move and Rename Task Scripts

```bash
# Move common task scripts to their task directories
cp ci/tasks/kapply.sh ci/tasks/common/kubectl-apply/task.sh
cp ci/tasks/kustomize.sh ci/tasks/common/kustomize/task.sh
cp ci/tasks/make-git-commit.sh ci/tasks/common/make-git-commit/task.sh
cp ci/tasks/prepare-kustomize.sh ci/tasks/common/prepare-kustomize/task.sh
cp ci/tasks/create-release-info.sh ci/tasks/common/create-release-info/task.sh

# Move Kubernetes-specific task scripts to their task directories
cp ci/tasks/create-legacy-netpol.sh ci/tasks/k8s/create-legacy-netpol/task.sh
cp ci/tasks/create-legacy-rbac.sh ci/tasks/k8s/create-legacy-rbac/task.sh
cp ci/tasks/create-limits-quotas.sh ci/tasks/k8s/create-limits-quotas/task.sh
cp ci/tasks/create-namespaces.sh ci/tasks/k8s/create-namespaces/task.sh
cp ci/tasks/delete-namespaces.sh ci/tasks/k8s/delete-namespaces/task.sh
cp ci/tasks/validate-namespaces.sh ci/tasks/k8s/validate-namespaces/task.sh

# Move TKGi-specific task scripts to their task directories
cp ci/tasks/tkgi-login.sh ci/tasks/tkgi/tkgi-login/task.sh

# Move testing task scripts to their task directories
cp ci/tasks/test.sh ci/tasks/testing/run-unit-tests/task.sh
```

### 4. Update Script Path References

For each task script in the new task directories, update the relative path references:

```bash
# Process common task scripts
for script in ci/tasks/common/*/task.sh; do
  sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' "$script"
done

# Process k8s task scripts
for script in ci/tasks/k8s/*/task.sh; do
  sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' "$script"
done

# Process tkgi task scripts
for script in ci/tasks/tkgi/*/task.sh; do
  sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' "$script"
done

# Process testing task scripts
for script in ci/tasks/testing/*/task.sh; do
  sed -i 's|__DIR/../../scripts/|__DIR/../../../../scripts/|g' "$script"
done

# Update specific path in test.sh
sed -i 's|__DIR/../../test/tests.sh|__DIR/../../../../test/tests.sh|g' ci/tasks/testing/run-unit-tests/task.sh
```

### 5. Create Task YAML Files

Create YAML definition files for each task:

```bash
# Create task YAML for the kapply common task
cat > ci/tasks/common/kubectl-apply/task.yml << 'EOF'
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
EOF

# Create task YAML for the kustomize common task
cat > ci/tasks/common/kustomize/task.yml << 'EOF'
platform: linux
inputs:
  - name: ns-mgmt
  - name: config
outputs:
  - name: manifests
run:
  path: ns-mgmt/ci/tasks/common/kustomize/task.sh
params:
  FOUNDATION: ((foundation))
  FOUNDATION_PATH: ((foundation_path))
  VERBOSE: ((verbose))
EOF

# Create similar YAML files for other common tasks
# ...

# Create task YAML for the create-namespaces k8s task
cat > ci/tasks/k8s/create-namespaces/task.yml << 'EOF'
platform: linux
inputs:
  - name: ns-mgmt
  - name: pks-config
  - name: config
  - name: manifests
outputs:
  - name: manifests
run:
  path: ns-mgmt/ci/tasks/k8s/create-namespaces/task.sh
params:
  FOUNDATION: ((foundation))
  PKS_PASSWORD: ((pks_api_admin_pw))
  VERBOSE: ((verbose))
EOF

# Create similar YAML files for other k8s tasks
# ...

# Create task YAML for the tkgi-login task
cat > ci/tasks/tkgi/tkgi-login/task.yml << 'EOF'
platform: linux
inputs:
  - name: ns-mgmt
outputs:
  - name: pks-config
run:
  path: ns-mgmt/ci/tasks/tkgi/tkgi-login/task.sh
params:
  PKS_API_URL: ((pks_api_url))
  PKS_USER: ((pks_api_admin))
  PKS_PASSWORD: ((pks_api_admin_pw))
EOF

# Create task YAML for testing tasks
cat > ci/tasks/testing/run-unit-tests/task.yml << 'EOF'
platform: linux
inputs:
  - name: ns-mgmt
  - name: pks-config
  - name: config
run:
  path: ns-mgmt/ci/tasks/testing/run-unit-tests/task.sh
params:
  FOUNDATION: ((foundation))
  TEST_CLUSTER: ((test_cluster))
  PKS_PASSWORD: ((pks_api_admin_pw))
EOF

# Create remaining task YAML files...
```

### 6. Create Wrapper Scripts for Backward Compatibility

Create wrapper scripts in the original locations that redirect to the new ones:

```bash
# For each task script, create a wrapper
for script in ci/tasks/*.sh; do
  if [ -f "$script" ]; then
    filename=$(basename "$script")
    taskname=${filename%.sh}
    category=""
    
    # Determine the category
    if [[ "$filename" == "kapply.sh" || "$filename" == "kustomize.sh" || 
          "$filename" == "make-git-commit.sh" || "$filename" == "prepare-kustomize.sh" ||
          "$filename" == "create-release-info.sh" ]]; then
      category="common"
    elif [[ "$filename" == "tkgi-login.sh" ]]; then
      category="tkgi"
    elif [[ "$filename" == "test.sh" || "$filename" == "validate-namespaces.sh" ]]; then
      category="testing"
    else
      category="k8s"
    fi
    
    # Save the original script content for backup
    cp "$script" "$script.backup"
    
    # Create a wrapper script that calls the new location
    cat > "$script" << EOF
#!/usr/bin/env bash
# This is a wrapper script that calls the standardized location
# Migrated as part of CI folder structure standardization

# Use direct execution to maintain environment variables and exit code
exec "\$(dirname "\${BASH_SOURCE[0]}")/$category/$taskname/task.sh" "\$@"
EOF
    chmod +x "$script"
  fi
done
```

### 7. Move fly.sh to scripts Directory

```bash
# Copy the current fly.sh to scripts directory
cp ci/fly.sh ci/scripts/

# Create a wrapper for the original location
cat > ci/fly.sh << 'EOF'
#!/usr/bin/env bash
# This is a wrapper script that calls the standardized location
# Migrated as part of CI folder structure standardization
exec "$(dirname "${BASH_SOURCE[0]}")/scripts/fly.sh" "$@"
EOF
chmod +x ci/fly.sh
```

### 8. Create Documentation

Create a README file in the CI directory explaining the new structure:

```bash
cat > ci/README.md << 'EOF'
# CI Directory Structure

This directory contains all CI/CD pipeline configurations and scripts for the ns-mgmt repository.

## Structure

- `pipelines/`: Contains all pipeline definition YAML files
  - `ns-mgmt.yml`: Main namespace management pipeline
  - `release.yml`: Release pipeline for creating GitHub releases
  - `set-pipeline.yml`: Pipeline for setting other pipelines

- `scripts/`: Control scripts for the pipelines
  - `fly.sh`: Standardized script for setting and managing pipelines

- `tasks/`: Tasks organized by functional category
  - `common/`: Common/shared tasks
    - `kapply/`: Kubernetes apply resource task
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

## Using fly.sh

The `fly.sh` script provides a consistent interface for setting and managing pipelines:

\```bash
./ci/scripts/fly.sh -f <foundation> [options] [command] [pipeline_name]
\```

For details on all options, run:

\```bash
./ci/scripts/fly.sh --help
\```

## Backward Compatibility

For backward compatibility, wrapper scripts are provided in the original locations. 
These will be removed in a future release, so please update your scripts to use 
the new standardized locations.
EOF
```

### 9. Test the Migration

Before committing, verify that everything works correctly:

```bash
# Test fly.sh help
./ci/scripts/fly.sh --help

# Test with dry run to see if fly.sh runs correctly
./ci/scripts/fly.sh -f cml-k8s-n-01 --dry-run

# Test validation
./ci/scripts/fly.sh validate all

# Test task scripts directly
./ci/tasks/common/kubectl-apply/task.sh -h
./ci/tasks/k8s/create-namespaces/task.sh -h
./ci/tasks/tkgi/tkgi-login/task.sh -h

# Test wrapper scripts
./ci/tasks/kapply.sh -h
./ci/tasks/create-namespaces.sh -h
./ci/tasks/tkgi-login.sh -h
```

### 10. Phase 1 Pipeline Migration (Optional)

For one or two pipeline jobs, update the pipeline YAML to use the new task YAML files instead of inline task definitions:

```yaml
# From:
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
  image: s3-container-image

# To:
- task: kustomize
  file: ns-mgmt/ci/tasks/common/kustomize/task.yml
  image: s3-container-image
```

This is optional for Phase 1 but would provide a test case for the new task YAML approach.

### 11. Restore Original Task Scripts for Safety

Until the migration is complete and tested, keep the original scripts as .backup files:

```bash
# This step is optional but recommended for immediate rollback ability
for script in ci/tasks/*.backup; do
  if [ -f "$script" ]; then
    cp "$script" "${script%.backup}.original"
  fi
done
```

### 12. Commit Changes

```bash
git add ci/
git commit -m "Standardize CI folder structure and task organization"
git push origin feature/standardize-ci-structure
```

### 13. Create Pull Request

Create a pull request to merge these changes into the `develop` branch.

## Phase 2: Full Adoption (Future Work)

Once the initial migration is complete and proven stable, a second phase can be implemented:

1. **Update All Pipeline YAMLs**: Update all pipeline YAML files to use the task YAML files instead of inline tasks.

2. **Remove Wrapper Scripts**: Remove the wrapper scripts in the original locations.

3. **Update Documentation**: Update documentation to remove references to the old structure.

This second phase should only be undertaken after all dependent repositories and users have been notified and given time to adopt the new structure.

## Testing Strategy

To ensure minimal disruption to your pipelines, follow this testing strategy:

1. **Verify Script Path Updates**:
   Ensure that all script path references are correctly updated in the relocated scripts.

2. **Test Task YAML Files**:
   Use `fly validate-pipeline` with sample pipeline snippets that reference the new task YAML files.

3. **Test Basic Script Execution**:
   Test that scripts in their new locations can be executed with dummy parameters.

4. **Test Wrapper Functionality**:
   Verify that the wrapper scripts correctly redirect to their new locations.

5. **End-to-End Testing**:
   If possible, run a complete pipeline with at least one job updated to use the new task YAML files.

## Special Considerations

1. **Relative Path References**: The task scripts use `__DIR/../../scripts/` to reference scripts in the repository root. These paths have been adjusted in the relocated scripts to be `__DIR/../../../../scripts/`.

2. **Task Organization**: Task scripts and their YAML definitions are now organized in task-specific directories with standardized filenames (`task.yml` and `task.sh`).

3. **Pipeline Updates**: Pipeline YAMLs can be gradually updated to use the new task YAML files. Existing inline task definitions will continue to work with the wrapper scripts.

## Appendix: Mapping of Original to New Files

| Original Location | New Location |
|-------------------|--------------|
| ci/fly.sh | ci/scripts/fly.sh |
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
