#!/usr/bin/env python3
"""
migrate_fly_script.py - Migrate existing fly.sh to conform to standards

This tool helps migrate an existing fly.sh script to conform to the
tkgi-pipeline-standards by extracting functionality and restructuring it.

Usage:
    python3 migrate_fly_script.py -i /path/to/existing/fly.sh -o /path/to/output/dir

Author: Platform Engineering Team
"""

import argparse
import os
import sys
import re
import shutil
import json
from pathlib import Path

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Migrate fly.sh to standards")
    parser.add_argument("-i", "--input", required=True, 
                        help="Path to existing fly.sh script")
    parser.add_argument("-o", "--output-dir", required=True, 
                        help="Output directory for migrated script")
    parser.add_argument("-b", "--backup", action="store_true", 
                        help="Create backup of original script")
    parser.add_argument("--alternative-tests", action="store_true", 
                        help="Generate alternative tests instead of standard tests")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Show detailed migration steps")
    args = parser.parse_args()
    
    # Expand ~ to home directory in paths
    if args.input and args.input.startswith('~'):
        args.input = os.path.expanduser(args.input)
    if args.output_dir and args.output_dir.startswith('~'):
        args.output_dir = os.path.expanduser(args.output_dir)
        
    return args

def create_directory_structure(output_dir):
    """Create the required directory structure"""
    # Create base output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    # Create subdirectories
    os.makedirs(os.path.join(output_dir, "lib"), exist_ok=True)
    os.makedirs(os.path.join(output_dir, "tests"), exist_ok=True)

def extract_commands(script_content):
    """Extract commands handled by the script"""
    commands = []
    
    # Look for case statements handling commands
    case_pattern = re.compile(r'case\s+\$\w+\s+in(.*?)esac', re.DOTALL)
    command_pattern = re.compile(r'(\w+)\s*\)')
    
    for case_block in case_pattern.findall(script_content):
        for match in command_pattern.finditer(case_block):
            command = match.group(1)
            if command not in ["*", "esac"] and len(command) > 1:
                commands.append(command)
    
    # Also look for cmd_ functions
    for match in re.finditer(r'function\s+cmd_(\w+)', script_content):
        commands.append(match.group(1))
    
    return list(set(commands))

def extract_options(script_content):
    """Extract command-line options handled by the script"""
    options = []
    
    # Look for case statements handling options
    case_blocks = re.findall(r'case\s+\$\w+\s+in(.*?)esac', script_content, re.DOTALL)
    for block in case_blocks:
        # Find short and long options
        for match in re.finditer(r'(-\w|--\w+)\s*\)', block):
            options.append(match.group(1))
    
    return list(set(options))

def extract_variables(script_content):
    """Extract global variables defined in the script"""
    variables = {}
    
    # First split the script into lines to process each line
    lines = script_content.split('\n')
    for line in lines:
        # Skip comments, empty lines, and lines that don't look like variable assignments
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
            
        # Handle simple variable assignments
        if re.match(r'^\s*[A-Z_][A-Z0-9_]*=', line):
            # Split only on the first equals sign
            parts = line.split('=', 1)
            if len(parts) == 2:
                name = parts[0].strip()
                value = parts[1].strip()
                
                # Skip internal variables
                if name.startswith('__'):
                    continue
                    
                # Skip common environment variables
                if name in ['PATH', 'HOME', 'USER', 'PWD']:
                    continue
                
                # Handle command substitutions and function calls properly
                if '$(' in value and ')' in value:
                    # For these complex values, let's store the full value
                    variables[name] = value
                else:
                    # For simple values, clean up quotes if needed
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                    variables[name] = value
    
    return variables

def extract_functions(script_content):
    """Extract function definitions from the script"""
    functions = {}
    
    # Match function definitions
    function_pattern = re.compile(r'function\s+(\w+)\s*\(\)\s*\{(.*?)^\}', 
                                 re.MULTILINE | re.DOTALL)
    
    for match in function_pattern.finditer(script_content):
        name = match.group(1)
        body = match.group(2)
        functions[name] = body.strip()
    
    return functions

