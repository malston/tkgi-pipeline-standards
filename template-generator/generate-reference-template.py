#!/usr/bin/env python3
"""
Template Generator for Pipeline Standards

This script generates a standardized reference template for CI/CD pipelines
based on the tkgi-pipeline-standards. It copies template files from the reference
directory and customizes them with the provided configuration.

Usage:
    python generate-reference-template.py --output-dir ./my-project --config ./my-config.yaml
    python generate-reference-template.py --output-dir ./my-project --template-type kustomize --org-name "MyOrg" --repo-name "my-service"

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

class TemplateGenerator:
    """Generator for CI/CD pipeline reference templates"""

    def __init__(self, config: Dict[str, Any]):
        """Initialize the generator with configuration

        Args:
            config: Dictionary containing configuration values
        """
        self.config = {**DEFAULTS, **config}
        script_dir = self._get_script_dir()
        repo_root = script_dir.parent
        self.repo_root = repo_root

        # Set up template directories
        template_type = self.config.get("template_type", "kustomize").lower()
        self.template_type = template_type

        # Primary template directory - specific to the template type
        self.template_dir = repo_root / "reference" / "templates" / template_type

        # Fallback directory - common reference pipeline
        self.fallback_dir = repo_root / "reference" / "pipeline"

        # Validate template directories
        if not self.template_dir.exists():
            print(f"Warning: Template directory {self.template_dir} does not exist.")
            if self.fallback_dir.exists():
                print(f"Will use {self.fallback_dir} as primary source.")
                # Swap template and fallback if template doesn't exist
                self.template_dir, self.fallback_dir = self.fallback_dir, None
            else:
                print("Error: Could not find any template directory. Make sure the templates exist.")
                sys.exit(1)
        elif not self.fallback_dir.exists():
            print(f"Warning: Fallback directory {self.fallback_dir} does not exist.")
            print("Will only use template-specific files.")
            self.fallback_dir = None

        print(f"Using template from: {self.template_dir}")
        if self.fallback_dir:
            print(f"Using fallback source: {self.fallback_dir}")

        self.output_dir = Path(self.config.get("output_dir", "./output"))

        # Ensure the output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def _get_script_dir(self) -> Path:
        """Get the directory where this script is located

        Returns:
            Path to the script directory
        """
        return Path(os.path.dirname(os.path.abspath(__file__)))

    def _render_template(self, content: str) -> str:
        """Replace template variables with configuration values

        Args:
            content: Content of the template file

        Returns:
            Rendered content with variables replaced
        """
        # Replace ${VAR_NAME} style variables
        pattern = r'\$\{([A-Za-z0-9_]+)\}'

        def replace_var(match: re.Match) -> str:
            var_name = match.group(1)
            if var_name.lower() in self.config:
                return str(self.config.get(var_name.lower(), f"${{{var_name}}}"))
            else:
                # Look for a case-insensitive match
                for key in self.config:
                    if key.lower() == var_name.lower():
                        return str(self.config[key])
            return f"${{{var_name}}}"

        return re.sub(pattern, replace_var, content)

    def _is_binary_file(self, file_path: Path) -> bool:
        """Check if a file is binary

        Args:
            file_path: Path to the file

        Returns:
            True if the file is binary, False otherwise
        """
        with open(file_path, 'rb') as file:
            chunk = file.read(1024)
            return b'\0' in chunk

    def _copy_file(self, src_path: Path, dest_path: Path) -> None:
        """Copy a file from source to destination, with variable replacement if it's a text file

        Args:
            src_path: Source file path
            dest_path: Destination file path
        """
        # Make sure the parent directory exists
        dest_path.parent.mkdir(parents=True, exist_ok=True)

        # Check if the file is binary
        if self._is_binary_file(src_path):
            # Copy binary file directly
            shutil.copy2(src_path, dest_path)
        else:
            # Read, render, and write text file
            try:
                with open(src_path, 'r', encoding='utf-8') as file:
                    content = file.read()

                rendered_content = self._render_template(content)

                with open(dest_path, 'w', encoding='utf-8') as file:
                    file.write(rendered_content)

                # Preserve executable permissions
                if os.access(src_path, os.X_OK):
                    mode = os.stat(dest_path).st_mode
                    os.chmod(dest_path, mode | 0o111)  # Add executable bit
            except UnicodeDecodeError:
                # Fall back to binary copy if we can't read as text
                shutil.copy2(src_path, dest_path)

        print(f"Generated {dest_path}")

    def _should_copy_task_directory(self, rel_path: Path) -> bool:
        """Determine if a task directory should be copied based on template type

        Args:
            rel_path: Path relative to the source directory

        Returns:
            True if the directory should be copied, False otherwise
        """
        # If not in the tasks directory, always copy
        if not str(rel_path).startswith("ci/tasks/"):
            return True

        # Handle shallow scripts in the tasks directory
        if len(rel_path.parts) == 2:  # Just "ci/tasks"
            return True

        # Get specific task category
        task_category = rel_path.parts[2] if len(rel_path.parts) > 2 else None

        # Common categories that should always be included
        common_categories = ["common", "tkgi", "testing"]
        if task_category in common_categories:
            return True

        # Template-specific task directories
        template_type_tasks = {
            "kustomize": [],  # kustomize uses tasks in the common directory
            "helm": ["helm", "k8s"],
            "cli-tool": ["cli-tool"]
        }

        # Check if task category is relevant for the current template type
        return task_category in template_type_tasks.get(self.template_type, [])

    def _copy_directory(self, src_dir: Path, dest_dir: Path, relative_path: Path = Path(".")) -> None:
        """Recursively copy a directory with variable replacement

        Args:
            src_dir: Source directory path
            dest_dir: Destination directory path
            relative_path: Path relative to the source directory
        """
        # Create destination directory if it doesn't exist
        current_src_dir = src_dir / relative_path
        current_dest_dir = dest_dir / relative_path

        # Skip task directories that don't apply to the current template type
        if not self._should_copy_task_directory(relative_path):
            return

        current_dest_dir.mkdir(parents=True, exist_ok=True)

        # Copy all files and subdirectories
        for item in current_src_dir.iterdir():
            src_item = current_src_dir / item.name
            dest_item = current_dest_dir / item.name
            rel_item = relative_path / item.name

            if item.is_dir():
                # Recursive copy for directories
                self._copy_directory(src_dir, dest_dir, rel_item)
            else:
                # Check if this file already exists in the output from the primary template
                # Only use fallback files if they don't exist in the output yet
                if self.fallback_dir and current_src_dir.is_relative_to(self.fallback_dir) and dest_item.exists():
                    # Skip this file, it was already copied from the primary template
                    continue

                # Copy and render file
                self._copy_file(src_item, dest_item)

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

        # Display which task categories will be included
        common_categories = ["common", "tkgi", "testing"]
        template_specific_tasks = {
            "kustomize": [],  # kustomize uses tasks in the common directory
            "helm": ["helm", "k8s"],
            "cli-tool": ["cli-tool"]
        }

        template_type_tasks = common_categories + template_specific_tasks.get(self.template_type, [])

        print(f"\nIncluding task categories for {self.template_type} template:")
        for task in template_type_tasks:
            print(f"  - {task}")

        # First copy the template directory to the output directory
        self._copy_directory(self.template_dir, self.output_dir)

        # Then copy any missing files from the fallback directory
        if self.fallback_dir:
            self._copy_directory(self.fallback_dir, self.output_dir)

        # Generate a GUIDE.md file
        guide_md_path = self.output_dir / "GUIDE.md"
        if not guide_md_path.exists():
            guide_content = f"""# GUIDE.md

