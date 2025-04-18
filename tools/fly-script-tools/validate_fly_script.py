#!/usr/bin/env python3
"""
validate_fly_script.py - Validate fly.sh script compliance with standards

This tool checks if a fly.sh script and its associated files conform to the
tkgi-pipeline-standards.

Usage:
    python3 validate_fly_script.py -d /path/to/scripts/dir [-o report.json] [-v]

Author: Platform Engineering Team
"""

import argparse
import os
import re
import json
import sys
from pathlib import Path

# Define standard requirements
REQUIRED_DIRS = ["lib", "tests"]
REQUIRED_FILES = {
    "fly.sh": {"executable": True},
    "lib/commands.sh": {"executable": True},
    "lib/help.sh": {"executable": True},
    "lib/parsing.sh": {"executable": True},
    "lib/utils.sh": {"executable": True},
    "tests/run_tests.sh": {"executable": True}
}
REQUIRED_COMMANDS = ["set", "unpause", "destroy", "validate", "release", "set-pipeline"]
REQUIRED_OPTIONS = [
    "-f", "--foundation", "-t", "--target", "-e", "--environment",
    "-b", "--branch", "-c", "--config-branch", "-p", "--pipeline",
    "-o", "--github-org", "-v", "--version", "--dry-run", "--verbose"
]

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Validate fly.sh script conformance")
    parser.add_argument("-d", "--directory", required=True, 
                        help="Directory containing the fly.sh script")
    parser.add_argument("-o", "--output", help="Output file for validation report")
    parser.add_argument("-v", "--verbose", action="store_true", 
                        help="Show detailed validation results")
    return parser.parse_args()

def check_structure(directory):
    """Check if directory has the required file structure"""
    results = {"structure": {"directories": {}, "files": {}}}
    
    # Check directories
    for dirname in REQUIRED_DIRS:
        path = os.path.join(directory, dirname)
        results["structure"]["directories"][dirname] = os.path.isdir(path)
    
    # Check files
    for filename, requirements in REQUIRED_FILES.items():
        path = os.path.join(directory, filename)
        file_exists = os.path.isfile(path)
        executable = os.access(path, os.X_OK) if file_exists else False
        
        results["structure"]["files"][filename] = {
            "exists": file_exists,
            "executable": executable if requirements.get("executable", False) else None
        }
    
    return results

def extract_commands(script_path):
    """Extract commands implemented in the script"""
    results = {"commands": {}}
    
    # Initialize all required commands as missing
    for cmd in REQUIRED_COMMANDS:
        results["commands"][cmd] = False
    
    if not os.path.isfile(script_path):
        return results
    
    # Look for command handlers in files
    commands_file = os.path.join(os.path.dirname(script_path), "lib/commands.sh")
    files_to_check = [script_path]
    if os.path.isfile(commands_file):
        files_to_check.append(commands_file)
    
    cmd_patterns = [
        re.compile(r'case\s+.*\s+in(.*?)esac', re.DOTALL),  # Case statement
        re.compile(r'function\s+cmd_(\w+)\s*\(\)')  # Function declarations
    ]
    
    for file_path in files_to_check:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                
                # Check for case statements
                case_blocks = cmd_patterns[0].findall(content)
                for block in case_blocks:
                    for cmd in REQUIRED_COMMANDS:
                        if re.search(fr'\b{cmd}\s*\)', block):
                            results["commands"][cmd] = True
                
                # Check for function declarations
                for cmd in REQUIRED_COMMANDS:
                    if re.search(fr'function\s+cmd_{cmd}\s*\(\)', content):
                        results["commands"][cmd] = True
        except Exception as e:
            print(f"Error reading file {file_path}: {e}")
    
    return results

def extract_options(script_path):
    """Extract command-line options implemented in the script"""
    results = {"options": {}}
    
    # Initialize all required options as missing
    for opt in REQUIRED_OPTIONS:
        results["options"][opt] = False
    
    if not os.path.isfile(script_path):
        return results
    
    # Look for option handling in files
    parsing_file = os.path.join(os.path.dirname(script_path), "lib/parsing.sh")
    files_to_check = [script_path]
    if os.path.isfile(parsing_file):
        files_to_check.append(parsing_file)
    
    for file_path in files_to_check:
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                for opt in REQUIRED_OPTIONS:
                    # Look for the option in a case statement or getopt
                    if re.search(fr'{re.escape(opt)}\s*\)', content) or re.search(fr'{re.escape(opt)}[:|]', content):
                        results["options"][opt] = True
        except Exception as e:
            print(f"Error reading file {file_path}: {e}")
    
    return results

