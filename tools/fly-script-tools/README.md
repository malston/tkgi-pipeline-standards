# Fly Script Tools

This directory contains tools for generating, validating, and migrating `fly.sh` scripts to conform with tkgi-pipeline-standards.

## Overview

These tools help maintain consistency in the way we interact with Concourse pipelines across different repositories. The standardized `fly.sh` script provides a common interface for operations like setting, validating, and managing pipelines.

## Tools

### 1. Generate Fly Script

Generates a standardized `fly.sh` script along with supporting files.

```bash
python3 generate_fly_script.py -t kustomize -o /path/to/output/dir -p my-pipeline-name
```

#### Options:
- `-t, --template`: Template type to use (kustomize, helm, cli-tool)
- `-o, --output-dir`: Output directory for the script
- `-c, --config`: YAML config file with custom values
- `-p, --pipeline-name`: Base pipeline name
- `--alternative-tests`: Generate alternative test framework

### 2. Validate Fly Script

Validates that a `fly.sh` script conforms to the standards.

```bash
python3 validate_fly_script.py -d /path/to/scripts/dir [-o report.json] [-v]
```

#### Options:
- `-d, --directory`: Directory containing the fly.sh script
- `-o, --output`: Output file for validation report
- `-v, --verbose`: Show detailed validation results

### 3. Migrate Fly Script

Migrates an existing `fly.sh` script to conform to the standards.

```bash
python3 migrate_fly_script.py -i /path/to/existing/fly.sh -o /path/to/output/dir
```

#### Options:
- `-i, --input`: Path to existing fly.sh script
- `-o, --output-dir`: Output directory for migrated script
- `-b, --backup`: Create backup of original script
- `--alternative-tests`: Generate alternative tests instead of standard tests
- `-v, --verbose`: Show detailed migration steps

## Standards

A standard `fly.sh` script should:

1. Have a modular structure with separate files for distinct functionality
2. Support a common set of commands: set, unpause, destroy, validate, release, set-pipeline
3. Support a common set of options for foundation, environment, branches, etc.
4. Include proper error handling and validation
5. Have tests to verify functionality

### Directory Structure

```
scripts/
├── fly.sh                 # Main script
├── lib/                   # Modular components
│   ├── commands.sh        # Command implementations
│   ├── help.sh            # Help text and usage information
│   ├── parsing.sh         # Argument parsing
│   └── utils.sh           # Utility functions
└── tests/                 # Tests
    ├── run-tests.sh       # Test runner
    ├── test-framework.sh  # Test framework
    └── test-fly-basics.sh # Basic tests
```

## Using the Makefile

For easier use, a Makefile is provided that wraps the Python scripts. Use it as follows:

```bash
# Show help
make help

# Setup environment
make setup

# Generate scripts
make generate OUTPUT_DIR=/path/to/output/dir PIPELINE_NAME=my-pipeline
make generate-kustomize OUTPUT_DIR=/path/to/output/dir PIPELINE_NAME=my-project
make generate-helm OUTPUT_DIR=/path/to/output/dir PIPELINE_NAME=my-helm-chart
make generate-cli OUTPUT_DIR=/path/to/output/dir PIPELINE_NAME=my-cli-tool

# Validate a script
make validate SCRIPT_DIR=/path/to/scripts/dir VERBOSE=true

# Migrate an existing script
make migrate INPUT_FILE=/path/to/fly.sh OUTPUT_DIR=/path/to/output/dir BACKUP=true
```

### Makefile Parameters

- `OUTPUT_DIR`: Directory where generated files will be placed
- `INPUT_FILE`: Path to existing fly.sh script (for migration)
- `SCRIPT_DIR`: Directory containing fly.sh script (for validation)
- `PIPELINE_NAME`: Name of the pipeline to use in generated scripts
- `ALTERNATIVE_TESTS`: Set to any value to generate alternative tests
- `VERBOSE`: Set to any value to enable verbose output
- `BACKUP`: Set to any value to create a backup when migrating

## Examples

### Generate a new fly.sh script for a kustomize project:

```bash
# Using Python script directly
python3 generate_fly_script.py -t kustomize -o /path/to/repo/ci/scripts -p my-k8s-app

# Using Makefile
make generate-kustomize OUTPUT_DIR=/path/to/repo/ci/scripts PIPELINE_NAME=my-k8s-app
```

### Validate an existing fly.sh script:

```bash
# Using Python script directly
python3 validate_fly_script.py -d /path/to/repo/ci/scripts -v

# Using Makefile
make validate SCRIPT_DIR=/path/to/repo/ci/scripts VERBOSE=true
```

### Migrate an existing fly.sh script:

```bash
# Using Python script directly
python3 migrate_fly_script.py -i /path/to/repo/ci/scripts/fly.sh -o /path/to/repo/ci/scripts-new -b --alternative-tests

# Using Makefile
make migrate INPUT_FILE=/path/to/repo/ci/scripts/fly.sh OUTPUT_DIR=/path/to/repo/ci/scripts-new BACKUP=true ALTERNATIVE_TESTS=true
```

## Contributing

To add more templates or enhance existing ones:

1. Add new template files to the `templates/` directory
2. Update the tools to support the new templates
3. Add tests for your changes