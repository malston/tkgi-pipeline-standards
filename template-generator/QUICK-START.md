# Quick Start Guide: Generate Reference Template

This guide explains how to use the `generate-reference-template.py` script to create standardized pipeline templates for your projects.

## Prerequisites

- Python 3.6 or higher
- PyYAML library (`pip install pyyaml`)

## Running the Script

### Standard Execution

```bash
cd template-generator
python generate-reference-template.py --output-dir ./my-new-project
```

### Using a Virtual Environment

For isolated dependencies:

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

This will create a complete reference template using default values in the specified directory.

## Customizing Using Command Line Arguments

You can customize basic settings using command line arguments:

```bash
python generate-reference-template.py \
  --output-dir ./my-new-project \
  --template-type kustomize \
  --org-name "MyOrganization" \
  --repo-name "my-service" \
  --default-branch "main" \
  --default-foundation "aws-k8s-p-01"
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

Each template type includes appropriate task definitions organized by category.

## Customizing Using a Configuration File

For more advanced customization, create a YAML configuration file:

1. Create a copy of `sample-config.yml`:

   ```bash
   cp sample-config.yml my-config.yml
   ```

2. Edit the configuration file to customize settings:

   ```yaml
   # Organization and repository information
   org_name: "MyOrganization"
   repo_name: "my-service"
   
   # Git branch configuration
   default_branch: "main"
   
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

## Updating an Existing Project

To update an existing project with a new reference template:

1. Generate a new template in a temporary directory
2. Compare the generated files with your existing files
3. Merge the changes manually or using tools like `diff` and `patch`

## Best Practices

- Keep custom modifications minimal and well-documented
- Add tests for any custom functionality you add
- Consider contributing improvements back to the reference template
