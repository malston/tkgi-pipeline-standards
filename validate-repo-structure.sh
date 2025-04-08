#!/usr/bin/env bash
#
# validate-repo-structure.sh
#
# A tool to validate if a repository conforms to the standardized structure
# for TKGI component installation repositories.
#
# Usage: ./validate-repo-structure.sh [path/to/repo]

set -eo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if a repo path was provided, otherwise use current directory
REPO_PATH="${1:-.}"

# Ensure the repo path exists
if [[ ! -d "$REPO_PATH" ]]; then
  echo -e "${RED}Error: Directory does not exist: $REPO_PATH${NC}"
  exit 1
fi

# Get absolute path
REPO_PATH=$(cd "$REPO_PATH" && pwd)
REPO_NAME=$(basename "$REPO_PATH")

echo -e "${BLUE}Validating repository structure: ${REPO_NAME}${NC}"
echo

# Track validation results
ERRORS=0
WARNINGS=0
PASSED=0

# Function to check if a path exists
check_path() {
  local path="$1"
  local required="$2"
  local description="$3"
  
  if [[ -e "$path" ]]; then
    echo -e "${GREEN}✓ $description exists${NC}"
    ((PASSED++))
    return 0
  else
    if [[ "$required" == "true" ]]; then
      echo -e "${RED}✗ $description does not exist: $path${NC}"
      ((ERRORS++))
    else
      echo -e "${YELLOW}⚠ $description does not exist (optional): $path${NC}"
      ((WARNINGS++))
    fi
    return 1
  fi
}

# Function to check if any file matches a pattern
check_files_exist() {
  local pattern="$1"
  local required="$2"
  local description="$3"
  
  if ls $pattern 1> /dev/null 2>&1; then
    echo -e "${GREEN}✓ $description exists${NC}"
    ((PASSED++))
    return 0
  else
    if [[ "$required" == "true" ]]; then
      echo -e "${RED}✗ $description does not exist: $pattern${NC}"
      ((ERRORS++))
    else
      echo -e "${YELLOW}⚠ $description does not exist (optional): $pattern${NC}"
      ((WARNINGS++))
    fi
    return 1
  fi
}

# Function to check if a script file has execute permissions
check_executable() {
  local path="$1"
  local required="$2"
  local description="$3"
  
  if [[ -x "$path" ]]; then
    echo -e "${GREEN}✓ $description is executable${NC}"
    ((PASSED++))
    return 0
  else
    if [[ "$required" == "true" ]]; then
      echo -e "${RED}✗ $description is not executable: $path${NC}"
      ((ERRORS++))
    else
      echo -e "${YELLOW}⚠ $description is not executable (should be): $path${NC}"
      ((WARNINGS++))
    fi
    return 1
  fi
}

# Function to check if a script contains a particular string/pattern
check_script_content() {
  local path="$1"
  local pattern="$2"
  local description="$3"
  
  if grep -q "$pattern" "$path" 2>/dev/null; then
    echo -e "${GREEN}✓ $description: $path${NC}"
    ((PASSED++))
    return 0
  else
    echo -e "${YELLOW}⚠ $description: $path${NC}"
    ((WARNINGS++))
    return 1
  fi
}

# Function to check directory structure
check_directory_structure() {
  echo -e "\n${BLUE}Checking directory structure:${NC}"
  
  # Required directories
  check_path "$REPO_PATH/ci" "true" "CI directory"
  check_path "$REPO_PATH/ci/pipelines" "true" "CI pipelines directory"
  check_path "$REPO_PATH/ci/tasks" "true" "CI tasks directory"
  check_path "$REPO_PATH/ci/vars" "true" "CI variables directory"
  check_path "$REPO_PATH/ci/helm" "true" "CI Helm values directory"
  check_path "$REPO_PATH/ci/lib" "true" "CI lib directory"
  check_path "$REPO_PATH/ci/cmds" "true" "CI commands directory"
  check_path "$REPO_PATH/scripts" "true" "Scripts directory"
  check_path "$REPO_PATH/release" "true" "Release directory"
  
  # Optional directories
  check_path "$REPO_PATH/ci/tasks/pre-install" "false" "Pre-install tasks directory"
  check_path "$REPO_PATH/ci/tasks/install" "false" "Install tasks directory" 
  check_path "$REPO_PATH/ci/tasks/post-install" "false" "Post-install tasks directory"
  check_path "$REPO_PATH/ci/tasks/test" "false" "Test tasks directory"
}

# Function to check key files
check_key_files() {
  echo -e "\n${BLUE}Checking key files:${NC}"
  
  # Required files
  check_path "$REPO_PATH/README.md" "true" "README file"
  check_path "$REPO_PATH/ci/fly.sh" "true" "Fly script"
  check_files_exist "$REPO_PATH/ci/pipelines/*.yml" "true" "Pipeline definition"
  check_files_exist "$REPO_PATH/ci/helm/values-*.yaml" "true" "Helm values"
  check_path "$REPO_PATH/release/versions.yml" "true" "Versions file"
  
  # Optional files - vars files are now optional
  check_files_exist "$REPO_PATH/ci/vars/*.yml" "false" "Variables file (optional)"
  check_path "$REPO_PATH/ci/helm/base-values.yaml" "false" "Helm base values"
  check_path "$REPO_PATH/.pipeline-config" "false" "Pipeline config for params repo"
}

