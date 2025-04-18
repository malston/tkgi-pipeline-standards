#!/usr/bin/env python3
"""
generate_fly_script.py - Generate standardized fly.sh scripts

This tool generates a standardized fly.sh script along with supporting files
according to the tkgi-pipeline-standards.

Usage:
    python3 generate_fly_script.py -t kustomize -o /path/to/output/dir -p my-pipeline-name

Author: Platform Engineering Team
"""

import argparse
import os
import sys
import shutil
import jinja2
import yaml
from pathlib import Path

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Generate standardized fly.sh scripts")
    parser.add_argument("-t", "--template", choices=["kustomize", "helm", "cli-tool"], 
                        default="kustomize", help="Template type to use")
    parser.add_argument("-o", "--output-dir", required=True, 
                        help="Output directory for the script")
    parser.add_argument("-c", "--config", help="YAML config file with custom values")
    parser.add_argument("-p", "--pipeline-name", default="tkgi-app", 
                        help="Base pipeline name")
    parser.add_argument("--alternative-tests", action="store_false", dest="standard_tests",
                        help="Generate alternative test framework")
    return parser.parse_args()

def load_config(config_path):
    """Load configuration from YAML file"""
    if not config_path:
        return {}
    
    try:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"Error loading config file: {e}")
        return {}

def create_directory_structure(output_dir):
    """Create the required directory structure"""
    os.makedirs(os.path.join(output_dir, "lib"), exist_ok=True)
    os.makedirs(os.path.join(output_dir, "tests"), exist_ok=True)

def get_template_dir():
    """Get the path to the templates directory"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, "templates")

def render_template(template_path, output_path, context):
    """Render a template file and write to output path"""
    template_dir = get_template_dir()
    
    try:
        template_loader = jinja2.FileSystemLoader(searchpath=template_dir)
        template_env = jinja2.Environment(loader=template_loader, 
                                         trim_blocks=True, 
                                         lstrip_blocks=True)
        
        # Check if template file exists
        template_file = os.path.join(template_dir, template_path)
        if not os.path.exists(template_file):
            print(f"Error: Template file not found: {template_file}")
            return False
        
        template = template_env.get_template(template_path)
        
        try:
            output = template.render(**context)
        except jinja2.exceptions.TemplateSyntaxError as e:
            print(f"Syntax error in template {template_path}: {e}")
            print(f"Line {e.lineno}: {e.message}")
            return False
        except Exception as e:
            print(f"Error rendering template {template_path}: {e}")
            return False
        
        # Ensure target directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        with open(output_path, 'w') as f:
            f.write(output)
        
        # Make script files executable
        if output_path.endswith('.sh'):
            os.chmod(output_path, 0o755)
            
        return True
    except jinja2.exceptions.TemplateNotFound as e:
        print(f"Template not found: {template_path}")
        print(f"Search path: {template_dir}")
        return False
    except Exception as e:
        print(f"Error processing template {template_path}: {e}")
        import traceback
        traceback.print_exc()
        return False

def copy_test_files(template_type, output_dir, use_standard_tests=True):
    """Copy test files to output directory"""
    template_dir = get_template_dir()
    tests_src_dir = os.path.join(template_dir, template_type, "tests")
    tests_dst_dir = os.path.join(output_dir, "tests")
    
    if not use_standard_tests:
        # Use alternative test files instead
        alt_test_dir = os.path.join(template_dir, "alternative-tests")
        
        if os.path.exists(alt_test_dir):
            for file in os.listdir(alt_test_dir):
                if file.endswith('.sh'):
                    src_file = os.path.join(alt_test_dir, file)
                    dst_file = os.path.join(tests_dst_dir, file)
                    shutil.copy2(src_file, dst_file)
                    os.chmod(dst_file, 0o755)
        else:
            print(f"Warning: Alternative test directory not found at {alt_test_dir}")
    else:
        # Use standard test files
        if os.path.exists(tests_src_dir):
            for file in os.listdir(tests_src_dir):
                if file.endswith('.sh'):
                    src_file = os.path.join(tests_src_dir, file)
                    dst_file = os.path.join(tests_dst_dir, file)
                    shutil.copy2(src_file, dst_file)
                    os.chmod(dst_file, 0o755)
        else:
            print(f"Warning: Test directory not found at {tests_src_dir}")

def main():
    args = parse_args()
    
    # Validate output directory
    if os.path.exists(args.output_dir):
        if not os.path.isdir(args.output_dir):
            print(f"Error: Output path {args.output_dir} exists but is not a directory")
            sys.exit(1)
    else:
        try:
            os.makedirs(args.output_dir)
        except Exception as e:
            print(f"Error creating output directory: {e}")
            sys.exit(1)
    
    # Load configuration
    config = load_config(args.config)
    
    # Combine config with command-line args
    context = {
        "pipeline_name": args.pipeline_name,
        "template_type": args.template,
        # Default values
        "github_org": "Utilities-tkgieng",
        "default_branch": "develop",
        "default_config_branch": "master",
        "default_params_branch": "master",
        **config
    }
    
    # Create directory structure
    create_directory_structure(args.output_dir)
    
    # Render main fly.sh
    template_path = f"{args.template}/fly.sh.j2"
    output_path = os.path.join(args.output_dir, "fly.sh")
    if not render_template(template_path, output_path, context):
        print("Error generating fly.sh")
        sys.exit(1)
    
    # Render library components
    for component in ["commands.sh", "help.sh", "parsing.sh", "utils.sh"]:
        template_path = f"{args.template}/lib/{component}.j2"
        output_path = os.path.join(args.output_dir, "lib", component)
        
        if not render_template(template_path, output_path, context):
            print(f"Warning: Could not generate {component}")
    
    # Copy test files
    copy_test_files(args.template, args.output_dir, args.standard_tests)
    
    print(f"Successfully generated fly.sh script in {args.output_dir}")
    print("Files generated:")
    print(f"  - {args.output_dir}/fly.sh")
    print(f"  - {args.output_dir}/lib/commands.sh")
    print(f"  - {args.output_dir}/lib/help.sh")
    print(f"  - {args.output_dir}/lib/parsing.sh")
    print(f"  - {args.output_dir}/lib/utils.sh")
    print(f"  - {args.output_dir}/tests/*")

if __name__ == "__main__":
    main()