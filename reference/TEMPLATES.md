# Reference Implementation Templates

This document provides details about the reference implementation templates available in this repository.

## Overview

The tkgi-pipeline-standards repository contains reference implementations for several CI/CD patterns:

1. **Kustomize Template**: A complete reference for kustomize-based projects
   - Located at `/reference/templates/kustomize/`
   - Features a hybrid approach with two fly.sh scripts:
     - Simple version in `ci/fly.sh` (similar to ns-mgmt)
     - Advanced version in `ci/scripts/fly.sh` with modular architecture
   - Includes a sophisticated modular architecture in `ci/scripts/lib/` with dedicated files:
     - `commands.sh`: Command implementations
     - `help.sh`: Help text and documentation
     - `parsing.sh`: Argument parsing functions
     - `pipelines.sh`: Pipeline management functions
     - `utils.sh`: Utility and helper functions
   - Comprehensive test framework in `ci/scripts/tests/` for CI scripts
   - Makefile in `ci/scripts/` for build and test automation

2. **Helm Template**: A reference for helm-based projects
   - Located at `/reference/templates/helm/`
   - Provides a standardized structure for Helm chart repositories
   - Includes pipeline definitions for testing, publishing, and releasing Helm charts

3. **CLI Tool Template**: A reference for command-line tool projects
   - Located at `/reference/templates/cli-tool/`
   - Supports downloading, installing, configuring, and validating CLI tools
   - Includes specific tasks for tool lifecycle management

## Real-World Implementation

The ns-mgmt repository serves as a real-world implementation of the standardized CI/CD structure. Key aspects of this implementation include:

1. **Task Organization**: Tasks are categorized into common, k8s, tkgi, and testing directories
2. **Task Definition**: Each task has both a task.yml (definition) and task.sh (implementation) file
3. **Pipeline Structure**: Pipeline files reference task.yml files instead of defining tasks inline
4. **Documentation**: The CI directory includes comprehensive documentation about its structure and usage
5. **Standardized fly.sh**: Implements the full command interface as specified in this guide

## Using the Reference Templates

To use these reference templates for a new project:

1. **Create a new repository**: Set up the basic repository structure
2. **Generate template structure using the template generator**:
   - Run the template generator script from the repository root:
     ```sh
     cd template-generator
     python generate-reference-template.py --output-dir /path/to/your/new-project
     ```
   - This will create the appropriate directory structure based on the selected template
3. **Alternatively, copy template structure manually**:
   - Copy the appropriate template from `/reference/templates/` to your repository
4. **Update configuration**:
   - Rename files and update references to match your project
   - Update pipeline files to reference your repositories
   - Configure foundation-specific parameters
5. **Test the implementation**: Run the included tests to validate your setup
   - For kustomize template, use `cd ci/scripts/tests && ./run_tests.sh`
   - These tests validate command handling, option parsing, environment determination, and flag behavior
6. **Set pipelines**: Use the provided `fly.sh` script to set your pipelines

The reference templates are designed to be used with minimal modifications while providing a
fully-functional CI/CD implementation that follows these standards.

## Template Generator

For quickly generating standardized templates, you can use the template generator tool included in the repository:

```sh
cd template-generator
python generate-reference-template.py --output-dir ./my-new-project
```

The generator provides various customization options:

- Specifying organization and repository names
- Configuring default branches and environments
- Setting pipeline prefixes and resource parameters

For more detailed instructions on using the template generator, see the [template generator quick start guide](../template-generator/QUICK-START.md).

## Template Structure

All templates follow the standardized folder structure:

```sh
repository-root/
├── ci/
│   ├── pipelines/            # Pipeline definition files
│   │   ├── main.yml          # Main pipeline
│   │   ├── release.yml       # Release pipeline
│   │   └── set-pipeline.yml  # Pipeline setup pipeline
│   ├── scripts/              # Pipeline control scripts
│   │   ├── lib/              # Modular components for the fly.sh script
│   │   ├── fly.sh            # Standardized pipeline management script
│   │   └── tests/            # Test scripts for CI scripts
│   ├── tasks/                # Task definitions organized by category
│   │   ├── common/           # Common/shared tasks
│   │   ├── specific-category/# Category-specific tasks
│   │   └── ...
│   └── README.md             # Documentation for CI process
|── scripts/                  # Repository-level scripts
│   ├── apply.sh
│   ├── build.sh
│   └── ...
└── tests/                    # Repository-level tests
    ├── test_apply.sh
    ├── test_build.sh
    ├── ...
    └── run_tests.sh
```

## Customizing Templates

When customizing templates for your specific use case:

1. Keep modifications minimal and well-documented
2. Add tests for any custom functionality
3. Consider contributing improvements back to the reference templates
4. Maintain compatibility with the standardized interface
5. Document any deviations from the standard in your repository README