# Function to check script permissions
check_script_permissions() {
  echo -e "\n${BLUE}Checking script permissions:${NC}"
  
  if check_path "$REPO_PATH/ci/fly.sh" "false" "Fly script"; then
    check_executable "$REPO_PATH/ci/fly.sh" "true" "Fly script"
  fi
  
  for script in "$REPO_PATH/ci/tasks/"*"/scripts/"*.sh; do
    if [[ -f "$script" ]]; then
      check_executable "$script" "true" "Task script: $script"
    fi
  done
  
  for script in "$REPO_PATH/scripts/"*.sh; do
    if [[ -f "$script" ]]; then
      check_executable "$script" "true" "Utility script: $script"
    fi
  done
  
  if check_path "$REPO_PATH/release/promote.sh" "false" "Promote script"; then
    check_executable "$REPO_PATH/release/promote.sh" "true" "Promote script"
  fi
}

# Function to check pipeline configurations
check_pipelines() {
  echo -e "\n${BLUE}Checking pipeline configurations:${NC}"
  
  # Check pipeline files exist
  local pipeline_types=("install" "upgrade" "test")
  local found_any=false
  
  for type in "${pipeline_types[@]}"; do
    if [[ -f "$REPO_PATH/ci/pipelines/$type.yml" ]]; then
      echo -e "${GREEN}✓ Found $type pipeline definition${NC}"
      found_any=true
      ((PASSED++))
    fi
  done
  
  if [[ "$found_any" == "false" ]]; then
    echo -e "${RED}✗ No standard pipeline definitions found${NC}"
    ((ERRORS++))
  fi
  
  # Check pipeline content validity if fly is available
  if command -v fly &> /dev/null; then
    for pipeline in "$REPO_PATH/ci/pipelines/"*.yml; do
      if [[ -f "$pipeline" ]]; then
        if fly validate-pipeline -c "$pipeline" &> /dev/null; then
          echo -e "${GREEN}✓ Pipeline validates: $(basename "$pipeline")${NC}"
          ((PASSED++))
        else
          echo -e "${RED}✗ Pipeline validation failed: $(basename "$pipeline")${NC}"
          ((ERRORS++))
        fi
      fi
    done
  else
    echo -e "${YELLOW}⚠ fly command not available, skipping pipeline validation${NC}"
    ((WARNINGS++))
  fi
}

# Function to check fly script functionality
check_fly_script() {
  echo -e "\n${BLUE}Checking fly.sh functionality:${NC}"
  
  if [[ -f "$REPO_PATH/ci/fly.sh" ]]; then
    # Check for required commands
    local required_commands=("set-pipeline" "promote-pipeline" "execute-task")
    
    for cmd in "${required_commands[@]}"; do
      if grep -q "case.*\"$cmd\"" "$REPO_PATH/ci/fly.sh"; then
        echo -e "${GREEN}✓ fly.sh implements $cmd command${NC}"
        ((PASSED++))
      else
        echo -e "${RED}✗ fly.sh missing $cmd command implementation${NC}"
        ((ERRORS++))
      fi
    done
    
    # Check for required options
    local required_options=("--datacenter" "--foundation" "--target")
    
    for opt in "${required_options[@]}"; do
      if grep -q "$opt" "$REPO_PATH/ci/fly.sh"; then
        echo -e "${GREEN}✓ fly.sh implements $opt option${NC}"
        ((PASSED++))
      else
        echo -e "${RED}✗ fly.sh missing $opt option${NC}"
        ((ERRORS++))
      fi
    done
    
    # Check for command files
    for cmd in "${required_commands[@]}"; do
      cmd_file="$REPO_PATH/ci/cmds/${cmd/-/_}.sh"
      if [[ -f "$cmd_file" ]]; then
        echo -e "${GREEN}✓ Command file exists: $(basename "$cmd_file")${NC}"
        ((PASSED++))
      else
        echo -e "${RED}✗ Command file missing: $(basename "$cmd_file")${NC}"
        ((ERRORS++))
      fi
    done
  fi
}

# Function to check utility scripts
check_utility_scripts() {
  echo -e "\n${BLUE}Checking utility scripts:${NC}"
  
  # Check for common utility scripts
  local utility_scripts=("helm-helpers.sh" "kubernetes-helpers.sh" "common.sh")
  local found_any=false
  
  for script in "${utility_scripts[@]}"; do
    if [[ -f "$REPO_PATH/scripts/$script" ]]; then
      echo -e "${GREEN}✓ Found utility script: $script${NC}"
      found_any=true
      ((PASSED++))
    fi
  done
  
  if [[ "$found_any" == "false" ]]; then
    echo -e "${YELLOW}⚠ No standard utility scripts found${NC}"
    ((WARNINGS++))
  fi
  
  # Check for utility script usage in task scripts
  for task_script in "$REPO_PATH/ci/tasks/"*"/scripts/"*.sh; do
    if [[ -f "$task_script" ]]; then
      if grep -q "source.*scripts/" "$task_script"; then
        echo -e "${GREEN}✓ Task script uses utility scripts: $(basename "$task_script")${NC}"
        ((PASSED++))
      else
        echo -e "${YELLOW}⚠ Task script doesn't appear to use utility scripts: $(basename "$task_script")${NC}"
        ((WARNINGS++))
      fi
    fi
  done
}

