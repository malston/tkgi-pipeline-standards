# Quick Start Guide: Generate Reference Template

This guide explains how to use the `generate-reference-template.py` script to create standardized pipeline templates for your projects.

## Prerequisites

- Python 3.6 or higher
- PyYAML library (`pip install pyyaml`)

## Running the Script

### Using the Makefile (Recommended)

The easiest way to run the template generator is using the provided Makefile, which handles the virtual environment automatically:

```bash
cd template-generator

# First time setup (creates virtual environment and installs dependencies)
make setup

# Generate a template (with required OUTPUT_DIR parameter)
make generate OUTPUT_DIR=./my-new-project

# Generate a specific template type
make generate-kustomize OUTPUT_DIR=./my-kustomize-project
make generate-helm OUTPUT_DIR=./my-helm-chart
make generate-cli OUTPUT_DIR=./my-cli-tool

# Pass additional parameters as needed
make generate OUTPUT_DIR=./my-new-project ORG_NAME="MyOrg" REPO_NAME="my-service"
```

For a full list of available commands:

```bash
make help
```

### Standard Execution (Manual)

If you prefer not to use the Makefile:

```bash
cd template-generator
python generate-reference-template.py --output-dir ./my-new-project
```

### Using a Virtual Environment (Manual)

For isolated dependencies without using the Makefile:

```bash
# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate

# Install required dependencies
pip install pyyaml

# Run the script
python generate-reference-template.py --output-dir ./my-new-project

# When finished
deactivate
```

All methods will create a complete reference template using default values in the specified directory.

## Customizing Using Command Line Arguments

You can customize basic settings using command line arguments:

```bash
python generate-reference-template.py \
  --output-dir ./my-new-project \
  --template-type kustomize \
  --org-name "Utilities-tkgieng" \
  --repo-name "my-service" \
  --default-branch "main" \
  --default-foundation "cml-k8s-n-01"
```

### Available Template Types

Choose the right template type for your project:

```bash
# For Kubernetes projects using Kustomize (default)
python generate-reference-template.py --output-dir ./my-project --template-type kustomize

# For Helm chart repositories
python generate-reference-template.py --output-dir ./my-chart --template-type helm

# For CLI tool management projects
python generate-reference-template.py --output-dir ./my-tool --template-type cli-tool
```

Each template type includes appropriate task definitions organized by category:

- All templates include common categories: `common`, `tkgi`, and `testing` tasks
- Kustomize templates include: k8s-specific tasks and common tasks
- Helm templates include: helm and k8s-specific tasks
- CLI tool templates include: cli-tool-specific tasks

## Customizing Using a Configuration File

For more advanced customization, create a YAML configuration file:

1. Create a copy of `sample-config.yml`:

   ```bash
   cp sample-config.yml my-config.yml
   ```

2. Edit the configuration file to customize settings:

   ```yaml
   # Organization and repository information
   org_name: "Utilities-tkgieng"
   repo_name: "my-service"
   
   # Git branch configuration
   default_branch: "develop"
   
   # Custom variables
   pipeline_prefix: "svc"
   ```

3. Use the configuration file when generating:

   ```bash
   python generate-reference-template.py --output-dir ./my-new-project --config my-config.yml
   ```

## Available Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `template_type` | Type of template to generate (kustomize, helm, cli-tool) | "kustomize" |
| `org_name` | GitHub organization name | "Utilities-tkgieng" |
| `repo_name` | Repository name | "my-service" |
| `default_branch` | Default git branch | "develop" |
| `release_branch` | Branch used for releases | "release" |
| `default_environment` | Default environment | "lab" |
| `default_foundation` | Default foundation | "cml-k8s-n-01" |
| `default_pipeline` | Default pipeline name | "main" |
| `default_timer_duration` | Default interval for timer resource | "3h" |
| `github_domain` | GitHub domain | "github.com" |
| `env_variables` | Environment variables to set | See sample config |
| `pipeline_prefix` | Prefix for pipeline names | "" |

You can add any custom variables to your configuration file, and they will be available as template variables using the `${variable_name}` syntax.

## Next Steps After Generation

After generating your reference template:

1. Review the generated files and customize as needed
2. Add your specific pipeline YAML files to `ci/pipelines/`
3. Test the scripts using the included test framework:

   ```bash
   cd my-new-project/ci/scripts/tests
   ./run_tests.sh
   ```

## Validating an Existing Project

You can validate an existing project against the reference template standards using the validation script:

### Using the Makefile

```bash
# Validate a project against the template standards
make validate PROJECT_DIR=/path/to/your-project TEMPLATE_TYPE=kustomize

# For more detailed output
make validate PROJECT_DIR=/path/to/your-project TEMPLATE_TYPE=helm VERBOSE=true
```

### Manual Validation

```bash
# Validate a project against the kustomize template standards
./validate-template-compliance.py --project-dir /path/to/your-project --template-type kustomize

# For more detailed output
./validate-template-compliance.py --project-dir /path/to/your-project --template-type helm --verbose
```

The validation script checks for:

- Required directory structure
- Required files
- Script standards (shebang, strict mode, etc.)
- fly.sh commands and options
- Pipeline YAML structure
- Task file organization
- Test framework implementation

If issues are found, the script will provide a categorized report and suggest next steps for remediation.

## Updating an Existing Project

To update an existing project with a new reference template:

1. Generate a new template in a temporary directory
2. Use the validation script to identify compliance issues:
   ```bash
   ./validate-template-compliance.py --project-dir /path/to/your-project --template-type kustomize
   ```
3. Compare the generated files with your existing files
4. Merge the changes manually or using tools like `diff` and `patch`

## Testing Template Generation and Validation

To ensure that generated templates comply with the standards, you can run the automated tests:

### Using the Makefile

```bash
# Run all tests
make test

# For detailed output
make test VERBOSE=true
```

### Manual Testing

```bash
# Test template task filtering
./test-task-filtering.py

# Test template compliance
./test-template-compliance.py

# For detailed output
./test-template-compliance.py --verbose
```

The test scripts:
1. Generate templates for each template type (kustomize, helm, cli-tool)
2. Validate that only the correct task directories are included for each template type
3. Validate each generated template using validate-template-compliance.py
4. Report any compliance issues found

This is useful for checking that the template generator produces fully compliant templates and that the validation script is correctly configured.

## Best Practices

- Keep custom modifications minimal and well-documented
- Add tests for any custom functionality you add
- Consider contributing improvements back to the reference template
- Run the validation script regularly to ensure ongoing compliance