def categorize_functions(functions):
    """Categorize functions into lib files"""
    categories = {
        "commands.sh": [],
        "help.sh": [],
        "parsing.sh": [],
        "utils.sh": []
    }
    
    for name, body in functions.items():
        if name.startswith('cmd_') or name.endswith('_command') or 'pipeline' in name:
            categories["commands.sh"].append(name)
        elif name in ['show_usage', 'usage', 'help'] or 'help' in name or 'usage' in name:
            categories["help.sh"].append(name)
        elif name in ['parse_arguments', 'process_args'] or 'arg' in name or 'parse' in name:
            categories["parsing.sh"].append(name)
        else:
            categories["utils.sh"].append(name)
    
    return categories

def extract_pipeline_name(script_content):
    """Try to extract the base pipeline name"""
    match = re.search(r'PIPELINE="?([a-zA-Z0-9_-]+)"?', script_content)
    if match:
        return match.group(1)
    return "tkgi-app"

def generate_lib_files(output_dir, functions, categories, verbose=False):
    """Generate lib module files with categorized functions"""
    for filename, function_names in categories.items():
        filepath = os.path.join(output_dir, "lib", filename)
        
        if verbose:
            print(f"Generating {filepath} with {len(function_names)} functions")
        
        with open(filepath, 'w') as f:
            f.write(r"#!/usr/bin/env bash" + "\n")
            f.write(f"# {filename.split('.')[0].title()} functions for fly.sh\n\n")
            
            for name in function_names:
                if name in functions:
                    f.write(f"function {name}() {{\n{functions[name]}\n}}\n\n")
        
        # Make executable
        os.chmod(filepath, 0o755)

def generate_main_script(output_dir, pipeline_name, variables, functions, verbose=False):
    """Generate the main fly.sh script"""
    filepath = os.path.join(output_dir, "fly.sh")
    
    if verbose:
        print(f"Generating main script at {filepath}")
    
    with open(filepath, 'w') as f:
        f.write(r"#!/usr/bin/env bash" + "\n")
        f.write("# Standardized fly.sh script\n\n")
        
        # Add strict mode
        f.write("set -o errexit\n")
        f.write("set -o pipefail\n\n")
        
        # Add script directory
        f.write('__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"\n\n')
        
        # Add source statements for lib files
        f.write("# Source helper libraries\n")
        f.write('source "$__DIR/lib/utils.sh"\n')
        f.write('source "$__DIR/lib/commands.sh"\n')
        f.write('source "$__DIR/lib/help.sh"\n')
        f.write('source "$__DIR/lib/parsing.sh"\n\n')
        
        # Add global variables
        f.write("# Global defaults\n")
        for name, value in variables.items():
            # Check if we need to preserve quotes
            if ' ' in value and not (value.startswith('"') or value.startswith("'")):
                # Add quotes for values with spaces
                f.write(f'{name}="{value}"\n')
            else:
                # Preserve the value as is
                f.write(f"{name}={value}\n")
        
        # Add initialization of additional variables
        f.write("CREATE_RELEASE=false\n")
        f.write("SET_RELEASE_PIPELINE=false\n")
        f.write("DRY_RUN=false\n")
        f.write("VERBOSE=false\n")
        f.write('ENVIRONMENT=""\n')
        f.write('TIMER_DURATION=3h\n\n')
        
        # Add main execution
        f.write("# Process command line arguments\n")
        f.write('parse_arguments "$@"\n')
    
    # Make executable
    os.chmod(filepath, 0o755)