# Function to check parameter file compatibility
check_params_compatibility() {
  echo -e "\n${BLUE}Checking parameter compatibility:${NC}"
  
  # Check set_pipeline.sh for params repo handling
  if [[ -f "$REPO_PATH/ci/cmds/set_pipeline.sh" ]]; then
    if grep -q "params_repo" "$REPO_PATH/ci/cmds/set_pipeline.sh"; then
      echo -e "${GREEN}✓ set_pipeline.sh handles params repository${NC}"
      ((PASSED++))
    else
      echo -e "${RED}✗ set_pipeline.sh doesn't handle params repository${NC}"
      ((ERRORS++))
    fi
    
    # Check for datacenter handling
    if grep -q "datacenter" "$REPO_PATH/ci/cmds/set_pipeline.sh"; then
      echo -e "${GREEN}✓ set_pipeline.sh handles datacenter parameter${NC}"
      ((PASSED++))
    else
      echo -e "${RED}✗ set_pipeline.sh doesn't handle datacenter parameter${NC}"
      ((ERRORS++))
    fi
    
    # Check for foundation handling
    if grep -q "foundation" "$REPO_PATH/ci/cmds/set_pipeline.sh"; then
      echo -e "${GREEN}✓ set_pipeline.sh handles foundation parameter${NC}"
      ((PASSED++))
    else
      echo -e "${RED}✗ set_pipeline.sh doesn't handle foundation parameter${NC}"
      ((ERRORS++))
    fi
    
    # Check for hierarchical vars file structure
    local patterns=("global.yml" "k8s-global.yml" "datacenter.yml" "foundation.yml")
    for pattern in "${patterns[@]}"; do
      if grep -q "$pattern" "$REPO_PATH/ci/cmds/set_pipeline.sh"; then
        echo -e "${GREEN}✓ set_pipeline.sh references $pattern${NC}"
        ((PASSED++))
      else
        echo -e "${YELLOW}⚠ set_pipeline.sh might not reference $pattern${NC}"
        ((WARNINGS++))
      fi
    done
  fi
  
  # Check promote_pipeline.sh for params handling
  if [[ -f "$REPO_PATH/ci/cmds/promote_pipeline.sh" ]]; then
    if grep -q "params_repo" "$REPO_PATH/ci/cmds/promote_pipeline.sh"; then
      echo -e "${GREEN}✓ promote_pipeline.sh handles params repository${NC}"
      ((PASSED++))
    else
      echo -e "${RED}✗ promote_pipeline.sh doesn't handle params repository${NC}"
      ((ERRORS++))
    fi
    
    # Check for ops target handling
    if grep -q "ops-target\|ops_target" "$REPO_PATH/ci/cmds/promote_pipeline.sh"; then
      echo -e "${GREEN}✓ promote_pipeline.sh handles Ops Concourse target${NC}"
      ((PASSED++))
    else
      echo -e "${RED}✗ promote_pipeline.sh doesn't handle Ops Concourse target${NC}"
      ((ERRORS++))
    fi
  fi
  
  # Check if .pipeline-config exists for storing params repo location
  if [[ -f "$REPO_PATH/.pipeline-config" ]]; then
    echo -e "${GREEN}✓ Pipeline config file exists for storing params repo location${NC}"
    ((PASSED++))
  else
    echo -e "${YELLOW}⚠ Pipeline config file does not exist: $REPO_PATH/.pipeline-config (optional)${NC}"
    ((WARNINGS++))
  fi
}

# Run all checks
check_directory_structure
check_key_files
check_script_permissions
check_pipelines
check_fly_script
check_utility_scripts
check_params_compatibility

# Print summary
echo
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Errors: $ERRORS${NC}"

# Set exit code based on errors
if [[ $ERRORS -gt 0 ]]; then
  echo -e "\n${RED}Repository does not conform to the standard structure.${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "\n${YELLOW}Repository has some minor deviations from the standard structure.${NC}"
  exit 0
else
  echo -e "\n${GREEN}Repository conforms to the standard structure!${NC}"
  exit 0
fi

# Print summary
echo
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Errors: $ERRORS${NC}"

# Set exit code based on errors
if [[ $ERRORS -gt 0 ]]; then
  echo -e "\n${RED}Repository does not conform to the standard structure.${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "\n${YELLOW}Repository has some minor deviations from the standard structure.${NC}"
  exit 0
else
  echo -e "\n${GREEN}Repository conforms to the standard structure!${NC}"
  exit 0
fi