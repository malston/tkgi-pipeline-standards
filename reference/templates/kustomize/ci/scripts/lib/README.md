# Modular Script Library for fly.sh

This directory contains modular components for the fly.sh script, making the codebase more maintainable and easier to understand.

## Modules

The script is divided into several logical modules:

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

5. **pipelines.sh**: Contains pipeline-specific helper functions
   - `get_latest_version()`: Gets the latest version from git tags
   - `pipeline_pause_check()`: Checks if a pipeline is paused and offers to unpause it
   - `generate_pipeline_config()`: Generates pipeline configuration using ytt

## How It Works

The main fly.sh script sources these modules and orchestrates their execution:

1. First, it initializes default values for all variables
2. Then it sources the module files to load all required functions
3. In the `main()` function, it:
   - Checks for help flags
   - Processes and normalizes arguments
   - Detects command and pipeline arguments
   - Handles legacy behavior conversion
   - Validates required parameters
   - Executes the requested command

## Building and Testing

To build and test the modular script, use the provided Makefile:

```sh
# Build the script
make build

# Test the script
make test

# Install the modular script (replace the original)
make install
```

## Adding New Features

To add new features:

1. Identify which module should contain the new functionality
2. Add your functions to the appropriate module
3. Update the main script if needed
4. Add tests for your new functionality
5. Test using `make test`
