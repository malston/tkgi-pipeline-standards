# CLI Tool Scripts

This directory contains repository-level scripts that implement the core functionality for CLI tool operations. These scripts are designed to be:

1. Called directly from the command line
2. Invoked by CI tasks in the pipeline
3. Tested independently of the pipeline

## Script Overview

### helpers.sh

Contains common functions used across all scripts, including:
- Logging functions (info, error, success, warning)
- File and directory validation
- Cluster information retrieval
- Kubernetes operations

### download.sh

Downloads and prepares the CLI tool for use.

```bash
./download.sh -t tridentctl -v 24.02.0 -o ./bin
```

### install.sh

Installs the component across all clusters in a foundation.

```bash
./install.sh -f cml-k8s-n-01 -t tridentctl -v 24.02.0 -c /path/to/config-repo
```

### validate.sh

Validates the component installation across all clusters.

```bash
./validate.sh -f cml-k8s-n-01 -t tridentctl -c /path/to/config-repo -o ./validation-results
```

### configure.sh

Configures the component after installation (e.g., sets up storage backends, classes).

```bash
./configure.sh -f cml-k8s-n-01 -t tridentctl -c /path/to/config-repo/foundations/cml-k8s-n-01/trident-config -o ./config-results
```

## Design Principles

1. **Separation of Concerns**: Each script focuses on a specific operation
2. **Self-Contained**: Scripts can be run independently of the pipeline
3. **Consistent Interface**: Common command-line argument patterns
4. **Robust Error Handling**: Validation and clear error messages
5. **Modularity**: Common functions in helpers.sh

## Using These Scripts

The scripts can be used directly from the command line:

```bash
# Download the tool
./scripts/download.sh -t tridentctl -v 24.02.0 -o ./bin

# Install across all clusters
./scripts/install.sh -f cml-k8s-n-01 -t tridentctl -v 24.02.0 -c ./config-repo

# Validate the installation
./scripts/validate.sh -f cml-k8s-n-01 -t tridentctl -c ./config-repo

# Configure backends and storage classes
./scripts/configure.sh -f cml-k8s-n-01 -t tridentctl -c ./config-repo/foundations/cml-k8s-n-01/trident-config
```

They are also called by the Concourse task scripts in the `ci/tasks/` directory, which handle the pipeline-specific aspects like inputs and outputs.