#!/usr/bin/env python3
"""
Template Compliance Validator

This script validates an existing project against the reference template standards,
identifying any areas where the project doesn't conform to the standards.

Usage:
    python validate-template-compliance.py --project-dir /path/to/project --template-type kustomize
    python validate-template-compliance.py --project-dir /path/to/project --template-type helm --verbose

Author: CI/CD Platform Team
"""

import argparse
import os
import sys
import yaml
import json
from pathlib import Path
import re
from typing import Dict, Any, List, Tuple, Set
import fnmatch

# Define file structures for each template type
TEMPLATE_STRUCTURES = {
    "kustomize": {
        "required_dirs": [
            "ci/pipelines",
            "ci/scripts",
            "ci/scripts/lib",
            "ci/scripts/tests",
            "ci/tasks",
            "ci/tasks/common",
            "ci/tasks/testing",
            "ci/tasks/tkgi",
            "ci/tasks/k8s",
            "scripts"
        ],
        "required_files": [
            "ci/fly.sh",
            "ci/pipelines/main.yml",
            "ci/pipelines/release.yml",
            "ci/pipelines/set-pipeline.yml",
            "ci/scripts/fly.sh",
            "ci/scripts/lib/commands.sh",
            "ci/scripts/lib/help.sh",
            "ci/scripts/lib/parsing.sh",
            "ci/scripts/lib/utils.sh",
            "ci/scripts/tests/run_tests.sh",
            "ci/scripts/tests/test-framework.sh",
            "README.md"
        ],
        "critical_task_dirs": [
            "ci/tasks/common/kubectl-apply",
            "ci/tasks/tkgi/tkgi-login"
        ],
        "script_patterns": {
            "shebang": r"^#!/usr/bin/env bash$",
            "strict_mode": r"set -o errexit.*set -o pipefail",
            "script_dir": r"[A-Za-z_]+(DIR|_DIR)=.*\$\(cd.*\$\{BASH_SOURCE\[0\]\}.*pwd\)"
        },
        # Default relaxed rules - nothing relaxed by default
        "relaxed_rules": {}
    },
    "helm": {
        "required_dirs": [
            "ci/pipelines",
            "ci/scripts",
            "ci/scripts/lib",
            "ci/scripts/tests",
            "ci/tasks",
            "ci/tasks/common",
            "ci/tasks/testing",
            "ci/tasks/tkgi",
            "ci/tasks/helm",
            "ci/tasks/k8s",
            "scripts"
        ],
        "required_files": [
            "ci/fly.sh",
            "ci/pipelines/main.yml",
            "ci/pipelines/release.yml",
            "ci/scripts/fly.sh",
            "ci/scripts/lib/commands.sh",
            "ci/scripts/lib/help.sh",
            "ci/scripts/lib/parsing.sh",
            "ci/scripts/lib/utils.sh",
            "ci/scripts/tests/run_tests.sh",
            "ci/scripts/tests/test-framework.sh",
            "README.md"
        ],
        "critical_task_dirs": [
            "ci/tasks/helm/helm-deploy",
            "ci/tasks/tkgi/tkgi-login"
        ],
        "script_patterns": {
            "shebang": r"^#!/usr/bin/env bash$",
            "strict_mode": r"set -o errexit.*set -o pipefail",
            "script_dir": r"[A-Za-z_]+(DIR|_DIR)=.*\$\(cd.*\$\{BASH_SOURCE\[0\]\}.*pwd\)"
        },
        # Default relaxed rules - nothing relaxed by default
        "relaxed_rules": {}
    },
    "cli-tool": {
        "required_dirs": [
            "ci/pipelines",
            "ci/scripts",
            "ci/scripts/lib",
            "ci/scripts/tests",
            "ci/tasks",
            "ci/tasks/common",
            "ci/tasks/testing",
            "ci/tasks/tkgi",
            "ci/tasks/cli-tool",
            "scripts"
        ],
        "required_files": [
            "ci/fly.sh",
            "ci/pipelines/main.yml",
            "ci/pipelines/release.yml",
            "ci/scripts/fly.sh",
            "ci/scripts/lib/commands.sh",
            "ci/scripts/lib/help.sh",
            "ci/scripts/lib/parsing.sh",
            "ci/scripts/lib/utils.sh",
            "ci/scripts/tests/run_tests.sh",
            "ci/scripts/tests/test-framework.sh",
            "README.md"
        ],
        "critical_task_dirs": [
            "ci/tasks/cli-tool/download-tool",
            "ci/tasks/cli-tool/install-tool",
            "ci/tasks/tkgi/tkgi-login"
        ],
        "script_patterns": {
            "shebang": r"^#!/usr/bin/env bash$",
            "strict_mode": r"set -o errexit.*set -o pipefail",
            "script_dir": r"[A-Za-z_]+(DIR|_DIR)=.*\$\(cd.*\$\{BASH_SOURCE\[0\]\}.*pwd\)"
        },
        # Default relaxed rules - nothing relaxed by default
        "relaxed_rules": {}
    }
}

