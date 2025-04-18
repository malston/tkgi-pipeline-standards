#!/usr/bin/env python3
"""
test_tools.py - Simple tests for the fly script tools

This script tests the basic functionality of the generate, validate, and migrate tools.
"""

import os
import sys
import unittest
import tempfile
import shutil
import subprocess
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

class TestFlyScriptTools(unittest.TestCase):
    
    def setUp(self):
        # Create temp directory for tests
        self.test_dir = tempfile.mkdtemp()
        self.tools_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    
    def tearDown(self):
        # Clean up temp directory
        shutil.rmtree(self.test_dir)
    
    def test_generate_script(self):
        """Test generating a fly script"""
        output_dir = os.path.join(self.test_dir, 'generated')
        os.makedirs(output_dir, exist_ok=True)
        
        # Run generate_fly_script.py
        cmd = [
            sys.executable,
            os.path.join(self.tools_dir, 'generate_fly_script.py'),
            '-t', 'kustomize',
            '-o', output_dir,
            '-p', 'test-pipeline',
            '--simple-tests'
        ]
        
        try:
            result = subprocess.run(cmd, check=True, 
                                    stdout=subprocess.PIPE, 
                                    stderr=subprocess.PIPE,
                                    text=True)
            
            # Check that files were created
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'fly.sh')))
            self.assertTrue(os.path.isdir(os.path.join(output_dir, 'lib')))
            self.assertTrue(os.path.isdir(os.path.join(output_dir, 'tests')))
            
            # Check lib files
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'lib', 'commands.sh')))
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'lib', 'help.sh')))
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'lib', 'parsing.sh')))
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'lib', 'utils.sh')))
            
            # Check test files
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'tests', 'simple-test-framework.sh')))
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'tests', 'run-tests.sh')))
            
        except subprocess.CalledProcessError as e:
            self.fail(f"Generate script failed: {e.stderr}")
    
    def test_validate_script(self):
        """Test validating a fly script"""
        # First generate a script to validate
        output_dir = os.path.join(self.test_dir, 'to_validate')
        os.makedirs(output_dir, exist_ok=True)
        
        # Run generate_fly_script.py
        gen_cmd = [
            sys.executable,
            os.path.join(self.tools_dir, 'generate_fly_script.py'),
            '-t', 'kustomize',
            '-o', output_dir,
            '-p', 'test-pipeline'
        ]
        
        try:
            subprocess.run(gen_cmd, check=True, 
                           stdout=subprocess.PIPE, 
                           stderr=subprocess.PIPE)
            
            # Now validate the generated script
            val_cmd = [
                sys.executable,
                os.path.join(self.tools_dir, 'validate_fly_script.py'),
                '-d', output_dir
            ]
            
            result = subprocess.run(val_cmd, check=True,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE,
                                   text=True)
            
            # Check that validation passed
            self.assertIn("Compliant", result.stdout)
            
        except subprocess.CalledProcessError as e:
            self.fail(f"Validation failed: {e.stderr}")
    
    def test_migrate_script_simple(self):
        """Test migrating a simple script"""
        # Create a simple fly.sh script to migrate
        input_dir = os.path.join(self.test_dir, 'to_migrate')
        output_dir = os.path.join(self.test_dir, 'migrated')
        os.makedirs(input_dir, exist_ok=True)
        
        # Create a minimal fly.sh
        with open(os.path.join(input_dir, 'fly.sh'), 'w') as f:
            f.write("""#!/usr/bin/env bash
# Simple fly script for testing migration

PIPELINE="test-pipeline"
PIPELINE_NAME="$PIPELINE-test"

function show_usage() {
    echo "Usage: $0 -f <foundation>"
}

function set_pipeline() {
    echo "Setting pipeline $PIPELINE_NAME"
}

if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

# Parse arguments
while [[ "$1" =~ ^- ]]; do
    case $1 in
    -f | --foundation)
        shift
        FOUNDATION=$1
        ;;
    -h | --help)
        show_usage
        exit 0
        ;;
    esac
    shift
done

# Check required args
if [[ -z $FOUNDATION ]]; then
    echo "Missing -f <foundation>."
    show_usage
    exit 1
fi

set_pipeline
""")
        os.chmod(os.path.join(input_dir, 'fly.sh'), 0o755)
        
        # Run migrate_fly_script.py
        cmd = [
            sys.executable,
            os.path.join(self.tools_dir, 'migrate_fly_script.py'),
            '-i', os.path.join(input_dir, 'fly.sh'),
            '-o', output_dir,
            '--simple-tests'
        ]
        
        try:
            result = subprocess.run(cmd, check=True,
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE,
                                    text=True)
            
            # Check that migration produced the expected files
            self.assertTrue(os.path.isfile(os.path.join(output_dir, 'fly.sh')))
            self.assertTrue(os.path.isdir(os.path.join(output_dir, 'lib')))
            self.assertTrue(os.path.isdir(os.path.join(output_dir, 'tests')))
            
        except subprocess.CalledProcessError as e:
            self.fail(f"Migration failed: {e.stderr}")

if __name__ == '__main__':
    unittest.main()