This file provides guidance to Engineers when working with code in this repository.

## Build/Test Commands
- `./ci/scripts/tests/run_tests.sh` - Run all tests
- `./ci/scripts/tests/test_*.sh` - Run individual test (e.g., test_fly.sh)
- `./ci/scripts/fly.sh -f <foundation> [options] [command]` - Deploy pipeline
- `./ci/scripts/fly.sh validate all` - Validate all pipeline YAML
- `./ci/scripts/fly.sh -f <foundation> -r` - Deploy release pipeline
- `./ci/scripts/fly.sh -f <foundation> --dry-run` - Test without executing

## Code Style Guidelines
- **Shebang**: Use `#!/usr/bin/env bash` for all scripts
- **Strict Mode**: Include `set -o errexit` and `set -o pipefail` at start
- **Script Directory**: Define with `__DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" &>/dev/null && pwd)"`
- **Documentation**: Include function descriptions and usage examples
- **Error Handling**: Fail fast with descriptive messages, use standardized logging functions
- **Parameter Validation**: Check required parameters before execution
- **Testing**: Create test files for critical functions, use test-framework.sh

## Directory Structure
- `ci/pipelines/`: Pipeline definition YAML files
- `ci/scripts/`: Pipeline control scripts with lib/ subdirectory
- `ci/tasks/`: Task definitions organized by category
- `scripts/`: Repository-level scripts
- `tests/`: Test scripts for repository functionality

## Common Patterns
- Script functions should use descriptive names (cmd_set_pipeline, validate_file_exists)
- Use standardized output functions: info, error, success, warning
- Follow command pattern: command + required_params + optional_params + flags
- Structure task folders as category/task-name/task.yml and task.sh
- Use consistent foundation-based configuration

Generated by template-generator on {datetime.datetime.now().strftime('%Y-%m-%d')}
"""
            with open(guide_md_path, 'w') as file:
                file.write(guide_content)
            print(f"Generated {guide_md_path}")

        print("\nTemplate generation complete!")
        print(f"Template generated at: {self.output_dir}")
        print("\nNext steps:")
        print("1. Review the generated files and customize as needed")
        print("2. Add your specific pipeline YAML files to ci/pipelines/")
        print("3. Test the scripts using the included test framework: cd my-new-project/ci/scripts/tests && ./run_tests.sh")

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
