# CI Directory Structure

This directory contains all CI/CD pipeline configurations and tasks for the kustomize-based repository.

## Structure

- `pipelines/`: Contains all pipeline definition YAML files
  - `main.yml`: Main pipeline for applying Kubernetes resources
  - `release.yml`: Release pipeline for creating GitHub releases
  - `set-pipeline.yml`: Pipeline for setting other pipelines

- `fly.sh`: Simplified script for setting and managing pipelines (mirroring the ns-mgmt pattern)

- `scripts/`: Control scripts for more advanced functionality
  - `fly.sh`: Comprehensive pipeline management script with advanced features
  - `cmd_set_pipeline.sh`: Command implementations for the advanced fly.sh script

- `tasks/`: Tasks organized by functional category
  - `common/`: Common/shared tasks
    - `kubectl-apply/`: Kubernetes apply resource task
    - `kustomize/`: Kustomize resource generation task
    - `prepare-kustomize/`: Kustomize preparation task
    - `set-pipeline/`: Pipeline management task
  - `k8s/`: Kubernetes-specific tasks
    - `create-resources/`: Resource creation task
    - `validate-resources/`: Resource validation task
  - `tkgi/`: TKGi-specific tasks
    - `tkgi-login/`: TKGi login task
  - `testing/`: Testing tasks
    - `run-tests/`: Test execution task

Each task directory contains both a `task.yml` file (the task definition) and a `task.sh` file (the task implementation).

## Using fly.sh

This template provides two versions of the `fly.sh` script:

### 1. Simplified Version (ci/fly.sh)

The simplified version in the `ci` directory follows the pattern used in the ns-mgmt repository:

```bash
./ci/fly.sh -t <concourse-target> -p <pipeline> -f <foundation> [-v] [-c <config-repo-path>]
```

Example:
```bash
# Set the main pipeline for a specific foundation
./ci/fly.sh -t concourse-target -p main -f cml-k8s-n-01

# Use verbose output
./ci/fly.sh -t concourse-target -p main -f cml-k8s-n-01 -v
```

### 2. Advanced Version (ci/scripts/fly.sh)

The advanced version in the `ci/scripts` directory provides more functionality:

```bash
./ci/scripts/fly.sh [options] [command] [pipeline_name]
```

This version includes:
- Multiple commands (set, unpause, destroy, validate)
- Special commands for release pipelines and self-updates
- Advanced options for environments, branches, and configurations
- Dry-run capabilities
- Pipeline validation

## Task Design Pattern

Each task follows a standard pattern:

1. **Task YAML** (`task.yml`): Defines inputs, outputs, and parameters for the task.
2. **Task Script** (`task.sh`): Implements the task logic, including:
   - Validating required parameters
   - Setting default values for optional parameters
   - Executing the task logic
   - Handling errors

The task scripts typically call into the repository's scripts (in `../scripts/`) to perform the actual work, with the task script handling pipeline-specific aspects like input/output management.

## Pipeline Structure

Pipelines are organized to follow a standard workflow:

1. **Validation**: Validate resources before deployment
2. **Building**: Generate Kubernetes manifests using kustomize
3. **Deployment**: Apply resources to Kubernetes clusters

This structure ensures resources are properly validated and built before being applied to any clusters.