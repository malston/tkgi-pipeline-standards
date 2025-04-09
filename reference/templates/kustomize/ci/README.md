# CI Directory Structure

This directory contains all CI/CD pipeline configurations and tasks for the kustomize-based repository.

## Structure

- `pipelines/`: Contains all pipeline definition YAML files
  - `main.yml`: Main pipeline for applying Kubernetes resources
  - `release.yml`: Release pipeline for creating GitHub releases
  - `set-pipeline.yml`: Pipeline for setting other pipelines

- `fly.sh`: Simplified script for setting and managing pipelines (mirroring the ns-mgmt pattern)

- `scripts/`: Control scripts for more advanced functionality
  - `fly.sh`: Comprehensive modular pipeline management script
  - `lib/`: Modular components for the fly.sh script
    - `commands.sh`: Command implementations
    - `help.sh`: Help text and display functions
    - `parsing.sh`: Argument parsing logic
    - `utils.sh`: Utility functions
    - `README.md`: Module documentation
  - `tests/`: Test suite for validating script functionality

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

This template provides two versions of the `fly.sh` script for different use cases:

### 1. Simplified Version (ci/fly.sh)

The simplified version in the `ci` directory follows the pattern used in the ns-mgmt repository's migrated structure:

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

The advanced version in the `ci/scripts` directory provides more functionality while maintaining backward compatibility:

```bash
./ci/scripts/fly.sh [options] [command] [pipeline_name]
```

This version includes:
- Multiple commands (set, unpause, destroy, validate)
- Command-specific help with detailed usage information
- Special commands for release pipelines
- Advanced options for environments, branches, and configurations
- Dry-run capabilities
- Pipeline validation
- Backward compatibility with legacy flag style

The advanced script uses a modular architecture for better maintainability:
- Main script is only ~120 lines, with functionality broken into logical modules
- Each module has a single responsibility (commands, help, utils, parsing)
- New features can be added by extending the appropriate module
- Comprehensive testing suite to validate functionality

Example usage:
```bash
# Basic usage with command-style interface
./ci/scripts/fly.sh set main -f cml-k8s-n-01 -t concourse-target

# Validate pipeline without setting it
./ci/scripts/fly.sh validate main -f cml-k8s-n-01 -t concourse-target

# Destroy pipeline with confirmation
./ci/scripts/fly.sh destroy main -f cml-k8s-n-01 -t concourse-target

# Using dry-run to test without making changes
./ci/scripts/fly.sh set main -f cml-k8s-n-01 -t concourse-target --dry-run

# Getting command-specific help
./ci/scripts/fly.sh --help set
./ci/scripts/fly.sh set --help
```

The advanced script provides a full range of pipeline management capabilities while still supporting simpler usage patterns from the original approach.

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

## Testing

The CI structure includes a test suite for validating script functionality:

```sh
scripts/tests/
├── test_help_commands.sh      # Tests for command-specific help
├── test_commands.sh           # Tests for command functionality
└── helpers.sh                 # Test utilities and assertions
```

To run all tests:

```bash
cd ci/scripts
make test
```

The test suite verifies:

1. **Script Functionality**: Ensures scripts behave as expected
2. **Command Handling**: Validates command-based interface
3. **Option Parsing**: Tests argument parsing and validation
4. **Help System**: Tests the command-specific help functionality
5. **Backward Compatibility**: Ensures legacy flag support works correctly

This testing approach provides confidence when modifying scripts and serves as documentation for how the scripts are expected to behave.

## Modular Architecture

The advanced fly.sh script uses a modular architecture to improve maintainability:

```sh
scripts/
├── fly.sh                     # Main script (120 lines)
├── lib/                       # Modules
│   ├── commands.sh            # Command implementations
│   ├── help.sh                # Help text and display functions
│   ├── parsing.sh             # Argument parsing logic
│   ├── utils.sh               # Utility functions
│   └── README.md              # Module documentation
├── Makefile                   # Build and test automation
└── tests/                     # Test scripts
```

This architecture allows each module to have a single responsibility, making the script easier to understand, maintain, and extend. New features can be added to the appropriate module without impacting other functionality.

The Makefile provides convenient targets for building, testing, and maintaining the script:

```sh
make build      # Ensure proper file permissions
make test       # Run all tests
make clean      # Clean up temporary files
```

This modular approach significantly reduces the complexity of the main script while making the codebase more maintainable and easier to extend.
