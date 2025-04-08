# TKGi CI/CD Standards Documentation

Welcome to the TKGi CI/CD standardization documentation. This repository contains standards, guidelines, and templates for consistent CI/CD implementation across all TKGi component repositories.

## Overview

This standardization effort aims to:

- Create a consistent structure across all component repositories
- Standardize pipeline definitions and task organization
- Provide a unified interface for pipeline management
- Simplify onboarding for new team members
- Make maintenance and updates more straightforward

## Repository Structure Standard

All TKGi component repositories should follow this standard structure:

```sh
component-repository/
├── ci/
│   ├── pipelines/            # Pipeline definition files
│   │   ├── <component>-mgmt.yml    # Main pipeline
│   │   ├── release.yml             # Release pipeline
│   │   └── set-pipeline.yml        # Pipeline setup pipeline
│   ├── scripts/              # Pipeline control scripts
│   │   ├── fly.sh            # Standardized pipeline management script
│   │   └── helpers.sh        # Helper functions (if needed)
│   ├── tasks/                # Tasks organized by category
│   │   ├── common/           # Common/shared tasks
│   │   ├── k8s/              # Kubernetes-specific tasks
│   │   ├── [deployment-specific]/  # Deployment-specific tasks
│   │   ├── tkgi/             # TKGi-specific tasks
│   │   └── testing/          # Testing tasks
│   └── README.md             # CI documentation
└── README.md                 # Main repository documentation
```

Each component repository should contain only the tasks relevant to its deployment method. The `[deployment-specific]` directory will be one of:

- `kustomize/` - For Kustomize-based deployments
- `helm/` - For Helm-based deployments
- `cli-tool/` - For specialized CLI tool deployments (istioctl, tridentctl, etc.)

## Standard Pipelines

All component repositories should implement these three standard pipelines:

### 1. Component Management Pipeline

The main pipeline for deploying and managing the component, defined in `ci/pipelines/<component>-mgmt.yml`.

Key characteristics:

- Triggered by configuration changes
- Contains jobs for preparation, deployment, and validation
- Manages the day-to-day operations of the component

### 2. Release Pipeline

Handles versioning and releases, defined in `ci/pipelines/release.yml`.

Key characteristics:

- Creates versioned releases
- Merges code from develop to release branch
- Publishes GitHub releases
- Updates version numbers

### 3. Set-Pipeline Pipeline

Manages the deployment of pipelines themselves, defined in `ci/pipelines/set-pipeline.yml`.

Key characteristics:

- Downloads the appropriate version of pipeline definitions
- Sets the pipeline with the correct parameters
- Ensures consistent pipeline configuration

## Standardized fly.sh Interface

All repositories should use a standardized `fly.sh` script with this interface:

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

- `-f, --foundation NAME`: Foundation name (required)
- `-t, --target TARGET`: Concourse target (default: <foundation>)
- `-e, --environment ENV`: Environment type (lab|nonprod|prod)
- `-b, --branch BRANCH`: Git branch for pipeline repository
- `-c, --config-branch BRANCH`: Git branch for config repository
- `-d, --params-branch BRANCH`: Params git branch (default: master)
- And other standard options

## Task Organization

Tasks should be organized by function in task-specific directories:

### Common Tasks

Reusable utility tasks:

- `common/make-git-commit/`: Git commit operations
- `common/create-release-info/`: Generate release information

### K8s Tasks

Kubernetes-specific tasks:

- `k8s/create-namespace/`: Create Kubernetes namespaces
- `k8s/validate-deployment/`: Validate Kubernetes deployments

### TKGi Tasks

TKGi-related tasks:

- `tkgi/tkgi-login/`: TKGi authentication

### Testing Tasks

Testing-related tasks:

- `testing/run-unit-tests/`: Execute unit tests
- `testing/run-integration-tests/`: Execute integration tests

### Deployment-Specific Tasks

Tasks specific to the deployment method of the component.

## Component Templates

Use the appropriate template based on your component's deployment method:

### [Kustomize Template](./templates/kustomize/README.md)

For components deployed using Kustomize with standard Kubernetes manifests.

### [Helm Template](./templates/helm/README.md)

For components packaged as Helm charts.

### [CLI Tool Template](./templates/cli-tool/README.md)

For components deployed with specialized CLI tools (istioctl, tridentctl, etc.).

## Implementation Guide

Follow these steps to implement the standards in your repository:

1. **Assessment**: Review your current repository structure
2. **Template Selection**: Choose the appropriate template for your component
3. **Migration**: Follow the migration plan for your specific component type
4. **Verification**: Use the compliance checklist to verify standardization
5. **Documentation**: Update your repository documentation

## Best Practices

- Keep pipelines as simple as possible
- Use tasks for all non-trivial operations
- Store parameters in the params repository
- Document task interfaces clearly
- Use consistent naming conventions
- Follow the directory structure standard
