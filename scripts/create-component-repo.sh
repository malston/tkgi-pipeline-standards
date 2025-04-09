#!/usr/bin/env bash
#
# create-component-repo.sh
#
# A tool to create a new component repository with the standardized structure
# for TKGI component installation repositories.
#
# This script is part of the tkgi-pipeline-standards repository and creates
# a new repository that follows the standardized structure.
#
# Usage: ./create-component-repo.sh <component-name> [target-dir]

set -eo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display usage
function usage() {
  cat <<EOF
Usage: $0 <component-name> [target-dir]

Create a new component repository with the standardized structure.

Arguments:
  component-name    Name of the component (e.g., gatekeeper, istio)
  target-dir        Target directory (default: ./<component-name>)

Examples:
  $0 gatekeeper
  $0 istio ~/repos/istio
EOF
  exit 1
}

# Check if component name was provided
if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error: Component name is required${NC}"
  usage
fi

COMPONENT_NAME="$1"
TARGET_DIR="${2:-${COMPONENT_NAME}}"

# Ensure target directory doesn't already exist
if [[ -d "$TARGET_DIR" ]]; then
  echo -e "${RED}Error: Target directory already exists: $TARGET_DIR${NC}"
  echo "Please choose a different target directory or remove the existing one."
  exit 1
fi

echo -e "${BLUE}Creating standardized repository for component: ${COMPONENT_NAME}${NC}"
echo -e "${BLUE}Target directory: ${TARGET_DIR}${NC}"

# Create the main directory structure
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Create all required directories
mkdir -p ci/pipelines
mkdir -p ci/tasks/pre-install/scripts
mkdir -p ci/tasks/install/scripts
mkdir -p ci/tasks/post-install/scripts
mkdir -p ci/tasks/test/scripts
mkdir -p ci/vars
mkdir -p ci/helm
mkdir -p ci/lib
mkdir -p ci/cmds
mkdir -p scripts
mkdir -p release

# Create basic README.md
cat > README.md <<EOF
# ${COMPONENT_NAME}

Repository for managing the installation and lifecycle of ${COMPONENT_NAME} on TKGI clusters.

## Overview

This repository contains the Concourse pipelines, tasks, and scripts needed to install, upgrade, and manage ${COMPONENT_NAME} on TKGI clusters. It follows the standardized structure for component management repositories.

## Usage

### Local Development

```bash
# Set up a pipeline locally for development
./ci/fly.sh set-pipeline -t dev -p install -e dev

# Execute a task locally for testing
./ci/fly.sh execute-task -t dev -f ci/tasks/install/install.yml
```

### Release Process

```bash
# Create a new version release
./ci/fly.sh release-version -v 1.0.0 -m "Initial release" --tag

# Promote a pipeline to Ops Concourse
./ci/fly.sh promote-pipeline -p install -e prod -v 1.0.0 --ops-target ops-concourse
```

## Directory Structure