def generate_alternative_test_framework(output_dir, verbose=False):
    """Generate alternative test framework"""
    test_dir = os.path.join(output_dir, "tests")
    
    if verbose:
        print(f"Generating alternative test framework in {test_dir}")
    
    # Create alternative test framework
    with open(os.path.join(test_dir, "test-framework.sh"), 'w') as f:
        f.write(r"""#!/usr/bin/env bash
# test-framework.sh - Easy-to-understand test framework for fly.sh

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Print a test header
function test_header() {
    echo "==== TEST: $1 ===="
}

# Assert that two values are equal
function assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo "✅ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $message"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        ((TESTS_FAILED++))
    fi
}

# Assert that a value contains a substring
function assert_contains() {
    local string="$1"
    local substring="$2"
    local message="$3"
    
    if [[ "$string" == *"$substring"* ]]; then
        echo "✅ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $message"
        echo "   String:    '$string'"
        echo "   Not found: '$substring'"
        ((TESTS_FAILED++))
    fi
}

# Assert that a command exits with expected code
function assert_exit_code() {
    local command="$1"
    local expected_code="$2"
    local message="$3"
    
    # Run command in subshell to capture exit code
    eval "$command" > /dev/null 2>&1
    local actual_code=$?
    
    if [[ $actual_code -eq $expected_code ]]; then
        echo "✅ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $message"
        echo "   Expected exit code: $expected_code"
        echo "   Actual exit code:   $actual_code"
        ((TESTS_FAILED++))
    fi
}

# Print summary of test results
function print_test_summary() {
    echo ""
    echo "==== TEST SUMMARY ===="
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "===================="
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "❌ Some tests failed!"
        return 1
    else
        echo "✅ All tests passed!"
        return 0
    fi
}
""")
    
    # Create test runner
    with open(os.path.join(test_dir, "run-tests.sh"), 'w') as f:
        f.write(r"""#!/usr/bin/env bash
# run-tests.sh - Run all tests for fly.sh

# Find all test files
TEST_DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
TEST_FILES=("$TEST_DIR"/test-*.sh)

# Run each test file
for test_file in "${TEST_FILES[@]}"; do
    echo "Running test: $(basename "$test_file")"
    bash "$test_file"
    
    # Check if test failed
    if [[ $? -ne 0 ]]; then
        echo "Test failed: $(basename "$test_file")"
        exit 1
    fi
done

echo "All tests passed!"
""")
    
    # Create example test for fly.sh
    with open(os.path.join(test_dir, "test-fly-basics.sh"), 'w') as f:
        f.write(r"""#!/usr/bin/env bash
# test-fly-basics.sh - Basic tests for fly.sh

# Source the test framework
source "$(dirname "$0")/test-framework.sh"

# Path to the fly.sh script being tested
FLY_SCRIPT="../fly.sh"

# Test 1: Check that script exists
test_header "Script exists"
if [[ -f "$FLY_SCRIPT" ]]; then
    echo "✅ PASS: fly.sh script exists"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: fly.sh script not found at $FLY_SCRIPT"
    ((TESTS_FAILED++))
    exit 1  # No point continuing if script doesn't exist
fi

# Test 2: Check that script is executable
test_header "Script is executable"
if [[ -x "$FLY_SCRIPT" ]]; then
    echo "✅ PASS: fly.sh script is executable"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL: fly.sh script is not executable"
    ((TESTS_FAILED++))
fi

# Test 3: Check usage output
test_header "Usage output"
OUTPUT=$("$FLY_SCRIPT" -h 2>&1)
assert_contains "$OUTPUT" "Usage:" "Help output should contain 'Usage:'"
assert_contains "$OUTPUT" "-f, --foundation" "Help should mention foundation parameter"

# Test 4: Check error for missing foundation
test_header "Error for missing foundation"
OUTPUT=$("$FLY_SCRIPT" 2>&1 || true)
assert_contains "$OUTPUT" "Missing -f <foundation>" "Should error when foundation is missing"

# Print test summary
print_test_summary
exit $?
""")
    
    # Make all scripts executable
    os.chmod(os.path.join(test_dir, "test-framework.sh"), 0o755)
    os.chmod(os.path.join(test_dir, "run-tests.sh"), 0o755)
    os.chmod(os.path.join(test_dir, "test-fly-basics.sh"), 0o755)

