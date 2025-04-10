# Pipeline Management Scripts

This directory contains scripts for managing Concourse pipelines, with a focus on providing a standardized interface for common tasks.

## Main Script: fly.sh

The main entry point is `fly.sh`, which provides a robust interface for interacting with Concourse pipelines:

```
./fly.sh [options] [command] [pipeline_name]
```

### Commands

- `set`: Set pipeline (default when no command is specified)
- `unpause`: Set and unpause pipeline
- `destroy`: Destroy specified pipeline
- `validate`: Validate pipeline YAML without setting
- `release`: Create a release pipeline

### Options

```
-f, --foundation NAME      Foundation name (required)
-t, --target TARGET        Concourse target (default: <foundation>)
-e, --environment ENV      Environment type (lab|nonprod|prod)
-b, --branch BRANCH        Git branch for pipeline repository
-c, --config-branch BRANCH Git branch for config repository
-d, --params-branch BRANCH Params git branch (default: master)
-p, --pipeline NAME        Custom pipeline name prefix
-o, --github-org ORG       GitHub organization
-v, --version VERSION      Pipeline version
--release                  Create a release pipeline
--set-release-pipeline     Set the release pipeline
--dry-run                  Simulate without making changes
--verbose                  Increase output verbosity
--timer DURATION           Set timer trigger duration
--enable-validation-testing Enable validation testing
-h, --help                 Show help message
```

### Command-Specific Help

For detailed help on specific commands, use any of these formats:

```
./fly.sh --help [command]   # Example: ./fly.sh --help set
./fly.sh -h [command]       # Example: ./fly.sh -h unpause
./fly.sh [command] --help   # Example: ./fly.sh destroy --help
./fly.sh [command] -h       # Example: ./fly.sh validate -h
```

## Modular Structure

The script follows a modular architecture:

```
.
├── fly.sh               # Main script - the entry point
├── helpers.sh           # Optional repository-specific helpers
├── lib/                 # Module library
│   ├── commands.sh      # Command implementations 
│   ├── help.sh          # Help display functions
│   ├── parsing.sh       # Argument parsing functions
│   ├── README.md        # Module documentation
│   └── utils.sh         # Utility functions
└── tests/               # Test scripts
    ├── helpers.sh       # Test helper functions
    └── test_*.sh        # Test scripts
```

### Modules

1. **help.sh**: Contains functions for displaying help information
   - `show_command_usage()`: Displays help for a specific command
   - `show_general_usage()`: Displays general help
   - `show_usage()`: Compatibility wrapper for general help

2. **utils.sh**: Contains utility functions used throughout the script
   - `info()`, `error()`, `success()`: Logging functions
   - `determine_environment()`: Determines environment from foundation name
   - `get_datacenter()`: Determines datacenter from foundation name
   - `check_fly()`: Verifies the fly command is available
   - `validate_file_exists()`: Checks if a file exists

3. **commands.sh**: Contains command implementations
   - `cmd_set_pipeline()`: Sets a Concourse pipeline
   - `cmd_unpause_pipeline()`: Sets and unpauses a pipeline
   - `cmd_destroy_pipeline()`: Destroys a pipeline
   - `cmd_validate_pipeline()`: Validates a pipeline
   - `cmd_release_pipeline()`: Creates a release pipeline

4. **parsing.sh**: Contains argument parsing logic
   - `check_help_flags()`: Handles help flags in different formats
   - `preprocess_args()`: Preprocesses arguments (especially --option=value format)
   - `process_short_args()`: Processes short-form arguments (-f value)
   - `detect_command_and_pipeline()`: Identifies command and pipeline arguments
   - `handle_legacy_behavior()`: Handles legacy flag options
   - `validate_and_set_defaults()`: Validates required parameters and sets defaults

## Building and Testing

Use the included Makefile for building and testing:

```
# Build the script (ensure executable permissions are set)
make build

# Run tests
make test

# Clean up temporary files
make clean
```

## Adding New Features

To add new features:

1. Identify which module should contain the new functionality
2. Add your functions to the appropriate module
3. Update the main script if needed
4. Add tests for your new functionality in the `tests/` directory
5. Test using `make test`

## Example Usage

### Setting a Pipeline

```sh
# Basic pipeline set
./fly.sh -f cml-k8s-n-01 set main

# Specifying environment
./fly.sh -f cml-k8s-n-01 -e lab set main

# Dry run mode
./fly.sh -f cml-k8s-n-01 set main --dry-run
```

### Setting and Unpausing a Pipeline

```sh
./fly.sh -f cml-k8s-n-01 unpause main
```

### Validating Pipelines

```sh
# Validate a single pipeline
./fly.sh -f cml-k8s-n-01 validate main

# Validate all pipelines
./fly.sh validate all
```

### Destroying a Pipeline

```sh
./fly.sh -f cml-k8s-n-01 destroy main
```

### Creating a Release Pipeline

```sh
./fly.sh -f cml-k8s-n-01 release
```