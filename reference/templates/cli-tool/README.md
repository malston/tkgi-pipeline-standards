# CLI Tool Component Template

This template is designed for components that use specialized CLI tools (like `tridentctl`, `istioctl`, etc.) for deployment and management. It follows the standardized pipeline structure with tasks organized in dedicated directories.

## Directory Structure

```
cli-tool-component-template/
├── ci/
│   ├── pipelines/
│   │   ├── main.yml                # Main pipeline (e.g., install)
│   │   ├── release.yml             # Release pipeline
│   │   └── set-pipeline.yml        # Self-management pipeline
│   ├── scripts/
│   │   ├── fly.sh                  # Standardized pipeline management script
│   │   └── helpers.sh              # Helper functions for CI
│   ├── tasks/
│   │   ├── common/
│   │   │   ├── create-release-info/
│   │   │   │   ├── task.yml        # Task definition
│   │   │   │   └── task.sh         # Task implementation
│   │   │   └── make-git-commit/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── cli-tool/               # CLI-specific tasks
│   │   │   ├── download-tool/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   ├── install-tool/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   ├── configure-tool/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── validate-tool/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── tkgi/
│   │   │   └── tkgi-login/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   └── testing/
│   │       └── run-tests/
│   │           ├── task.yml
│   │           └── task.sh
│   └── vars/                       # Environment-specific variables
│       ├── common.yml              # Common variables
│       ├── lab.yml                 # Lab environment variables
│       └── nonprod.yml             # Non-prod environment variables
├── scripts/                        # Repository-level scripts
│   ├── download.sh                 # Downloads the CLI tool
│   ├── install.sh                  # Installs the component
│   ├── configure.sh                # Configures the component
│   ├── validate.sh                 # Validates the installation
│   ├── wipe.sh                     # Removes the component
│   └── helpers.sh                  # Common helper functions
└── test/                           # Tests
    ├── scripts/
    │   └── test-installation.sh
    └── tests.sh                    # Main test script
```

## Task Organization

Each task is organized in its own directory with two key files:

1. `task.yml` - The Concourse task definition
2. `task.sh` - The task implementation script

This structure provides clear organization and makes it easy to locate task definitions and implementations.

## Relationship with Repository Scripts

The task scripts (`ci/tasks/*/task.sh`) serve as pipeline-specific wrappers that:

1. Handle pipeline-specific aspects (inputs, outputs, etc.)
2. Call into the repository scripts in `scripts/` for core functionality
3. Format outputs for pipeline consumption

This separation allows:

- Scripts to be used directly from the command line
- Tasks to focus on pipeline integration
- Core functionality to be tested independently of the pipeline

## Example for Trident Component

For a component that uses tridentctl:

1. `download-tool/task.sh` - Downloads the specific trident version
2. `install-tool/task.sh` - Installs trident across clusters
3. `configure-tool/task.sh` - Configures storage backends and classes
4. `validate-tool/task.sh` - Validates the installation and configuration

Each task calls the corresponding script in the repository's scripts directory.

## How to Use This Template

You can use this template for a new CLI tool-based component using one of two methods:

### Method 1: Using the Template Generator (Recommended)

1. Run the template generator script from the tkgi-pipeline-standards repository root:

   ```bash
   cd /path/to/tkgi-pipeline-standards
   ./tools/template-generator/generate-reference-template.py
   ```

2. Follow the prompts to select the CLI Tool template type and configure your project
3. The script will generate the entire directory structure based on this template
4. Customize the scripts for your specific CLI tool
5. Update the pipeline definitions to match your workflow
6. Configure appropriate variables in the params repository

For more details, see the [template generator quick start guide](../../../tools/template-generator/QUICK-START.md).

### Method 2: Manual Copy

1. Copy the template structure to your repository
2. Customize the scripts for your specific CLI tool
3. Update the pipeline definitions to match your workflow
4. Configure appropriate variables in the params repository

## Flying Pipelines

Use the standardized fly.sh script to set and manage pipelines:

```bash
# Set the main pipeline
./ci/scripts/fly.sh -f cml-k8s-n-01 -p main

# Set the release pipeline
./ci/scripts/fly.sh -f cml-k8s-n-01 -r

# Set the self-management pipeline
./ci/scripts/fly.sh -f cml-k8s-n-01 -s
```
