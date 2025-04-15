#!/usr/bin/env python3
"""
Template Generator for Pipeline Standards

This script generates a standardized reference template for CI/CD pipelines
based on the tkgi-pipeline-standards. It allows customization through
command-line arguments or a configuration file.

Usage:
    python generate-reference-template.py --output-dir ./my-project --config ./my-config.yaml
    python generate-reference-template.py --output-dir ./my-project --org-name "MyOrg" --repo-name "my-service"

Author: CI/CD Platform Team
"""

import argparse
import json
import os
import shutil
import sys
import yaml
from pathlib import Path
import re
from typing import Dict, Any, Optional, List
import stat
import datetime

# Default values
DEFAULTS = {
    "org_name": "Utilities-tkgieng",
    "repo_name": "my-service",
    "default_branch": "develop",
    "release_branch": "release",
    "default_environment": "lab",
    "default_foundation": "cml-k8s-n-01",
    "default_pipeline": "main",
    "default_timer_duration": "3h",
    "github_domain": "github.com",
    "datacenter_pattern": r"^([a-z]{3})-([a-z0-9]+)-([np])-(\d+)$",  # e.g., cml-k8s-n-01
    "env_variables": {
        "TEST_MODE": "false",
        "DEBUG": "false",
        "VERBOSE": "false"
    }
}

# Template directory - relative to this script
TEMPLATE_DIR = "templates"

