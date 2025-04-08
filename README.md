# TKGI Pipeline Standards

A reference implementation for standardizing CI folder structures, Concourse tasks, and fly scripts across TKGI platform component repositories (gatekeeper, istio, prisma-defender, etc.) with support for multiple datacenters and foundations.

## Overview

This repository provides a standardized approach for managing component installation pipelines for TKGI clusters across multiple datacenters and foundations. It includes:

1. A consistent folder structure for component repositories
2. Standardized fly scripts with datacenter/foundation awareness
3. Integration with a separate params repository
4. Pipeline promotion workflow for releasing to Ops Concourse
5. Tools for validation and creation of conformant repositories

## Folder Structure

Each component repository should follow this standard structure:

```
component-repo-root/  # e.g., gatekeeper-mgmt, istio-mgmt, prisma-defender-mgmt
├── ci/
│   ├── fly.sh        # Standardized fly script
│   ├── lib/          # Fly script libraries
│   ├── cmds/         # Fly subcommands 
│   ├── pipelines/    # Pipeline definitions
│   ├── tasks/        # Tasks organized by stage
│   ├── helm/         # Helm values by environment
│   └── vars/         # Component-specific variables (optional)
├── release/          # Pipeline release automation
└── scripts/          # Utility scripts (used both by CI and externally)
```

## Parameter Structure

Parameters are stored in a separate repository called "params" with the following structure:

```
params-repo-root/
├── global.yml            # Global parameters
├── k8s-global.yml        # Kubernetes global parameters
├── global-lab.yml        # Lab environment global parameters
├── cml/                  # CML datacenter
│   ├── cml.yml           # CML datacenter parameters
│   ├── cml-k8s.yml       # CML Kubernetes parameters
│   ├── cml-k8s-n-01.yml  # Foundation-specific parameters
│   └── ...
└── cic/                  # CIC datacenter
    ├── cic.yml           # CIC datacenter parameters
    ├── cic-vxrail.yml    # CIC vxrail parameters
    ├── cic-vxrail-n-01.yml # Foundation-specific parameters
    └── ...
```

## Usage

Each component repository includes a standardized fly script that provides consistent commands:

```bash
# Set up a pipeline for a specific foundation
./ci/fly.sh set-pipeline -t dev -p install -d cml -f cml-k8s-n-01 -P ~/repos/params

# Execute a task locally for testing
./ci/fly.sh execute-task -t dev -f ci/tasks/install/install.yml

# Create a new version release
./ci/fly.sh release-version -v 1.2.3 -m "Added new feature X" --tag

# Promote a pipeline to Ops Concourse for a specific foundation
./ci/fly.sh promote-pipeline -p install -d cml -f cml-k8s-n-01 --ops-target ops-concourse
```

## Foundation Structure

The standardized approach supports multiple datacenters and foundations:

- **Datacenters**
  - CML: Lab environment with two datacenters
  - CIC: Lab environment with vxrail hardware

- **Foundations**
  - CML: `cml-k8s-n-01` through `cml-k8s-n-10`
  - CIC: `cic-vxrail-n-01` through `cic-vxrail-n-06`

## Workflow

### Development Workflow

1. Make changes to the component repository (pipelines, tasks, Helm values)
2. Test locally using the fly script against a specific foundation
3. Commit changes and create a pull request
4. After approval, merge to main branch

### Release Workflow

1. Create a new version release:
   ```bash
   ./ci/fly.sh release-version -v 1.2.3 -m "Release notes" --tag
   ```

2. Promote to one or more foundations:
   ```bash
   # Promote to CML foundation 01
   ./ci/fly.sh promote-pipeline -p install -d cml -f cml-k8s-n-01 --ops-target ops-concourse
   
   # Promote to CIC foundation 02
   ./ci/fly.sh promote-pipeline -p install -d cic -f cic-vxrail-n-02 --ops-target ops-concourse
   ```

## Tools

This repository includes tools to help maintain standardization:

### validate-repo-structure.sh

Validates that a component repository follows the standardized structure:

```bash
./validate-repo-structure.sh /path/to/repo
```

### create-component-repo.sh

Creates a new component repository with the standardized structure:

```bash
./create-component-repo.sh gatekeeper
```

## Pipeline Naming Convention

Pipelines follow a consistent naming convention:

```
<component>-<pipeline>-<foundation>
```

Examples:
- `gatekeeper-install-cml-k8s-n-01`
- `istio-upgrade-cic-vxrail-n-02`
- `prisma-defender-install-cml-k8s-n-03`

## Best Practices

- Use the standardized fly.sh script for all Concourse operations
- Store all component-specific variables in the ci/vars directory
- Use the scripts/ directory for reusable functionality
- Always validate changes before promoting to production
- Use the release-version command to track versions properly
- Keep Helm values separate from pipeline configuration

## Versioning and Promotion

The `versions.yml` file in the `release/` directory tracks version information and promotion history for each foundation:

```yaml
gatekeeper:
  version: "1.2.3"
  date: "2025-04-08T12:34:56Z"
  message: "Added new feature X"
  promotions:
    cml:
      cml-k8s-n-01:
        pipeline: "install"
        date: "2025-04-08T13:00:00Z"
      cml-k8s-n-02:
        pipeline: "install"
        date: "2025-04-08T14:00:00Z"
    cic:
      cic-vxrail-n-01:
        pipeline: "install"
        date: "2025-04-09T09:00:00Z"
```

This allows tracking of which version is deployed to each foundation and when it was promoted.
