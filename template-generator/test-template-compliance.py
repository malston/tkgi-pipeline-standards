#!/usr/bin/env python3
"""
Template Compliance Testing Script

This script tests that projects created by generate-reference-template.py 
pass validation with validate-template-compliance.py.

Usage:
    python test-template-compliance.py [--verbose]

Author: CI/CD Platform Team
"""

import argparse
import os
import sys
import shutil
import tempfile
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Tuple, Set

# Template types to test
TEMPLATE_TYPES = ["kustomize", "helm", "cli-tool"]

def parse_args() -> Dict[str, Any]:
    """Parse command line arguments

    Returns:
        Dictionary of argument values
    """
    parser = argparse.ArgumentParser(
        description="Test that generated templates pass validation"
    )
    
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    return vars(parser.parse_args())

def run_generator(template_type: str, output_dir: Path, verbose: bool) -> bool:
    """Run the template generator for a specific template type

    Args:
        template_type: Type of template to generate
        output_dir: Directory where the template should be generated
        verbose: Whether to show verbose output

    Returns:
        Boolean indicating success or failure
    """
    cmd = [
        sys.executable,
        "generate-reference-template.py",
        "--output-dir", str(output_dir),
        "--template-type", template_type,
        "--org-name", "TestOrg",
        "--repo-name", f"test-{template_type}"
    ]
    
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE if not verbose else None,
            stderr=subprocess.PIPE if not verbose else None,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error generating {template_type} template: {e}")
        if not verbose:
            print(f"Stdout: {e.stdout}")
            print(f"Stderr: {e.stderr}")
        return False

def run_validator(template_type: str, project_dir: Path, verbose: bool) -> Tuple[bool, List[str]]:
    """Run the template validator on a project directory

    Args:
        template_type: Type of template to validate against
        project_dir: Directory of the project to validate
        verbose: Whether to show verbose output

    Returns:
        Tuple of (success, issues_list)
    """
    cmd = [
        sys.executable,
        "validate-template-compliance.py",
        "--project-dir", str(project_dir),
        "--template-type", template_type
    ]
    
    if verbose:
        cmd.append("--verbose")
    
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        if result.returncode != 0:
            # Validation failed, extract issues
            issues = []
            for line in result.stdout.splitlines():
                if line.strip().startswith(("1.", "2.", "3.")) and ". " in line:
                    issues.append(line.strip())
            return False, issues
        else:
            return True, []
    except subprocess.CalledProcessError as e:
        print(f"Error validating {template_type} template: {e}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")
        return False, ["Validator execution failed"]

def test_template_type(template_type: str, verbose: bool) -> bool:
    """Test a specific template type for compliance

    Args:
        template_type: Type of template to test
        verbose: Whether to show verbose output

    Returns:
        Boolean indicating success or failure
    """
    print(f"\n===== Testing {template_type} template =====")
    
    # Create temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        output_dir = Path(temp_dir) / f"test-{template_type}"
        
        # Run generator
        print(f"Generating {template_type} template in {output_dir}")
        if not run_generator(template_type, output_dir, verbose):
            print(f"❌ Failed to generate {template_type} template")
            return False
            
        # Run validator
        print(f"Validating {template_type} template")
        success, issues = run_validator(template_type, output_dir, verbose)
        
        if success:
            print(f"✅ {template_type} template passed validation")
            return True
        else:
            print(f"❌ {template_type} template failed validation")
            print(f"Issues found:")
            for issue in issues:
                print(f"  - {issue}")
            return False

def main():
    """Main entry point"""
    args = parse_args()
    verbose = args.get("verbose", False)
    
    print("Starting template compliance testing...")
    
    # Test each template type
    results = {}
    for template_type in TEMPLATE_TYPES:
        results[template_type] = test_template_type(template_type, verbose)
    
    # Print summary
    print("\n===== Test Results =====")
    all_passed = True
    for template_type, success in results.items():
        status = "✅ Passed" if success else "❌ Failed"
        print(f"{template_type}: {status}")
        if not success:
            all_passed = False
    
    # Exit with appropriate code
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()