class TemplateGenerator:
    """Generator for CI/CD pipeline reference templates"""

    def __init__(self, config: Dict[str, Any]):
        """Initialize the generator with configuration

        Args:
            config: Dictionary containing configuration values
        """
        self.config = {**DEFAULTS, **config}
        script_dir = self._get_script_dir()

        # First look for templates in the script directory itself (new location)
        template_dir = script_dir / TEMPLATE_DIR
        if template_dir.exists():
            self.template_dir = template_dir
        else:
            # Try to find in parent script dir (old location)
            template_dir = script_dir.parent / TEMPLATE_DIR
            if template_dir.exists():
                self.template_dir = template_dir
            else:
                # Try to find in reference/pipeline (new path as of April 2025)
                reference_pipeline = script_dir.parent / "reference" / "pipeline"
                if reference_pipeline.exists():
                    self.template_dir = reference_pipeline
                # Try to find in reference/templates/reference-template (old fallback path)
                else:
                    reference_template = script_dir.parent / "reference" / "templates" / "reference-template"
                    if reference_template.exists():
                        self.template_dir = reference_template
                    else:
                        print("Warning: Could not find templates directory. Using script directory as fallback.")
                        self.template_dir = script_dir

        self.output_dir = Path(self.config.get("output_dir", "./output"))

        # Ensure the output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)

        print(f"Using templates from: {self.template_dir}")

    def _get_script_dir(self) -> Path:
        """Get the directory where this script is located

        Returns:
            Path to the script directory
        """
        return Path(os.path.dirname(os.path.abspath(__file__)))

    def _render_template(self, template_content: str) -> str:
        """Replace template variables with configuration values

        Args:
            template_content: Content of the template file

        Returns:
            Rendered content with variables replaced
        """
        # Replace ${VAR_NAME} style variables
        pattern = r'\$\{([A-Za-z0-9_]+)\}'

        def replace_var(match: re.Match) -> str:
            var_name = match.group(1)
            # Only lowercase the variable name for non-bash scripts
            if not (template_content.startswith('#!') and 'bash' in template_content.splitlines()[0]):
                var_name = var_name.lower()
            # Use get with default to avoid KeyError
            return str(self.config.get(var_name, f"${{{var_name}}}"))

        return re.sub(pattern, replace_var, template_content)

    def _create_directory_structure(self):
        """Create the base directory structure for the template"""
        dirs = [
            "ci/pipelines",
            "ci/scripts/lib",
            "ci/scripts/tests",
            "scripts"
        ]

        for directory in dirs:
            (self.output_dir / directory).mkdir(parents=True, exist_ok=True)

        print(f"Created directory structure in {self.output_dir}")

    def _copy_template_file(self, template_path: str, output_path: str, executable: bool = False) -> bool:
        """Copy a template file from source to destination, with variable replacement

        Args:
            template_path: Path to the template file (relative to template_dir)
            output_path: Path where the file should be copied (relative to output_dir)
            executable: Whether the generated file should be executable

        Returns:
            Boolean indicating whether the copy was successful
        """
        source_file = self.template_dir / template_path
        if not source_file.exists():
            print(f"Warning: Template file {source_file} does not exist.")
            return False

        with open(source_file, 'r') as file:
            content = file.read()

        rendered_content = self._render_template(content)

        output_file = self.output_dir / output_path
        output_file.parent.mkdir(parents=True, exist_ok=True)

        with open(output_file, 'w') as file:
            file.write(rendered_content)

        if executable:
            st = os.stat(output_file)
            os.chmod(output_file, st.st_mode | stat.S_IEXEC)

        print(f"Generated {output_file}")
        return True

    def _generate_template(self, relative_path: str, executable: bool = False) -> None:
        """Generate a template file or create from scratch if it doesn't exist

        Args:
            relative_path: Path to the file relative to the root of the template/output
            executable: Whether the file should be executable
        """
        # Try to copy from template
        if not self._copy_template_file(relative_path, relative_path, executable):
            # If copying fails, generate a new file
            self._generate_new_file(relative_path, executable)

    def _generate_new_file(self, relative_path: str, executable: bool = False) -> None:
        """Generate a new file based on its type

        Args:
            relative_path: Path to the file relative to the root
            executable: Whether the file should be executable
        """
        output_file = self.output_dir / relative_path
        output_file.parent.mkdir(parents=True, exist_ok=True)

        filename = output_file.name
        file_type = output_file.suffix

        # Generate content based on file type
        if file_type == '.sh':
            content = self._generate_bash_template(filename)
        elif file_type == '.py':
            content = self._generate_python_template(filename)
        elif file_type == '.md':
            content = self._generate_markdown_template(filename)
        elif file_type in ['.yml', '.yaml']:
            content = self._generate_yaml_template(filename)
        else:
            content = f"# Generated file: {filename}\n# Created: {datetime.datetime.now().strftime('%Y-%m-%d')}\n\n"

        # Render the template
        content = self._render_template(content)

        # Write the file
        with open(output_file, 'w') as file:
            file.write(content)

        if executable:
            st = os.stat(output_file)
            os.chmod(output_file, st.st_mode | stat.S_IEXEC)

        print(f"Generated {output_file}")

    def _generate_bash_template(self, filename: str) -> str:
        """Generate a bash script template

        Args:
            filename: Name of the file

        Returns:
            Template content
        """
        return f"""#!/usr/bin/env bash
#
# {filename} - Generated by template generator
# Created: {datetime.datetime.now().strftime('%Y-%m-%d')}
#
# Organization: ${{org_name}}
# Repository: ${{repo_name}}
#

set -e

# Script variables
SCRIPT_DIR="${{SCRIPT_DIR_PLACEHOLDER}}"

# Your script logic here

""".replace("{{SCRIPT_DIR_PLACEHOLDER}}", "$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)")

    def _generate_python_template(self, filename: str) -> str:
        """Generate a Python script template

        Args:
            filename: Name of the file

        Returns:
            Template content
        """
        return f"""#!/usr/bin/env python3
\"\"\"
{filename} - Generated by template generator

Created: {datetime.datetime.now().strftime('%Y-%m-%d')}

Organization: ${{org_name}}
Repository: ${{repo_name}}
\"\"\"

import os
import sys
from typing import Dict, Any, List

def main():
    \"\"\"Main entry point\"\"\"
    print("Hello from {filename}")

if __name__ == "__main__":
    main()
"""

    def _generate_markdown_template(self, filename: str) -> str:
        """Generate a markdown template

        Args:
            filename: Name of the file

        Returns:
            Template content
        """
        title = os.path.splitext(filename)[0].replace('-', ' ').title()
        return f"""# {title}

Generated by template generator on {datetime.datetime.now().strftime('%Y-%m-%d')}.

## Overview

This is a template file for project ${{repo_name}} by ${{org_name}}.

## Usage

TODO: Add usage instructions.

"""

    def _generate_yaml_template(self, filename: str) -> str:
        """Generate a YAML template

        Args:
            filename: Name of the file

        Returns:
            Template content
        """
        return f"""# {filename} - Generated by template generator
# Created: {datetime.datetime.now().strftime('%Y-%m-%d')}
#
# Organization: ${{org_name}}
# Repository: ${{repo_name}}

---
version: '1.0'

# TODO: Add YAML content
"""

    def generate_template(self) -> None:
        """Generate the complete reference template"""
        print(f"Generating template with the following configuration:")
        for key, value in self.config.items():
            if isinstance(value, dict):
                print(f"  {key}:")
                for subkey, subvalue in value.items():
                    print(f"    {subkey}: {subvalue}")
            else:
                print(f"  {key}: {value}")

        template_type = self.config.get("template_type", "kustomize").lower()
        print(f"Using template type: {template_type}")

        # Create directory structure
        self._create_directory_structure()

        # Generate basic files
        self._generate_template("README.md")

        # Generate CI files
        self._generate_template("ci/fly.sh", executable=True)
        self._generate_template("ci/scripts/fly.sh", executable=True)

        # Generate library files
        lib_files = ["utils.sh", "help.sh", "parsing.sh", "commands.sh"]
        for lib_file in lib_files:
            self._generate_template(f"ci/scripts/lib/{lib_file}")

        # Generate test files
        self._generate_template("ci/scripts/tests/README.md")
        self._generate_template("ci/scripts/tests/test-framework.sh")
        self._generate_template("ci/scripts/tests/test_fly_basics.sh", executable=True)
        self._generate_template("ci/scripts/tests/run_tests.sh", executable=True)
        self._generate_template("ci/scripts/tests/test_fly_parameters.sh", executable=True)
        self._generate_template("ci/scripts/tests/test_verbose_param.sh", executable=True)
        self._generate_template("ci/scripts/tests/test_version_param.sh", executable=True)

        # Generate sample pipeline files
        self._generate_template("ci/pipelines/main.yml")
        self._generate_template("ci/pipelines/release.yml")
        self._generate_template("ci/pipelines/set-pipeline.yml")

        # Generate task definitions based on template type
        self._generate_task_categories(template_type)

        # Generate helper scripts
        self._generate_template("scripts/helpers.sh")

        print("\nTemplate generation complete!")
        print(f"Template generated at: {self.output_dir}")

    def _generate_task_categories(self, template_type: str) -> None:
        """Generate task definitions organized by category based on template type

        Args:
            template_type: Type of template to generate (kustomize, helm, cli-tool)
        """
        # Create base task directories
        task_categories = ["common", "testing", "tkgi"]

        # Add template-specific categories
        if template_type == "kustomize":
            task_categories.extend(["k8s"])
            task_prefix = "kustomize"
        elif template_type == "helm":
            task_categories.extend(["helm"])
            task_prefix = "helm"
        elif template_type == "cli-tool":
            task_categories.extend(["cli-tool"])
            task_prefix = "cli-tool"
        else:
            # Default to kustomize
            task_categories.extend(["k8s"])
            task_prefix = "kustomize"

        # Create task category directories
        for category in task_categories:
            category_dir = self.output_dir / f"ci/tasks/{category}"
            category_dir.mkdir(parents=True, exist_ok=True)
            print(f"Created task category directory: {category_dir}")

        # Generate common task: kubectl-apply (for kustomize)
        if template_type == "kustomize" or template_type == "k8s":
            self._generate_kubectl_apply_task()

            # Generate k8s tasks
            self._generate_template("ci/tasks/k8s/create-resources/task.yml")
            self._generate_template("ci/tasks/k8s/create-resources/task.sh", executable=True)
            self._generate_template("ci/tasks/k8s/validate-resources/task.yml")
            self._generate_template("ci/tasks/k8s/validate-resources/task.sh", executable=True)

        # Generate helm tasks
        if template_type == "helm":
            self._generate_template("ci/tasks/helm/helm-lint/task.yml")
            self._generate_template("ci/tasks/helm/helm-lint/task.sh", executable=True)
            self._generate_template("ci/tasks/helm/helm-deploy/task.yml")
            self._generate_template("ci/tasks/helm/helm-deploy/task.sh", executable=True)
            self._generate_template("ci/tasks/helm/helm-test/task.yml")
            self._generate_template("ci/tasks/helm/helm-test/task.sh", executable=True)
            self._generate_template("ci/tasks/helm/helm-delete/task.yml")
            self._generate_template("ci/tasks/helm/helm-delete/task.sh", executable=True)

        # Generate cli-tool tasks
        if template_type == "cli-tool":
            self._generate_template("ci/tasks/cli-tool/download-tool/task.yml")
            self._generate_template("ci/tasks/cli-tool/download-tool/task.sh", executable=True)
            self._generate_template("ci/tasks/cli-tool/install-tool/task.yml")
            self._generate_template("ci/tasks/cli-tool/install-tool/task.sh", executable=True)
            self._generate_template("ci/tasks/cli-tool/configure-tool/task.yml")
            self._generate_template("ci/tasks/cli-tool/configure-tool/task.sh", executable=True)
            self._generate_template("ci/tasks/cli-tool/validate-tool/task.yml")
            self._generate_template("ci/tasks/cli-tool/validate-tool/task.sh", executable=True)

        # Generate common tasks for all templates
        self._generate_template("ci/tasks/common/kustomize/task.yml")
        self._generate_template("ci/tasks/common/kustomize/task.sh", executable=True)

        # Generate testing tasks
        self._generate_template("ci/tasks/testing/run-tests/task.yml")
        self._generate_template("ci/tasks/testing/run-tests/task.sh", executable=True)

        # Generate tkgi login task (common to all templates)
        self._generate_template("ci/tasks/tkgi/tkgi-login/task.yml")
        self._generate_template("ci/tasks/tkgi/tkgi-login/task.sh", executable=True)

    def _generate_kubectl_apply_task(self) -> None:
        """Generate the kubectl-apply task files"""
        task_yml = self.output_dir / "ci/tasks/common/kubectl-apply/task.yml"
        task_sh = self.output_dir / "ci/tasks/common/kubectl-apply/task.sh"

        # Make sure the directory exists
        task_yml.parent.mkdir(parents=True, exist_ok=True)

        # Create the task.yml content
        task_yml_content = """---
platform: linux

inputs:
  - name: repo           # Repository containing task scripts
  - name: pks-config     # PKS/TKGi configuration
  - name: manifests      # Kubernetes manifests to apply

run:
  path: repo/ci/tasks/common/kubectl-apply/task.sh

params:
  # Required parameters
  FOUNDATION: ((foundation))              # Foundation name (e.g., ${default_foundation})
  PKS_PASSWORD: ((pks_api_admin_pw))      # PKS/TKGi password

  # Optional parameters
  KINDS: ((kinds))                        # Comma-separated list of kinds to apply (default: all)
  NAMESPACE_LIMIT: ((namespace_limit))    # Number of namespaces to process (default: 0 = all)
  VERBOSE: ((verbose))                    # Enable verbose output
"""

        # Create the task.sh content
        task_sh_content = """#!/usr/bin/env bash
#
# Task: kubectl-apply
# Description: Applies Kubernetes resources to a cluster
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., ${default_foundation})
#   - PKS_PASSWORD: PKS/TKGi password
#
# Optional Environment Variables:
#   - KINDS: Comma-separated list of kinds to apply (default: all)
#   - NAMESPACE_LIMIT: Number of namespaces to process (default: 0 = all)
#   - VERBOSE: Enable verbose output (default: false)
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get repository root directory
REPO_ROOT="$(cd "${__DIR}/../../../../.." &>/dev/null && pwd)"

# Validate required environment variables
[[ -z "${FOUNDATION}" ]] && { echo "Error: FOUNDATION is required"; exit 1; }
[[ -z "${PKS_PASSWORD}" ]] && { echo "Error: PKS_PASSWORD is required"; exit 1; }

# Set defaults for optional variables
KINDS="${KINDS:-all}"
NAMESPACE_LIMIT="${NAMESPACE_LIMIT:-0}"
VERBOSE="${VERBOSE:-false}"

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

echo "Running kubectl-apply task for foundation: ${FOUNDATION}"
echo "Using kinds: ${KINDS}"
if [[ "${NAMESPACE_LIMIT}" -gt 0 ]]; then
  echo "Limiting to ${NAMESPACE_LIMIT} namespaces"
fi

# Call the repository's apply script with the appropriate arguments
"${REPO_ROOT}/scripts/apply.sh" \\
  -f "${FOUNDATION}" \\
  -p "${PKS_PASSWORD}" \\
  -k "${KINDS}" \\
  -n "${NAMESPACE_LIMIT}" \\
  -m "manifests" \\
  ${VERBOSE} && { echo "Kubectl apply successful"; } || { echo "Kubectl apply failed"; exit 1; }

echo "Task completed successfully"
"""

        # Replace template variables
        task_yml_content = self._render_template(task_yml_content)
        task_sh_content = self._render_template(task_sh_content)

        # Write the files
        with open(task_yml, 'w') as file:
            file.write(task_yml_content)

        with open(task_sh, 'w') as file:
            file.write(task_sh_content)

        # Make task.sh executable
        st = os.stat(task_sh)
        os.chmod(task_sh, st.st_mode | stat.S_IEXEC)

        print(f"Generated kubectl-apply task files in {task_yml.parent}")


