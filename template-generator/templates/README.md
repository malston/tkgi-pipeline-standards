# ${repo_name} Pipeline Reference

This reference template provides standardized pipeline management scripts for ${repo_name} CI/CD pipelines. Generated for ${org_name}.

## Directory Structure

```sh
${repo_name}/
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

The simplified script in the CI directory is designed for basic pipeline operations with minimal configuration.

Usage:

```bash
./fly.sh -f FOUNDATION [-p PIPELINE] [-t TARGET] [-P PARAMS_REPO] [-d PARAMS_BRANCH] [-b BRANCH]
```

Example:

```bash
# Set the main pipeline for foundation ${default_foundation}
./fly.sh -f ${default_foundation}

# Set a custom pipeline with a specific params git branch
./fly.sh -f ${default_foundation} -p custom -d feature-branch
```

### Advanced CI Script (`ci/scripts/fly.sh`)

The advanced script in the scripts directory provides additional functionality and more configuration options.

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
./fly.sh -f ${default_foundation} unpause

# Create a release pipeline with version 1.2.3
./fly.sh -f ${default_foundation} --version 1.2.3 release
```

## Testing

This template includes a test framework to validate the functionality of the scripts. To run the tests:

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

## Notes

- Default foundation: ${default_foundation}
- Default branch: ${default_branch}
- Default environment: ${default_environment}
- Default pipeline: ${default_pipeline}