# Define expected fly.sh commands
FLY_COMMANDS = ["set", "unpause", "destroy", "validate", "release", "set-pipeline"]

# Define expected fly.sh options
FLY_OPTIONS = [
    "-f, --foundation",
    "-t, --target",
    "-e, --environment",
    "-b, --branch",
    "-c, --config-branch",
    "-d, --params-branch",
    "-p, --pipeline",
    "-o, --github-org",
    "-v, --version",
    "--dry-run",
    "--verbose",
    "--timer",
    "-h, --help"
]

class TemplateValidator:
    """Validator for CI/CD template compliance"""

    def __init__(self, project_dir: str, template_type: str, verbose: bool = False, 
                 relax_rules_file: str = None, skip_dirs: List[str] = None, 
                 skip_files: List[str] = None, skip_tasks: List[str] = None):
        """Initialize the validator

        Args:
            project_dir: Path to the project directory to validate
            template_type: Type of template to validate against (kustomize, helm, cli-tool)
            verbose: Whether to print verbose output
            relax_rules_file: Path to a JSON or YAML file containing rules to relax
            skip_dirs: List of required directories to skip checking
            skip_files: List of required files to skip checking
            skip_tasks: List of critical task directories to skip checking
        """
        self.project_dir = Path(project_dir)
        self.template_type = template_type.lower()
        self.verbose = verbose
        self.skip_dirs = skip_dirs or []
        self.skip_files = skip_files or []
        self.skip_tasks = skip_tasks or []

        if not self.project_dir.exists():
            raise ValueError(f"Project directory {project_dir} does not exist")

        if self.template_type not in TEMPLATE_STRUCTURES:
            raise ValueError(f"Unknown template type: {template_type}, must be one of: {', '.join(TEMPLATE_STRUCTURES.keys())}")

        # Clone the structure to avoid modifying the original
        self.structure = {k: v.copy() if isinstance(v, dict) else v.copy() if hasattr(v, 'copy') else v 
                          for k, v in TEMPLATE_STRUCTURES[self.template_type].items()}
        
        # Apply relaxed rules if specified
        if relax_rules_file:
            self._load_relaxed_rules(relax_rules_file)
            
        # Apply skip options
        self._apply_skip_options()
            
        self.issues = []

    def _load_relaxed_rules(self, rules_file: str) -> None:
        """Load relaxed rules from a file

        Args:
            rules_file: Path to a JSON or YAML file containing rules to relax
        """
        rules_path = Path(rules_file)
        if not rules_path.exists():
            raise ValueError(f"Relaxed rules file {rules_file} does not exist")
            
        try:
            with open(rules_path, "r") as f:
                if rules_path.suffix.lower() in ['.yaml', '.yml']:
                    relaxed_rules = yaml.safe_load(f)
                elif rules_path.suffix.lower() == '.json':
                    relaxed_rules = json.load(f)
                else:
                    raise ValueError(f"Unsupported file format: {rules_path.suffix}")
                    
            # Merge relaxed rules with default rules
            if relaxed_rules:
                self._log(f"Applying relaxed rules from {rules_file}")
                
                for rule_type, rules in relaxed_rules.items():
                    if rule_type == 'skip_dirs' and isinstance(rules, list):
                        self.skip_dirs.extend(rules)
                    elif rule_type == 'skip_files' and isinstance(rules, list):
                        self.skip_files.extend(rules)
                    elif rule_type == 'skip_tasks' and isinstance(rules, list):
                        self.skip_tasks.extend(rules)
                    else:
                        self._log(f"Unknown rule type: {rule_type}")
                        
        except Exception as e:
            raise ValueError(f"Error loading relaxed rules: {str(e)}")
            
    def _apply_skip_options(self) -> None:
        """Apply skip options to the structure"""
        # Remove skipped directories from required_dirs
        for dir_path in self.skip_dirs:
            if dir_path in self.structure["required_dirs"]:
                self.structure["required_dirs"].remove(dir_path)
                self._log(f"Skipping required directory check: {dir_path}")
                
        # Remove skipped files from required_files
        for file_path in self.skip_files:
            if file_path in self.structure["required_files"]:
                self.structure["required_files"].remove(file_path)
                self._log(f"Skipping required file check: {file_path}")
            else:
                # Support for glob patterns in skip_files
                for required_file in list(self.structure["required_files"]):
                    if fnmatch.fnmatch(required_file, file_path):
                        self.structure["required_files"].remove(required_file)
                        self._log(f"Skipping required file check (pattern match): {required_file}")
                
        # Remove skipped tasks from critical_task_dirs
        for task_path in self.skip_tasks:
            if task_path in self.structure["critical_task_dirs"]:
                self.structure["critical_task_dirs"].remove(task_path)
                self._log(f"Skipping critical task check: {task_path}")
            else:
                # Support for glob patterns in skip_tasks
                for critical_task in list(self.structure["critical_task_dirs"]):
                    if fnmatch.fnmatch(critical_task, task_path):
                        self.structure["critical_task_dirs"].remove(critical_task)
                        self._log(f"Skipping critical task check (pattern match): {critical_task}")

    def _log(self, message: str) -> None:
        """Log a message if verbose mode is enabled

        Args:
            message: Message to log
        """
        if self.verbose:
            print(message)

    def validate_directory_structure(self) -> None:
        """Validate the directory structure of the project"""
        self._log("Validating directory structure...")

        # Check required directories
        for dir_path in self.structure["required_dirs"]:
            full_path = self.project_dir / dir_path
            if not full_path.exists() or not full_path.is_dir():
                self.issues.append(f"Missing required directory: {dir_path}")

        # Check task directories - each task should have task.yml and task.sh
        # But only validate directories that actually exist
        task_dirs = list(self.project_dir.glob("ci/tasks/**/*"))
        for task_dir in task_dirs:
            # Only check leaf directories (task directories)
            if task_dir.is_dir() and not task_dir.name.startswith(".") and task_dir.name not in ["common", "testing", "tkgi", "k8s", "helm", "cli-tool"]:
                # Skip if the directory doesn't have at least one task file (may be a category directory)
                any_task_file = list(task_dir.glob("task.*"))
                if not any_task_file:
                    continue

                task_yml = task_dir / "task.yml"
                task_sh = task_dir / "task.sh"

                if not task_yml.exists():
                    self.issues.append(f"Task directory {task_dir.relative_to(self.project_dir)} missing task.yml")

                if not task_sh.exists():
                    self.issues.append(f"Task directory {task_dir.relative_to(self.project_dir)} missing task.sh")

        # Check critical task directories
        for task_dir in self.structure["critical_task_dirs"]:
            full_path = self.project_dir / task_dir
            if not full_path.exists() or not full_path.is_dir():
                self.issues.append(f"Missing critical task directory: {task_dir}")
            else:
                # Check if task.yml and task.sh exist
                if not (full_path / "task.yml").exists():
                    self.issues.append(f"Critical task {task_dir} missing task.yml")
                if not (full_path / "task.sh").exists():
                    self.issues.append(f"Critical task {task_dir} missing task.sh")

    def validate_required_files(self) -> None:
        """Validate the presence of required files"""
        self._log("Validating required files...")

        for file_path in self.structure["required_files"]:
            full_path = self.project_dir / file_path
            if not full_path.exists() or not full_path.is_file():
                self.issues.append(f"Missing required file: {file_path}")

    def validate_script_standards(self) -> None:
        """Validate that scripts follow the required standards"""
        self._log("Validating script standards...")

        # Find all shell scripts
        sh_files = []
        for ext in ["*.sh"]:
            sh_files.extend(self.project_dir.glob(f"**/{ext}"))

        for sh_file in sh_files:
            # Skip files in .git directory
            if ".git" in str(sh_file):
                continue

            try:
                with open(sh_file, "r") as f:
                    content = f.read()

                # Check if file is sourced (doesn't have a shebang)
                # Files meant to be sourced don't need to have strict mode or script directory
                is_sourced_file = not re.search(r'^#!/', content, re.MULTILINE)

                # Check path to detect lib files that are meant to be sourced
                is_lib_file = "lib/" in str(sh_file)

                # Check if file is a mock file (used for testing) or in tests directory
                is_mock_file = "mock" in sh_file.name.lower() or re.search(r'mock.*function', content, re.IGNORECASE)
                is_test_file = "/tests/" in str(sh_file) or "test_" in sh_file.name.lower()

                # Check shebang, but skip for files that are meant to be sourced
                if not is_sourced_file and not re.search(self.structure["script_patterns"]["shebang"], content, re.MULTILINE):
                    self.issues.append(f"Script {sh_file.relative_to(self.project_dir)} missing proper shebang (#!/usr/bin/env bash)")

                # Check strict mode, but skip for files that are meant to be sourced, mocks, or test files
                if not is_sourced_file and not is_lib_file and not is_mock_file and not is_test_file and not re.search(self.structure["script_patterns"]["strict_mode"], content, re.MULTILINE | re.DOTALL):
                    self.issues.append(f"Script {sh_file.relative_to(self.project_dir)} missing strict mode (set -o errexit and set -o pipefail)")

                # Check script directory definition, but skip for files that are meant to be sourced, mocks, or test files
                script_dir_pattern = r'(DIR|[A-Za-z_]+DIR|[A-Za-z_]+_DIR|SCRIPT_DIR|CURRENT_DIR)\s*=.*\$\(cd.*dirname.*BASH_SOURCE.*pwd\)'
                if not is_sourced_file and not is_lib_file and not is_mock_file and not is_test_file and not re.search(script_dir_pattern, content, re.MULTILINE | re.DOTALL):
                    self.issues.append(f"Script {sh_file.relative_to(self.project_dir)} missing script directory definition")
            except Exception as e:
                self.issues.append(f"Error reading script {sh_file.relative_to(self.project_dir)}: {str(e)}")

    def validate_fly_script(self) -> None:
        """Validate the fly.sh script for required commands and options"""
        self._log("Validating fly.sh script...")

        fly_args = self.project_dir / "ci/scripts/lib/parsing.sh"
        if not fly_args.exists():
            self.issues.append("Missing ci/scripts/lib/parsing.sh")
            return

        try:
            with open(fly_args, "r") as f:
                content = f.read()

            # Check for required commands
            missing_commands = []
            for cmd in FLY_COMMANDS:
                # Look for evidence of command implementation
                if not re.search(rf"(cmd_{cmd}|command.*{cmd}|case.*{cmd})", content, re.MULTILINE | re.DOTALL):
                    missing_commands.append(cmd)

            if missing_commands:
                self.issues.append(f"fly.sh missing required commands: {', '.join(missing_commands)}")

            # Check for required options
            missing_options = []
            for opt in FLY_OPTIONS:
                # Extract just the short and long option names
                opt_parts = opt.split(",")
                short_opt = opt_parts[0].strip()

                # Look for evidence of option parsing - more flexible pattern
                if not re.search(rf"{short_opt}\)|{short_opt}[ \"#]|\"{short_opt.replace('-', '')}", content, re.MULTILINE):
                    missing_options.append(opt)

            if missing_options:
                self.issues.append(f"fly.sh missing required options: {', '.join(missing_options)}")

        except Exception as e:
            self.issues.append(f"Error validating fly.sh script: {str(e)}")

    def validate_pipeline_files(self) -> None:
        """Validate pipeline YAML files for required structure"""
        self._log("Validating pipeline files...")

        pipeline_dir = self.project_dir / "ci/pipelines"
        if not pipeline_dir.exists():
            self.issues.append("Missing ci/pipelines directory")
            return

        main_pipeline = pipeline_dir / "main.yml"
        if not main_pipeline.exists():
            self.issues.append("Missing ci/pipelines/main.yml file")
        else:
            try:
                with open(main_pipeline, "r") as f:
                    pipeline = yaml.safe_load(f)

                # Make sure pipeline is not None (empty file)
                if pipeline is None:
                    self.issues.append("main.yml pipeline is empty")
                    return

                # Check for groups to organize jobs
                if "groups" not in pipeline:
                    self.issues.append("main.yml pipeline missing 'groups' section")

                # Check for jobs
                if "jobs" not in pipeline:
                    self.issues.append("main.yml pipeline missing 'jobs' section")

                # Check for resources
                if "resources" not in pipeline:
                    self.issues.append("main.yml pipeline missing 'resources' section")

            except Exception as e:
                self.issues.append(f"Error validating main.yml: {str(e)}")

        # Check that all task references in pipelines refer to task.yml files
        yaml_files = list(pipeline_dir.glob("*.yml"))
        for yaml_file in yaml_files:
            try:
                with open(yaml_file, "r") as f:
                    content = f.read()

                # Check for inline task definitions
                inline_tasks = re.findall(r"task:.*\n.*platform: linux", content, re.MULTILINE)
                if inline_tasks:
                    self.issues.append(f"{yaml_file.name} contains {len(inline_tasks)} inline task definitions instead of referencing task.yml files")

            except Exception as e:
                self.issues.append(f"Error checking task references in {yaml_file.name}: {str(e)}")

    def validate_task_files(self) -> None:
        """Validate task.yml files for required structure"""
        self._log("Validating task files...")

        task_ymls = list(self.project_dir.glob("ci/tasks/**/task.yml"))
        for task_yml in task_ymls:
            try:
                with open(task_yml, "r") as f:
                    task = yaml.safe_load(f)

                # Check for platform: linux
                if task.get("platform") != "linux":
                    self.issues.append(f"{task_yml.relative_to(self.project_dir)} missing or incorrect 'platform: linux'")

                # Check for inputs
                if "inputs" not in task:
                    self.issues.append(f"{task_yml.relative_to(self.project_dir)} missing 'inputs' section")

                # Check for run section
                if "run" not in task:
                    self.issues.append(f"{task_yml.relative_to(self.project_dir)} missing 'run' section")
                else:
                    # Check that run.path points to task.sh in the same directory
                    run_path = task["run"].get("path", "")
                    if not run_path.endswith(f"{task_yml.parent.name}/task.sh"):
                        self.issues.append(f"{task_yml.relative_to(self.project_dir)} run.path doesn't point to task.sh in the correct location")

            except Exception as e:
                self.issues.append(f"Error validating {task_yml.relative_to(self.project_dir)}: {str(e)}")

    def validate_test_framework(self) -> None:
        """Validate the test framework implementation"""
        self._log("Validating test framework...")

        test_framework = self.project_dir / "ci/scripts/tests/test-framework.sh"
        run_tests = self.project_dir / "ci/scripts/tests/run_tests.sh"

        if not test_framework.exists():
            self.issues.append("Missing test framework (ci/scripts/tests/test-framework.sh)")

        if not run_tests.exists():
            self.issues.append("Missing test runner (ci/scripts/tests/run_tests.sh)")

        # Check for test files
        test_files = list(self.project_dir.glob("ci/scripts/tests/test_*.sh"))
        if not test_files:
            self.issues.append("No test files found (ci/scripts/tests/test_*.sh)")

        # Check that test files use the test framework
        for test_file in test_files:
            try:
                with open(test_file, "r") as f:
                    content = f.read()

                if not re.search(r"source.*test-framework\.sh", content, re.MULTILINE):
                    self.issues.append(f"Test file {test_file.relative_to(self.project_dir)} doesn't source the test framework")

                # Check for test functions and assertions
                if not re.search(r"function test_", content, re.MULTILINE):
                    self.issues.append(f"Test file {test_file.relative_to(self.project_dir)} doesn't contain test functions")

                if not re.search(r"assert_", content, re.MULTILINE):
                    self.issues.append(f"Test file {test_file.relative_to(self.project_dir)} doesn't contain assertions")

            except Exception as e:
                self.issues.append(f"Error checking test file {test_file.relative_to(self.project_dir)}: {str(e)}")

    def validate(self) -> List[str]:
        """Run all validation checks and return the list of issues found

        Returns:
            List of issues found during validation
        """
        self._log(f"Validating project at {self.project_dir} against {self.template_type} template standards...")

        self.validate_directory_structure()
        self.validate_required_files()
        self.validate_script_standards()
        self.validate_fly_script()
        self.validate_pipeline_files()
        self.validate_task_files()
        # self.validate_test_framework()

        return self.issues

    def print_report(self) -> None:
        """Print a compliance report"""
        if not self.issues:
            print(f"\n✅ Project {self.project_dir} is compliant with {self.template_type} template standards!")
            return

        print(f"\n❌ Found {len(self.issues)} compliance issues:")

        # Group issues by category
        categories = {
            "directory": [],
            "file": [],
            "script": [],
            "fly": [],
            "pipeline": [],
            "task": [],
            "test": []
        }

        for issue in self.issues:
            if "directory" in issue.lower():
                categories["directory"].append(issue)
            elif "file" in issue.lower():
                categories["file"].append(issue)
            elif "script" in issue.lower() and "fly.sh" not in issue.lower():
                categories["script"].append(issue)
            elif "fly.sh" in issue.lower():
                categories["fly"].append(issue)
            elif "pipeline" in issue.lower() or ".yml" in issue.lower():
                categories["pipeline"].append(issue)
            elif "task" in issue.lower():
                categories["task"].append(issue)
            elif "test" in issue.lower():
                categories["test"].append(issue)
            else:
                # Default to script category
                categories["script"].append(issue)

        # Print issues by category
        for category, issues in categories.items():
            if issues:
                print(f"\n## {category.upper()} ISSUES ({len(issues)})")
                for idx, issue in enumerate(issues, 1):
                    print(f"{idx}. {issue}")

        # Print summary suggestion
        print("\n## NEXT STEPS")
        print("Consider using the template generator to create a reference project and compare with your existing project:")
        print(f"python generate-reference-template.py --output-dir ./reference-{self.template_type} --template-type {self.template_type}")
        print("\nThen use a diff tool to compare and identify the specific changes needed:")
        print(f"diff -r --exclude='.git' ./reference/templates/{self.template_type} {self.project_dir}")