def parse_args() -> Dict[str, Any]:
    """Parse command line arguments

    Returns:
        Dictionary of argument values
    """
    parser = argparse.ArgumentParser(
        description="Generate a reference template for CI/CD pipelines"
    )

    parser.add_argument(
        "--output-dir",
        required=True,
        help="Directory where the template should be generated"
    )

    parser.add_argument(
        "--config",
        help="Path to configuration file (YAML or JSON)"
    )

    parser.add_argument(
        "--template-type",
        choices=["kustomize", "helm", "cli-tool"],
        default="kustomize",
        help="Type of template to generate (default: kustomize)"
    )

    parser.add_argument(
        "--org-name",
        help=f"GitHub organization name (default: {DEFAULTS['org_name']})"
    )

    parser.add_argument(
        "--repo-name",
        help=f"Repository name (default: {DEFAULTS['repo_name']})"
    )

    parser.add_argument(
        "--default-branch",
        help=f"Default git branch (default: {DEFAULTS['default_branch']})"
    )

    parser.add_argument(
        "--default-foundation",
        help=f"Default foundation (default: {DEFAULTS['default_foundation']})"
    )

    parser.add_argument(
        "--default-pipeline",
        help=f"Default pipeline name (default: {DEFAULTS['default_pipeline']})"
    )

    args = parser.parse_args()
    config = {}

    # Load configuration from file if provided
    if args.config:
        with open(args.config, 'r') as file:
            if args.config.endswith('.yaml') or args.config.endswith('.yml'):
                config = yaml.safe_load(file)
            elif args.config.endswith('.json'):
                config = json.load(file)
            else:
                print(f"Unsupported config file format: {args.config}")
                sys.exit(1)

    # Override with command line arguments
    if args.output_dir:
        config['output_dir'] = args.output_dir
    if args.template_type:
        config['template_type'] = args.template_type
    if args.org_name:
        config['org_name'] = args.org_name
    if args.repo_name:
        config['repo_name'] = args.repo_name
    if args.default_branch:
        config['default_branch'] = args.default_branch
    if args.default_foundation:
        config['default_foundation'] = args.default_foundation
    if args.default_pipeline:
        config['default_pipeline'] = args.default_pipeline

    return config


def main():
    """Main entry point"""
    config = parse_args()
    generator = TemplateGenerator(config)
    generator.generate_template()


if __name__ == "__main__":
    main()
