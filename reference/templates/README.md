# Pipeline Templates

This directory contains reference templates for standardized CI/CD pipelines based on repository type.

## Available Templates

### 1. Kustomize Template

The [kustomize](./kustomize) template provides a standardized structure for repositories that use Kustomize for Kubernetes resource management. It demonstrates:

- Organized CI task structure with task.yml and task.sh
- Clear separation between CI tasks and repository scripts
- Standard patterns for pipeline configuration and management
- Consistent command-line interfaces

This template follows the task organization principle where each task has:
1. A dedicated directory under `ci/tasks/<category>/<task-name>/`
2. A task.yml file defining the Concourse task
3. A task.sh script implementing the task logic

## Using Templates

To use these templates:

1. Copy the relevant template structure to your repository
2. Customize task scripts and pipeline definitions as needed
3. Ensure scripts are executable (`chmod +x scripts/*.sh ci/scripts/*.sh ci/tasks/**/task.sh`)
4. Update parameters in pipeline files to match your environment

## CI Directory Structure

All templates follow this common structure for CI components:

```sh
ci/
├── pipelines/           # Pipeline YAML definitions
├── scripts/             # Pipeline management scripts
├── tasks/               # Tasks organized by category
│   ├── common/          # Common tasks
│   ├── k8s/             # Kubernetes-specific tasks
│   ├── tkgi/            # TKGi-specific tasks
│   └── testing/         # Testing tasks
└── vars/                # Pipeline variables
```

Each category contains task-specific directories, and each task directory contains both `task.yml` and `task.sh` files.