def generate_standard_test_framework(output_dir, verbose=False):
    """Generate standard test framework from templates"""
    # For this prototype, we'll use a reduced version of the standard tests
    test_dir = os.path.join(output_dir, "tests")
    
    if verbose:
        print(f"Generating standard test framework in {test_dir}")
    
    # Create test framework
    with open(os.path.join(test_dir, "test-framework.sh"), 'w') as f:
        f.write(r"""#!/usr/bin/env bash
# Standard test framework for fly.sh script testing

# Global test variables
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_FAILURES=()

# Function to start a test
function start_test() {
    echo "TEST: $1"
    ((TESTS_RUN++))
}

# Function to indicate test passed
function test_pass() {
    echo "PASS: $1"
    ((TESTS_PASSED++))
}

# Function to indicate test failed
function test_fail() {
    local message=$1
    echo "FAIL: $message"
    TEST_FAILURES+=("$message")
    ((TESTS_FAILED++))
    return 1
}

# Function to run a test
function run_test() {
    local test_function=$1
    echo
    echo "Running test: ${test_function#test_}"
    $test_function || echo "Test exited with code $?"
    echo
}

# Function to report test results
function report_results() {
    echo
    echo "Test Summary:"
    echo "  Tests Run:    $TESTS_RUN"
    echo "  Tests Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "  Tests Failed: $TESTS_FAILED"
        echo
        echo "Failed Tests:"
        for ((i=0; i<${#TEST_FAILURES[@]}; i++)); do
            echo "  $((i+1)). ${TEST_FAILURES[$i]}"
        done
        exit 1
    else
        echo "All tests passed!"
    fi
}

# Mock functions
function mock_fly() {
    # Mock of the fly command
    echo "Mock fly command called with: $*"
    return 0
}

# Assertion functions
function assert_equals() {
    local actual=$1
    local expected=$2
    local message=${3:-"Expected: '$expected', but got: '$actual'"}
    
    if [[ "$actual" != "$expected" ]]; then
        test_fail "$message"
        return 1
    fi
    return 0
}

function assert_contains() {
    local haystack=$1
    local needle=$2
    local message=${3:-"Expected to find: '$needle' in: '$haystack'"}
    
    if [[ ! "$haystack" =~ "$needle" ]]; then
        test_fail "$message"
        return 1
    fi
    return 0
}

function assert_file_exists() {
    local file=$1
    local message=${2:-"Expected file to exist: '$file'"}
    
    if [[ ! -f "$file" ]]; then
        test_fail "$message"
        return 1
    fi
    return 0
}
""")
    
    # Create test runner
    with open(os.path.join(test_dir, "run_tests.sh"), 'w') as f:
        f.write(r"""#!/usr/bin/env bash
# Test runner for fly.sh tests

# Find all test files
TEST_DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
TEST_FILES=("$TEST_DIR"/test_*.sh)

echo "Running ${#TEST_FILES[@]} tests:"
for test_file in "${TEST_FILES[@]}"; do
    echo "  - $(basename "$test_file")"
done
echo

# Run each test file
FAILED=0
for test_file in "${TEST_FILES[@]}"; do
    echo "=== Running test: $(basename "$test_file") ==="
    if ! bash "$test_file"; then
        FAILED=1
    fi
    echo
done

# Report overall status
if [ $FAILED -eq 0 ]; then
    echo "All test files executed successfully!"
    exit 0
else
    echo "Some tests failed. Please review the output above."
    exit 1
fi
""")
    
    # Create a basic test file
    with open(os.path.join(test_dir, "test_fly_basics.sh"), 'w') as f:
        f.write(r"""#!/usr/bin/env bash
# Basic tests for fly.sh

source "$(dirname "$0")/test-framework.sh"

# Setup
FLY_SCRIPT="../fly.sh"

# Test that fly.sh exists and is executable
function test_fly_exists() {
    start_test "fly.sh existence"
    
    assert_file_exists "$FLY_SCRIPT" "fly.sh script must exist"
    
    if [[ -x "$FLY_SCRIPT" ]]; then
        test_pass "fly.sh is executable"
    else
        test_fail "fly.sh must be executable"
    fi
}

# Test help output
function test_help_output() {
    start_test "Help output"
    
    # Get help output
    local output=$("$FLY_SCRIPT" -h 2>&1 || echo "Failed to run command")
    
    # Check for key components
    assert_contains "$output" "Usage:" "Help output should show usage"
    assert_contains "$output" "-f, --foundation" "Help should explain foundation parameter"
}

# Test error when missing foundation
function test_missing_foundation() {
    start_test "Missing foundation error"
    
    # Run without foundation and expect error
    local output=$("$FLY_SCRIPT" 2>&1 || echo "Command failed as expected")
    
    # Check error message
    assert_contains "$output" "Missing -f <foundation>" "Should error when foundation missing"
}

# Run tests
run_test test_fly_exists
run_test test_help_output
run_test test_missing_foundation

# Report results
report_results
""")
    
    # Make all scripts executable
    os.chmod(os.path.join(test_dir, "test-framework.sh"), 0o755)
    os.chmod(os.path.join(test_dir, "run_tests.sh"), 0o755)
    os.chmod(os.path.join(test_dir, "test_fly_basics.sh"), 0o755)

