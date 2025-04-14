# Reference Template for Pipeline Management

This reference template demonstrates the recommended structure and implementation for standardized pipeline management scripts. It's designed to be reused across projects with minimal modifications.

## Directory Structure

```sh
pipeline/
├── ci/
│   ├── fly.sh                 # Simplified script for basic pipeline operations
│   ├── pipelines/             # Contains pipeline YAML definitions
│   └── scripts/               # Advanced scripts and utilities
│       ├── fly.sh             # Enhanced script with more features
│       ├── lib/               # Library modules for the advanced script
│       │   ├── commands.sh    # Implementation of script commands
│       │   ├── help.sh        # Help text and usage information
│       │   ├── parsing.sh     # Command-line argument parsing
│       │   └── utils.sh       # Utility functions
│       └── tests/             # Test framework and test cases
│           ├── run_tests.sh   # Script to run all tests
│           ├── test-framework.sh  # Testing utilities and assertions
│           └── test_*.sh      # Individual test files
└── scripts/                   # Repository-level utility scripts
```

## Scripts Overview

### Simple CI Script (`ci/fly.sh`)

The simplified script in the CI directory is designed for basic pipeline operations with minimal configuration. It's a wrapper around the more advanced script and suitable for common use cases.

Usage:

```bash
./fly.sh -f FOUNDATION [-p PIPELINE] [-t TARGET] [-P PARAMS_REPO] [-d PARAMS_BRANCH] [-b BRANCH]
```

Example:

```bash
# Set the main pipeline for foundation cml-k8s-n-01
./fly.sh -f cml-k8s-n-01

# Set a custom pipeline with a specific params git branch
./fly.sh -f cml-k8s-n-01 -p custom -d feature-branch
```

### Advanced CI Script (`ci/scripts/fly.sh`)

The advanced script in the scripts directory provides additional functionality and more configuration options. It's modular, extensible, and includes support for various pipeline operations.

Usage:

```bash
./fly.sh [options] [command] [pipeline_name]
```

Commands:

- `set`: Set a pipeline (default)
- `unpause`: Set and unpause a pipeline
- `destroy`: Destroy a pipeline
- `validate`: Validate pipeline YAML without setting
- `release`: Create a release pipeline

Example:

```bash
# Set and unpause the main pipeline
./fly.sh -f cml-k8s-n-01 unpause

# Create a release pipeline with version 1.2.3
./fly.sh -f cml-k8s-n-01 --version 1.2.3 release
```

## How to Use in a New Project

1. Copy the entire `fly` directory to your project
2. Rename the directory as needed (e.g., to match your project name)
3. Update any project-specific values in the scripts
4. Add your pipeline YAML files to the `ci/pipelines` directory
5. If needed, create project-specific helper functions in `scripts/helpers.sh`

## Testing

The template includes a test framework to validate the functionality of the scripts. To run the tests:

```bash
cd ci/scripts/tests
./run_tests.sh
```

This will execute all test files and report the results.

## Best Practices

1. **Keep the simple script simple**: Only add to the simple script what's absolutely necessary
2. **Modularize the advanced script**: Keep functionality in appropriate library files
3. **Write tests**: Add tests for new functionality to ensure everything works as expected
4. **Document usage**: Update help text and README.md with any changes
5. **Maintain backwards compatibility**: Avoid breaking changes when extending the scripts