def check_content_requirements(directory):
    """Check that scripts follow content requirements"""
    results = {}
    
    # Check for strict mode
    fly_path = os.path.join(directory, "fly.sh")
    if os.path.isfile(fly_path):
        try:
            with open(fly_path, 'r') as f:
                content = f.read()
                results["strict_mode"] = {
                    "errexit": "set -o errexit" in content,
                    "pipefail": "set -o pipefail" in content
                }
        except Exception as e:
            print(f"Error reading file {fly_path}: {e}")
            results["strict_mode"] = {"errexit": False, "pipefail": False}
    else:
        results["strict_mode"] = {"errexit": False, "pipefail": False}
    
    # Check for help function
    help_file = os.path.join(directory, "lib/help.sh")
    if os.path.isfile(help_file):
        try:
            with open(help_file, 'r') as f:
                content = f.read()
                results["help_function"] = re.search(r'function\s+(show_usage|usage|help)\s*\(\)', content) is not None
        except Exception as e:
            print(f"Error reading file {help_file}: {e}")
            results["help_function"] = False
    else:
        results["help_function"] = False
    
    return results

def calculate_compliance(structure_results, command_results, option_results, content_results):
    """Calculate compliance percentage and level"""
    total_checks = 0
    passed_checks = 0
    
    # Count directory checks
    for dirname, exists in structure_results["structure"]["directories"].items():
        total_checks += 1
        if exists:
            passed_checks += 1
    
    # Count file checks
    for filename, checks in structure_results["structure"]["files"].items():
        total_checks += 1
        if checks["exists"]:
            passed_checks += 1
            
            # Check executable if required
            if checks["executable"] is not None:
                total_checks += 1
                if checks["executable"]:
                    passed_checks += 1
    
    # Count command checks
    for cmd, present in command_results["commands"].items():
        total_checks += 1
        if present:
            passed_checks += 1
    
    # Count option checks
    for opt, present in option_results["options"].items():
        total_checks += 1
        if present:
            passed_checks += 1
    
    # Count content checks
    if "strict_mode" in content_results:
        for mode, enabled in content_results["strict_mode"].items():
            total_checks += 1
            if enabled:
                passed_checks += 1
    
    total_checks += 1  # help function
    if content_results.get("help_function", False):
        passed_checks += 1
    
    # Calculate percentage
    compliance_percentage = (passed_checks / total_checks) * 100 if total_checks > 0 else 0
    compliance_level = "High" if compliance_percentage >= 90 else "Medium" if compliance_percentage >= 70 else "Low"
    
    return {
        "compliance_percentage": compliance_percentage,
        "compliance_level": compliance_level,
        "passed_checks": passed_checks,
        "total_checks": total_checks,
        "compliant": compliance_percentage >= 90
    }

def main():
    args = parse_args()
    
    # Check if directory exists
    if not os.path.isdir(args.directory):
        print(f"Error: Directory {args.directory} does not exist")
        sys.exit(1)
    
    # Run checks
    structure_results = check_structure(args.directory)
    command_results = extract_commands(os.path.join(args.directory, "fly.sh"))
    option_results = extract_options(os.path.join(args.directory, "fly.sh"))
    content_results = check_content_requirements(args.directory)
    
    # Calculate compliance
    compliance = calculate_compliance(structure_results, command_results, option_results, content_results)
    
    # Combine results
    results = {
        **structure_results,
        **command_results,
        **option_results,
        "content": content_results,
        "compliance": compliance
    }
    
    # Output results
    if args.output:
        try:
            with open(args.output, 'w') as f:
                json.dump(results, f, indent=2)
            print(f"Validation report written to {args.output}")
        except Exception as e:
            print(f"Error writing output file: {e}")
    
    # Always print summary
    print(f"Compliance: {compliance['compliance_percentage']:.1f}% ({compliance['passed_checks']}/{compliance['total_checks']})")
    print(f"Level: {compliance['compliance_level']}")
    print(f"Status: {'✅ Compliant' if compliance['compliant'] else '❌ Non-compliant'}")
        
    # Print issues if non-compliant or verbose mode
    if not compliance['compliant'] or args.verbose:
        print("\nIssues found:")
        
        issue_count = 0
        
        # Directory issues
        for dirname, exists in structure_results["structure"]["directories"].items():
            if not exists:
                print(f"- Missing directory: {dirname}")
                issue_count += 1
        
        # File issues
        for filename, checks in structure_results["structure"]["files"].items():
            if not checks["exists"]:
                print(f"- Missing file: {filename}")
                issue_count += 1
            elif checks["executable"] is False:
                print(f"- File not executable: {filename}")
                issue_count += 1
        
        # Command issues
        for cmd, present in command_results["commands"].items():
            if not present:
                print(f"- Missing command: {cmd}")
                issue_count += 1
        
        # Option issues
        for opt, present in option_results["options"].items():
            if not present:
                print(f"- Missing option: {opt}")
                issue_count += 1
        
        # Content issues
        if "strict_mode" in content_results:
            for mode, enabled in content_results["strict_mode"].items():
                if not enabled:
                    print(f"- Missing strict mode: {mode}")
                    issue_count += 1
        
        if not content_results.get("help_function", False):
            print("- Missing help function")
            issue_count += 1
        
        if issue_count == 0:
            print("No issues found. Script is compliant with standards.")
    
    # Return exit code based on compliance
    return 0 if compliance['compliant'] else 1

if __name__ == "__main__":
    sys.exit(main())