#!/usr/bin/env python3
"""
Test that task filtering works correctly based on template type.

This script generates templates for each template type and checks that
only the appropriate task directories are included in each template.

Usage:
    python test-task-filtering.py
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path
import tempfile

def run_command(cmd):
    """Run a command and return its output"""
    try:
        result = subprocess.run(cmd, 
                               check=True, 
                               shell=True, 
                               stdout=subprocess.PIPE, 
                               stderr=subprocess.PIPE, 
                               universal_newlines=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {cmd}")
        print(f"Error output:\n{e.stderr}")
        sys.exit(1)

def check_task_directories(template_dir, template_type):
    """Check that only the appropriate task directories exist"""
    # Common tasks that should be in all templates
    common_tasks = ["common", "tkgi", "testing"]
    
    # Template-specific tasks - note that some template-specific tasks are in the common directory
    template_specific_tasks = {
        "kustomize": ["k8s"],
        "helm": ["helm", "k8s"],
        "cli-tool": ["cli-tool"]
    }
    
    # Get all task category directories
    task_dir = Path(template_dir) / "ci" / "tasks"
    if not task_dir.exists():
        print(f"ERROR: Task directory not found at {task_dir}")
        return False
    
    task_categories = [d.name for d in task_dir.iterdir() if d.is_dir()]
    
    # Check that all expected task categories exist
    expected_categories = common_tasks + template_specific_tasks.get(template_type, [])
    missing_categories = [c for c in expected_categories if c not in task_categories]
    if missing_categories:
        print(f"ERROR: Missing expected task categories: {missing_categories}")
        return False
    
    # Check that no unexpected task categories exist
    unexpected_categories = [c for c in task_categories if c not in expected_categories]
    if unexpected_categories:
        print(f"ERROR: Found unexpected task categories: {unexpected_categories}")
        return False
    
    # Create a set of all template tasks that don't overlap
    non_overlapping_tasks = {}
    for t, tasks in template_specific_tasks.items():
        for task in tasks:
            if task not in non_overlapping_tasks:
                non_overlapping_tasks[task] = []
            non_overlapping_tasks[task].append(t)
    
    # Find task categories that don't belong to this template type
    wrong_template_categories = []
    for c in task_categories:
        # Skip common task categories
        if c in common_tasks:
            continue
        # Check if category is in template_specific_tasks for this template
        if c not in template_specific_tasks.get(template_type, []):
            # Check if category exists but is exclusive to other template types
            if c in non_overlapping_tasks and template_type not in non_overlapping_tasks[c]:
                wrong_template_categories.append(c)
    
    if wrong_template_categories:
        print(f"ERROR: Found task categories exclusive to other template types: {wrong_template_categories}")
        return False
    
    return True

def main():
    # Get the script directory
    script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    repo_root = script_dir.parent
    
    # Create virtual environment if needed and activate it
    venv_dir = repo_root / ".venv"
    if not venv_dir.exists():
        print("Creating virtual environment...")
        run_command(f"cd {repo_root} && python3 -m venv .venv")
    
    # Install required dependencies
    print("Installing dependencies...")
    run_command(f"cd {repo_root} && source .venv/bin/activate && pip install pyyaml")
    
    # Test each template type
    template_types = ["kustomize", "helm", "cli-tool"]
    failures = []
    
    for template_type in template_types:
        print(f"\nTesting {template_type} template...")
        
        # Create a temporary directory for the template
        with tempfile.TemporaryDirectory() as temp_dir:
            # Generate the template
            cmd = f"cd {repo_root} && source .venv/bin/activate && "
            cmd += f"python {script_dir}/generate-reference-template.py "
            cmd += f"--output-dir {temp_dir} --template-type {template_type} "
            cmd += f"--org-name TestOrg --repo-name test-{template_type}"
            
            print(f"Generating template in {temp_dir}...")
            run_command(cmd)
            
            # Check the task directories
            print(f"Checking task directories...")
            if check_task_directories(temp_dir, template_type):
                print(f"✅ {template_type} template passed task filtering test")
            else:
                print(f"❌ {template_type} template failed task filtering test")
                failures.append(template_type)
    
    # Print summary
    print("\n=== Test Summary ===")
    if failures:
        print(f"❌ {len(failures)} template(s) failed: {', '.join(failures)}")
        return 1
    else:
        print(f"✅ All {len(template_types)} templates passed task filtering tests")
        return 0

if __name__ == "__main__":
    sys.exit(main())