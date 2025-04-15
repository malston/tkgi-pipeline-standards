# Pipeline CI Script Library

This directory contains library modules used by the main `fly.sh` script. These modules separate functionality into logical components for better organization and maintainability.

## Core Modules

- `commands.sh`: Implementations for the main pipeline commands (set, unpause, destroy, validate, release)
- `parsing.sh`: Command-line argument parsing functions
- `help.sh`: Help text and usage information
- `utils.sh`: Utility functions for common operations
- `environment.sh`: Environment configuration and detection
- `foundation.sh`: Foundation-specific operations
- `version.sh`: Version handling functions
- `pipelines.sh`: Pipeline-specific operations

## Parameters

The script supports the following key parameters:
- `-f, --foundation`: Specify foundation to deploy (required)
- `-t, --target`: Concourse target
- `-b, --branch`: Git branch to use
- `-p, --pipeline`: Pipeline name
- `-P, --params-repo`: Path to params repo
- `-d, --params-branch`: Params git branch
- `--version`: Version for release pipeline
- `--verbose`: Enable verbose output

## Testing

All modules have corresponding tests in the `../tests` directory. To run tests:

```bash
../tests/run_tests.sh
```

## Adding New Features

When adding new features:
1. Add the functionality to the appropriate module
2. Update help documentation in `help.sh`
3. Add parameter handling in `parsing.sh` if needed
4. Create tests in the `../tests` directory