def main():
    try:
        args = parse_args()
        
        # Check if input file exists
        if not os.path.isfile(args.input):
            print(f"Error: Input file {args.input} does not exist")
            sys.exit(1)
        
        # Ensure output directory can be created
        output_dir = args.output_dir
        if not os.path.exists(os.path.dirname(output_dir)) and os.path.dirname(output_dir):
            try:
                # Create parent directory if it doesn't exist
                os.makedirs(os.path.dirname(output_dir), exist_ok=True)
                if args.verbose:
                    print(f"Created parent directory: {os.path.dirname(output_dir)}")
            except PermissionError:
                print(f"Error: Permission denied when creating directory {os.path.dirname(output_dir)}")
                sys.exit(1)
            except Exception as e:
                print(f"Error creating parent directory: {e}")
                sys.exit(1)
        
        # Create backup if requested
        if args.backup:
            backup_path = f"{args.input}.bak"
            try:
                shutil.copy2(args.input, backup_path)
                print(f"Created backup at {backup_path}")
            except Exception as e:
                print(f"Warning: Could not create backup: {e}")
        
        # Create output directory
        try:
            create_directory_structure(args.output_dir)
            if args.verbose:
                print(f"Created directory structure in {args.output_dir}")
        except PermissionError:
            print(f"Error: Permission denied when creating directory {args.output_dir}")
            sys.exit(1)
        except Exception as e:
            print(f"Error creating directory structure: {e}")
            sys.exit(1)
        
        # Read the source script
        try:
            with open(args.input, 'r') as f:
                script_content = f.read()
            if args.verbose:
                print(f"Successfully read input file: {args.input}")
        except Exception as e:
            print(f"Error reading input file: {e}")
            sys.exit(1)
        
        # Extract components
        if args.verbose:
            print("Analyzing input script...")
        
        commands = extract_commands(script_content)
        options = extract_options(script_content)
        variables = extract_variables(script_content)
        functions = extract_functions(script_content)
        categories = categorize_functions(functions)
        pipeline_name = extract_pipeline_name(script_content)
        
        if args.verbose:
            print(f"Found:")
            print(f"  - {len(commands)} commands: {', '.join(commands)}")
            print(f"  - {len(options)} options: {', '.join(options)}")
            print(f"  - {len(functions)} functions")
            print(f"  - Pipeline name: {pipeline_name}")
            print("\nExtracted variables:")
            for name, value in variables.items():
                if '$(' in value:
                    # Highlight command substitutions for easier review
                    print(f"  \033[33m{name}={value}\033[0m")
                else:
                    print(f"  {name}={value}")
        
        # Generate lib files
        try:
            generate_lib_files(args.output_dir, functions, categories, args.verbose)
        except PermissionError:
            print(f"Error: Permission denied when writing to {args.output_dir}/lib/")
            sys.exit(1)
        except Exception as e:
            print(f"Error generating lib files: {e}")
            sys.exit(1)
        
        # Generate main script
        try:
            generate_main_script(args.output_dir, pipeline_name, variables, functions, args.verbose)
        except PermissionError:
            print(f"Error: Permission denied when writing to {args.output_dir}/fly.sh")
            sys.exit(1)
        except Exception as e:
            print(f"Error generating main script: {e}")
            sys.exit(1)
        
        # Generate test framework
        try:
            if args.alternative_tests:
                generate_alternative_test_framework(args.output_dir, args.verbose)
            else:
                generate_standard_test_framework(args.output_dir, args.verbose)
        except PermissionError:
            print(f"Error: Permission denied when writing to {args.output_dir}/tests/")
            sys.exit(1)
        except Exception as e:
            print(f"Error generating test framework: {e}")
            sys.exit(1)
        
        # Success message
        print("\033[92mMigration completed successfully!\033[0m")
        print(f"Output files written to: \033[1m{os.path.abspath(args.output_dir)}\033[0m")
        print()
        print("Next steps:")
        print("1. Review the migrated files for correctness")
        print("2. Update any hard-coded paths or references")
        print("3. Run the tests to verify functionality")
        print("4. Update documentation as needed")
        
    except KeyboardInterrupt:
        print("\nOperation canceled by user")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error occurred: {e}")
        if args and args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()