def parse_args() -> Dict[str, Any]:
    """Parse command line arguments

    Returns:
        Dictionary of argument values
    """
    parser = argparse.ArgumentParser(
        description="Validate a project against reference template standards"
    )

    parser.add_argument(
        "--project-dir",
        required=True,
        help="Directory of the project to validate"
    )

    parser.add_argument(
        "--template-type",
        choices=["kustomize", "helm", "cli-tool"],
        default="kustomize",
        help="Type of template to validate against (default: kustomize)"
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print verbose validation information"
    )
    
    parser.add_argument(
        "--relax-rules",
        help="Path to a JSON or YAML file containing rules to relax"
    )
    
    parser.add_argument(
        "--skip-dirs",
        help="Comma-separated list of required directories to skip checking"
    )
    
    parser.add_argument(
        "--skip-files",
        help="Comma-separated list of required files to skip checking"
    )
    
    parser.add_argument(
        "--skip-tasks",
        help="Comma-separated list of critical task directories to skip checking"
    )

    args = parser.parse_args()

    # Convert to dictionary for return
    return {
        "project_dir": args.project_dir,
        "template_type": args.template_type,
        "verbose": args.verbose,
        "relax_rules": args.relax_rules,
        "skip_dirs": args.skip_dirs.split(",") if args.skip_dirs else [],
        "skip_files": args.skip_files.split(",") if args.skip_files else [],
        "skip_tasks": args.skip_tasks.split(",") if args.skip_tasks else []
    }

def main():
    """Main entry point"""
    args = parse_args()

    try:
        validator = TemplateValidator(
            project_dir=args["project_dir"],
            template_type=args["template_type"],
            verbose=args["verbose"],
            relax_rules_file=args["relax_rules"],
            skip_dirs=args["skip_dirs"],
            skip_files=args["skip_files"],
            skip_tasks=args["skip_tasks"]
        )

        issues = validator.validate()
        validator.print_report()

        # Exit with non-zero code if issues were found
        if issues:
            sys.exit(1)

    except Exception as e:
        print(f"Error during validation: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()