- \`ci/\`: CI-related files (pipelines, tasks, etc.)
- \`scripts/\`: Utility scripts (used both by CI and externally)
- \`release/\`: Pipeline release automation
EOF

# Create basic fly.sh script
cat > ci/fly.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Define script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CI_DIR="${SCRIPT_DIR}"

# Source shared libraries
source "${CI_DIR}/lib/common.sh"
source "${CI_DIR}/lib/validation.sh"

# Define usage
function usage() {
  cat <<USAGE
Usage: ./fly.sh COMMAND [options]

Standardized interface for component pipeline operations.

Commands:
  set-pipeline       Set or update a local pipeline
  destroy-pipeline   Remove a pipeline
  execute-task       Execute a single task locally
  promote-pipeline   Promote a pipeline to the Ops Concourse instance
  validate-pipeline  Validate pipeline configuration
  release-version    Create a new component version release
  login              Login to a Concourse instance
  help               Display this help message

Global Options:
  -t, --target       TARGET       Concourse target (required for Concourse operations)
  -d, --datacenter   DATACENTER   Datacenter (cml, cic)
  -f, --foundation   FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -v, --verbose                   Enable verbose output
  -h, --help                      Display help for the given command

Run './fly.sh COMMAND --help' for more information on a command.
USAGE
  exit 1
}

# Parse global options
VERBOSE=false
TARGET=""
DATACENTER=""
FOUNDATION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target)
      TARGET="$2"
      shift 2
      ;;
    -d|--datacenter)
      DATACENTER="$2"
      shift 2
      ;;
    -f|--foundation)
      FOUNDATION="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      break
      ;;
  esac
done

# Ensure we have a command
if [[ $# -lt 1 ]]; then
  echo "ERROR: No command specified"
  usage
fi

COMMAND="$1"
shift

# Validate target is set for commands that require it
CONCOURSE_COMMANDS=("set-pipeline" "destroy-pipeline" "execute-task" "promote-pipeline" "login")
if [[ " ${CONCOURSE_COMMANDS[*]} " =~ " ${COMMAND} " && -z "$TARGET" ]]; then
  echo "ERROR: Target not specified. Use -t or --target option."
  exit 1
fi

# Execute the appropriate command
case "$COMMAND" in
  set-pipeline)
    # Load the set-pipeline command implementation
    source "${CI_DIR}/cmds/set_pipeline.sh"
    cmd_set_pipeline "$@"
    ;;
  destroy-pipeline)
    source "${CI_DIR}/cmds/destroy_pipeline.sh"
    cmd_destroy_pipeline "$@"
    ;;
  execute-task)
    source "${CI_DIR}/cmds/execute_task.sh"
    cmd_execute_task "$@"
    ;;
  promote-pipeline)
    source "${CI_DIR}/cmds/promote_pipeline.sh"
    cmd_promote_pipeline "$@"
    ;;
  validate-pipeline)
    source "${CI_DIR}/cmds/validate_pipeline.sh"
    cmd_validate_pipeline "$@"
    ;;
  release-version)
    source "${CI_DIR}/cmds/release_version.sh"
    cmd_release_version "$@"
    ;;
  login)
    if [[ "$#" -ge 1 && "$1" == "--ops" ]]; then
      shift
      # Use Ops Concourse credentials if available
      if [[ -f "${REPO_ROOT}/release/ops-credentials.yml" ]]; then
        OPS_API=$(yq e '.concourse_api' "${REPO_ROOT}/release/ops-credentials.yml")
        echo "INFO: Logging in to Ops Concourse at: ${OPS_API}"
        fly -t "$TARGET" login -c "${OPS_API}"
      else
        echo "ERROR: Ops credentials file not found at: ${REPO_ROOT}/release/ops-credentials.yml"
        exit 1
      fi
    else
      # Regular login
      fly -t "$TARGET" login
    fi
    ;;
  help)
    usage
    ;;
  *)
    echo "ERROR: Unknown command: $COMMAND"
    usage
    ;;
esac
EOF

# Make fly.sh executable
chmod +x ci/fly.sh

# Create common.sh in ci/lib
cat > ci/lib/common.sh <<'EOF'
#!/usr/bin/env bash
# Common utility functions for fly.sh

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
function info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

function success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

function warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

function error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if command exists
function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for fly CLI
function check_fly() {
  if ! command_exists "fly"; then
    error "fly CLI not found. Please install Concourse fly CLI."
    exit 1
  fi
  
  # Check fly version
  local fly_version
  fly_version=$(fly --version 2>&1 | head -n 1)
  
  info "Using fly version: $fly_version"
}

# Ensure target exists and is logged in
function check_fly_target() {
  local target="$1"
  
  if ! fly targets | grep -q "$target"; then
    error "Target '$target' does not exist. Please login first."
    info "Try: ./fly.sh login -t $target"
    exit 1
  fi
  
  # Check if we need to relogin by attempting a simple fly command
  if ! fly -t "$target" containers &>/dev/null; then
    error "Session for target '$target' has expired. Please login again."
    info "Try: ./fly.sh login -t $target"
    exit 1
  fi
}
EOF

# Create validation.sh in ci/lib
cat > ci/lib/validation.sh <<'EOF'
#!/usr/bin/env bash
# Validation utility functions for fly.sh

# Validate that a file exists
function validate_file_exists() {
  local file_path="$1"
  local description="${2:-file}"
  
  if [[ ! -f "$file_path" ]]; then
    error "$description not found: $file_path"
    return 1
  fi
  
  return 0
}

# Validate that a directory exists
function validate_directory_exists() {
  local dir_path="$1"
  local description="${2:-directory}"
  
  if [[ ! -d "$dir_path" ]]; then
    error "$description not found: $dir_path"
    return 1
  fi
  
  return 0
}

# Validate that a variable is not empty
function validate_not_empty() {
  local var_value="$1"
  local var_name="$2"
  
  if [[ -z "$var_value" ]]; then
    error "$var_name must not be empty"
    return 1
  fi
  
  return 0
}

# Validate semver format
function validate_semver() {
  local version="$1"
  
  if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$ ]]; then
    error "Invalid version format: $version. Must be a valid semver (e.g., 1.2.3)"
    return 1
  fi
  
  return 0
}

# Validate environment name
function validate_environment() {
  local env="$1"
  
  if [[ ! "$env" =~ ^(dev|stage|prod)$ ]]; then
    error "Invalid environment: $env. Must be one of: dev, stage, prod"
    return 1
  fi
  
  return 0
}
EOF

# Create a placeholder set-pipeline.sh command
cat > ci/cmds/set_pipeline.sh <<'EOF'
#!/usr/bin/env bash
# Command implementation for set-pipeline

function cmd_set_pipeline_usage() {
  cat <<EOF_USAGE
Usage: ./fly.sh set-pipeline [options]

Set or update a pipeline in Concourse.

Options:
  -p, --pipeline  PIPELINE    Pipeline name (required)
  -e, --env       ENV         Environment (dev, stage, prod)
  -n, --non-interactive      Non-interactive mode
  -h, --help                  Display this help message

Examples:
  ./fly.sh set-pipeline -t dev -p install -e dev
  ./fly.sh set-pipeline -t dev -p upgrade -e stage -n
EOF_USAGE
  exit 1
}

function cmd_set_pipeline() {
  check_fly

  local pipeline=""
  local non_interactive=false

  # Parse command-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--pipeline)
        pipeline="$2"
        shift 2
        ;;
      -n|--non-interactive)
        non_interactive=true
        shift
        ;;
      -h|--help)
        cmd_set_pipeline_usage
        ;;
      *)
        error "Unknown option: $1"
        cmd_set_pipeline_usage
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$pipeline" ]]; then
    error "Pipeline name not specified. Use -p or --pipeline option."
    cmd_set_pipeline_usage
  fi
  
  # Validate the environment
  validate_environment "$ENVIRONMENT"
  
  # Construct pipeline file path
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
  
  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    exit 1
  fi
  
  # Construct vars file path
  local vars_file="${CI_DIR}/vars/${ENVIRONMENT}.yml"
  
  # Check if vars file exists
  if ! validate_file_exists "$vars_file" "Variables file"; then
    info "Using empty vars file set"
  fi
  
  # Construct the fly command
  local cmd=(
    "fly" "-t" "$TARGET" "set-pipeline"
    "-p" "${pipeline}"
    "-c" "${pipeline_file}"
  )
  
  # Add vars file if it exists
  if [[ -f "$vars_file" ]]; then
    cmd+=("-l" "${vars_file}")
  fi
  
  # Add common vars file if it exists
  if [[ -f "${CI_DIR}/vars/common.yml" ]]; then
    cmd+=("-l" "${CI_DIR}/vars/common.yml")
  fi
  
  # Add non-interactive flag if specified
  if [[ "$non_interactive" == "true" ]]; then
    cmd+=("-n")
  fi
  
  # Log the command in verbose mode
  if [[ "$VERBOSE" == "true" ]]; then
    info "Executing: ${cmd[*]}"
  fi
  
  # Execute the command
  "${cmd[@]}"
  
  success "Pipeline '${pipeline}' set successfully"
}
EOF

# Create basic example pipeline
cat > ci/pipelines/install.yml <<EOF
---
# Sample installation pipeline for ${COMPONENT_NAME}

resources:
  - name: component-repo
    type: git
    source:
      uri: ((git_repo_uri))
      branch: main

  - name: helm-chart
    type: helm-release
    source:
      repository_url: ((chart_repo_url))
      chart: ((chart_name))
      version_constraint: ((chart_version_constraint))

jobs:
  - name: validate-cluster
    plan:
      - get: component-repo
        trigger: true
      - task: validate-cluster
        file: component-repo/ci/tasks/pre-install/validate-cluster.yml
        params:
          KUBECONFIG: ((kubeconfig))
          NAMESPACE: ((namespace))
          ENVIRONMENT: ((environment))

  - name: install-component
    plan:
      - get: component-repo
        passed: [validate-cluster]
        trigger: true
      - get: helm-chart
        trigger: true
      - task: install-component
        file: component-repo/ci/tasks/install/install.yml
        params:
          KUBECONFIG: ((kubeconfig))
          NAMESPACE: ((namespace))
          COMPONENT_NAME: ((component_name))
          ENVIRONMENT: ((environment))
          RELEASE_NAME: ((release_name))
          VALUES_PATH: component-repo/ci/helm/values-((environment)).yaml
EOF

# Create dev vars file
cat > ci/vars/dev.yml <<EOF
# Development environment variables
environment: dev
component_name: ${COMPONENT_NAME}
namespace: ${COMPONENT_NAME}-system
chart_name: ${COMPONENT_NAME}
chart_repo_url: https://example.com/helm-charts
chart_version_constraint: ~1.0.x
release_name: ${COMPONENT_NAME}
EOF

# Create basic Helm values
cat > ci/helm/base-values.yaml <<EOF
# Base values for ${COMPONENT_NAME}
nameOverride: ${COMPONENT_NAME}
fullnameOverride: ${COMPONENT_NAME}

image:
  repository: example.com/${COMPONENT_NAME}
  tag: latest

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
EOF

cat > ci/helm/values-dev.yaml <<EOF
# Development environment values
replicaCount: 1

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
EOF

# Create versions file
cat > release/versions.yml <<EOF
${COMPONENT_NAME}:
  version: "0.1.0-dev"
  date: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  message: "Initial repository structure"
  promotions: {}
EOF

# Create utility script examples
cat > scripts/helm-helpers.sh <<'EOF'
#!/usr/bin/env bash
# scripts/helm-helpers.sh
#
# A set of Helm-related utility functions that can be used both:
# 1. By CI tasks during pipeline execution
# 2. By operators running commands outside the pipeline
#
# Usage: source scripts/helm-helpers.sh

# Verify Helm is installed and return version
function verify_helm() {
  if ! command -v helm &> /dev/null; then
    echo "Helm is not installed or not in PATH" >&2
    return 1
  fi
  
  local helm_version
  helm_version=$(helm version --short 2>/dev/null)
  echo "$helm_version"
}

# Add a Helm repository if it doesn't exist already
function ensure_helm_repo() {
  local repo_name="$1"
  local repo_url="$2"
  
  if ! helm repo list 2>/dev/null | grep -q "^$repo_name"; then
    echo "Adding Helm repository: $repo_name ($repo_url)"
    helm repo add "$repo_name" "$repo_url"
    helm repo update
  else
    # Update the repo URL if it has changed
    local current_url
    current_url=$(helm repo list | grep "^$repo_name" | awk '{print $2}')
    
    if [[ "$current_url" != "$repo_url" ]]; then
      echo "Updating Helm repository URL: $repo_name ($current_url -> $repo_url)"
      helm repo remove "$repo_name"
      helm repo add "$repo_name" "$repo_url"
      helm repo update
    fi
  fi
}

# Check if a Helm release exists and is in a successful state
function check_release_status() {
  local release_name="$1"
  local namespace="${2:-default}"
  
  if ! helm status -n "$namespace" "$release_name" &>/dev/null; then
    return 1  # Release does not exist
  fi
  
  # Get status
  local status
  status=$(helm status -n "$namespace" "$release_name" -o json | jq -r '.info.status')
  
  if [[ "$status" == "deployed" ]]; then
    return 0  # Success
  else
    return 2  # Release exists but is not in deployed status
  fi
}
EOF

# Create kubernetes helper functions
cat > scripts/kubernetes-helpers.sh <<'EOF'
#!/usr/bin/env bash
# scripts/kubernetes-helpers.sh
#
# A set of Kubernetes-related utility functions that can be used both:
# 1. By CI tasks during pipeline execution
# 2. By operators running commands outside the pipeline
#
# Usage: source scripts/kubernetes-helpers.sh

# Setup kubectl with a provided kubeconfig
function setup_kubeconfig() {
  local kubeconfig_content="$1"
  
  if [[ -z "$kubeconfig_content" ]]; then
    echo "ERROR: No kubeconfig content provided" >&2
    return 1
  fi
  
  # Create temporary kubeconfig file
  local kubeconfig_file
  kubeconfig_file=$(mktemp)
  
  echo "$kubeconfig_content" > "$kubeconfig_file"
  chmod 600 "$kubeconfig_file"
  
  # Set KUBECONFIG environment variable
  export KUBECONFIG="$kubeconfig_file"
  
  echo "Kubeconfig set up at: $kubeconfig_file"
}

# Check if kubectl can connect to the cluster
function check_kubernetes_connection() {
  if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: Unable to connect to Kubernetes cluster" >&2
    return 1
  fi
  
  echo "Successfully connected to Kubernetes cluster"
  return 0
}

# Create a namespace if it doesn't exist
function create_namespace_if_not_exists() {
  local namespace="$1"
  
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    echo "Creating namespace: $namespace"
    kubectl create namespace "$namespace"
  else
    echo "Namespace already exists: $namespace"
  fi
}

# Wait for a deployment to be ready
function wait_for_deployment() {
  local deployment="$1"
  local namespace="${2:-default}"
  local timeout="${3:-300s}"
  
  echo "Waiting for deployment $deployment in namespace $namespace to be ready (timeout: $timeout)"
  if ! kubectl rollout status deployment "$deployment" -n "$namespace" --timeout="$timeout"; then
    echo "ERROR: Deployment $deployment not ready within timeout" >&2
    return 1
  fi
  
  echo "Deployment $deployment is ready"
  return 0
}

# Get pod logs for a given label selector
function get_pods_by_label() {
  local label="$1"
  local namespace="${2:-default}"
  
  kubectl get pods -n "$namespace" -l "$label" -o wide
}

# Check if a CRD exists
function check_crd_exists() {
  local crd="$1"
  
  if kubectl get crd "$crd" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Apply a Kubernetes manifest file
function apply_manifest() {
  local manifest_file="$1"
  local namespace="${2:-}"
  
  if [[ ! -f "$manifest_file" ]]; then
    echo "ERROR: Manifest file not found: $manifest_file" >&2
    return 1
  fi
  
  local cmd=("kubectl" "apply" "-f" "$manifest_file")
  
  if [[ -n "$namespace" ]]; then
    cmd+=("-n" "$namespace")
  fi
  
  echo "Applying manifest: $manifest_file"
  "${cmd[@]}"
}
EOF

# Create install task
cat > ci/tasks/install/install.yml <<'EOF'
---
platform: linux

image_resource:
  type: registry-image
  source:
    repository: registry.example.com/helm-kubectl
    tag: latest

inputs:
  - name: component-repo
  - name: helm-chart

outputs:
  - name: installation-result

params:
  KUBECONFIG:
  NAMESPACE:
  COMPONENT_NAME:
  ENVIRONMENT:
  RELEASE_NAME:
  CHART_NAME:
  CHART_VERSION:
  VALUES_PATH:
  OVERRIDE_VALUES_PATH:
  CHART_REPO_URL:
  CHART_REPO_NAME:
  HELM_TIMEOUT: 10m
  DEBUG: false
  DRY_RUN: false

run:
  path: component-repo/ci/tasks/install/scripts/install.sh
EOF

# Create a sample install script
cat > ci/tasks/install/scripts/install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Setup debugging if enabled
if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

# Root of the repository after checking it out in the CI pipeline
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Source helper scripts from the scripts directory
source "${REPO_ROOT}/scripts/helm-helpers.sh"
source "${REPO_ROOT}/scripts/kubernetes-helpers.sh"

echo "Starting component installation process"

# Ensure required environment variables are set
required_vars=("NAMESPACE" "COMPONENT_NAME" "ENVIRONMENT" "RELEASE_NAME" "CHART_NAME")
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required variable $var is not set"
    exit 1
  fi
done

# Configure kubectl with the provided kubeconfig if given
if [[ -n "${KUBECONFIG:-}" ]]; then
  setup_kubeconfig "${KUBECONFIG}"
fi

# Validate cluster connection
echo "Validating cluster connection"
check_kubernetes_connection

# Validate namespace
echo "Ensuring namespace ${NAMESPACE} exists"
create_namespace_if_not_exists "${NAMESPACE}"

# Set up Helm repository if specified
if [[ -n "${CHART_REPO_URL:-}" && -n "${CHART_REPO_NAME:-}" ]]; then
  ensure_helm_repo "${CHART_REPO_NAME}" "${CHART_REPO_URL}"
  CHART="${CHART_REPO_NAME}/${CHART_NAME}"
else
  CHART="${CHART_NAME}"
fi

# Determine Values file path
VALUES_FILE=""
if [[ -n "${VALUES_PATH:-}" && -f "${VALUES_PATH}" ]]; then
  VALUES_FILE="${VALUES_PATH}"
elif [[ -f "${REPO_ROOT}/ci/helm/values-${ENVIRONMENT}.yaml" ]]; then
  VALUES_FILE="${REPO_ROOT}/ci/helm/values-${ENVIRONMENT}.yaml"
else
  echo "ERROR: No values file specified or found for environment ${ENVIRONMENT}"
  exit 1
fi

# Construct the Helm command
HELM_CMD="helm upgrade --install ${RELEASE_NAME} ${CHART} \
  --namespace ${NAMESPACE} \
  --values ${VALUES_FILE} \
  --atomic \
  --timeout ${HELM_TIMEOUT}"

# Add version if specified
if [[ -n "${CHART_VERSION:-}" ]]; then
  HELM_CMD="${HELM_CMD} --version ${CHART_VERSION}"
fi

# Add dry-run flag if specified
if [[ "${DRY_RUN}" == "true" ]]; then
  HELM_CMD="${HELM_CMD} --dry-run"
fi

# Execute the Helm command
echo "Executing: ${HELM_CMD}"
eval "${HELM_CMD}"

echo "Component installation completed successfully"

# Create output directory for metadata
mkdir -p installation-result

# Save installation metadata
cat > installation-result/metadata.json <<META_EOF
{
  "component": "${COMPONENT_NAME}",
  "environment": "${ENVIRONMENT}",
  "namespace": "${NAMESPACE}",
  "release": "${RELEASE_NAME}",
  "chart": "${CHART_NAME}",
  "installation_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
META_EOF
EOF

# Make scripts executable
chmod +x ci/tasks/install/scripts/install.sh
chmod +x scripts/helm-helpers.sh
chmod +x scripts/kubernetes-helpers.sh

# Create a validate-cluster task
cat > ci/tasks/pre-install/validate-cluster.yml <<'EOF'
---
platform: linux

image_resource:
  type: registry-image
  source:
    repository: registry.example.com/kubectl
    tag: latest

inputs:
  - name: component-repo

params:
  KUBECONFIG:
  NAMESPACE:
  CLUSTER_NAME:
  ENVIRONMENT:
  MIN_NODE_COUNT: 3
  MIN_CPU: 2
  MIN_MEMORY: 4Gi

run:
  path: component-repo/ci/tasks/pre-install/scripts/validate-cluster.sh
EOF

cat > ci/tasks/pre-install/scripts/validate-cluster.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Root of the repository after checking it out in the CI pipeline
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Source helper scripts from the scripts directory
source "${REPO_ROOT}/scripts/kubernetes-helpers.sh"

echo "Validating cluster for component installation"

# Configure kubectl with the provided kubeconfig
if [[ -n "${KUBECONFIG:-}" ]]; then
  setup_kubeconfig "${KUBECONFIG}"
fi

# Validate cluster connection
echo "Validating connection to cluster: ${CLUSTER_NAME:-unknown}"
check_kubernetes_connection

# Check namespace exists or can be created
echo "Checking namespace: ${NAMESPACE}"
if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  echo "Namespace ${NAMESPACE} already exists"
else
  echo "Namespace ${NAMESPACE} does not exist, will be created during installation"
fi

# Check node count
NODE_COUNT=$(kubectl get nodes -o name | wc -l)
echo "Cluster has ${NODE_COUNT} nodes"

if [[ ${NODE_COUNT} -lt ${MIN_NODE_COUNT} ]]; then
  echo "ERROR: Cluster has insufficient nodes (${NODE_COUNT} < ${MIN_NODE_COUNT})"
  exit 1
fi

echo "Cluster validation completed successfully"
EOF

chmod +x ci/tasks/pre-install/scripts/validate-cluster.sh

# Final message
echo
echo -e "${GREEN}Repository structure created successfully for ${COMPONENT_NAME}!${NC}"
echo -e "${BLUE}Location: ${TARGET_DIR}${NC}"
echo
echo "Next steps:"
echo "1. Initialize git repository:"
echo "   cd ${TARGET_DIR} && git init && git add . && git commit -m 'Initial repository structure'"
echo "2. Push to your git repository"
echo "3. Set up your first pipeline:"
echo "   cd ${TARGET_DIR} && ./ci/fly.sh set-pipeline -t dev -p install -e dev"
echo

EOF
EOF