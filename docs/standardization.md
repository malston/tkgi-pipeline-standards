# CI Standardization Reference Implementation

This repository serves as a reference implementation for standardized CI folder structures, Concourse tasks, and fly scripts across pipeline repositories. It provides a consistent approach to organizing CI assets and interacting with Concourse CI.

## Table of Contents
- [Folder Structure](#folder-structure)
- [Fly Script Usage](#fly-script-usage)
- [Task Definitions](#task-definitions)
- [Migration Guide](#migration-guide)
- [Validation Checklist](#validation-checklist)

## Folder Structure

We've standardized on the following folder structure for CI-related assets:

```
repository-root/
├── ci/
│   ├── pipelines/       # Pipeline definition files
│   ├── tasks/           # Task definitions and scripts
│   ├── vars/            # Variables for different environments
│   ├── resources/       # Custom resource types
│   └── images/          # Dockerfile definitions
└── scripts/             # Fly scripts and utilities
```

See the [detailed folder structure documentation](./docs/folder-structure.md) for more information.

## Fly Script Usage

The standardized fly script provides a consistent interface for interacting with Concourse CI. It supports the following commands:

```
Usage: ./fly.sh COMMAND [options]

Commands:
  set-pipeline    Set or update a pipeline
  destroy-pipeline Remove a pipeline
  execute-task    Execute a single task locally
  login           Login to the Concourse instance
  help            Display this help message

Global Options:
  -t, --target    TARGET    Concourse target (required)
  -v, --verbose             Enable verbose output
  -h, --help                Display help for the given command
```

Example usage:

```bash
# Set a pipeline
./scripts/fly.sh set-pipeline -t main -p my-pipeline -e prod

# Execute a task locally
./scripts/fly.sh execute-task -t main -f ci/tasks/deploy/deploy-to-dev.yml

# Login to Concourse
./scripts/fly.sh login -t main
```

See the [detailed fly script documentation](./docs/fly-script.md) for more information.

## Task Definitions

Task definitions follow a standard format with consistent naming and organization:

1. Task YAML files are stored in `ci/tasks/<category>/<task-name>.yml`
2. Task scripts are stored in `ci/tasks/<category>/scripts/<script-name>.sh`
3. Common tasks that are used across multiple pipelines are stored in `ci/tasks/common/`

Example task definition:

```yaml
# ci/tasks/deploy/deploy-to-dev.yml
---
platform: linux
image_resource:
  type: registry-image
  source:
    repository: ((docker_registry))/deploy-image
    tag: latest
inputs:
  - name: source-code
run:
  path: source-code/ci/tasks/deploy/scripts/deploy.sh
```

See the [detailed task documentation](./docs/tasks.md) for more information.

## Migration Guide

To migrate an existing repository to this standardized structure:

1. Clone this reference repository
2. Copy the `scripts/` directory to your repository
3. Create the standardized `ci/` directory structure
4. Move existing pipeline definitions to `ci/pipelines/`
5. Move existing task definitions and scripts to the appropriate locations under `ci/tasks/`
6. Update pipeline references to task files to use the new paths
7. Test all pipelines using the standardized fly script

See the [detailed migration guide](./docs/migration.md) for step-by-step instructions.

## Validation Checklist

Use this checklist to verify that your repository adheres to the standardized structure:

- [ ] All CI-related files are under the `ci/` directory
- [ ] Pipeline definitions are in `ci/pipelines/`
- [ ] Task definitions are in `ci/tasks/<category>/`
- [ ] Task scripts are in `ci/tasks/<category>/scripts/`
- [ ] Environment variables are in `ci/vars/`
- [ ] The standardized fly script is used for all Concourse operations
- [ ] Pipeline references to tasks use the standardized paths
- [ ] All pipelines have been tested and verified to work with the new structure

## Best Practices

- Use consistent naming for tasks and scripts
- Keep task scripts focused on a single responsibility
- Use environment variables for configuration
- Leverage common tasks for shared functionality
- Document all custom parameters and usage
- Test all pipelines locally before pushing changes

## Contributing

If you have suggestions for improving these standards, please submit a pull request with your proposed changes.

