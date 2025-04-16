#!/usr/bin/env bash

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
#
# Script: helpers.sh
# Description: Helper functions for Helm template scripts
#

# Function to validate if a file exists
function validate_file_exists() {
  local file_path="$1"
  local description="${2:-File}"
  
  if [[ ! -f "$file_path" ]]; then
    echo "Error: $description not found: $file_path"
    return 1
  fi
  
  return 0
}

# Function to validate if a directory exists
function validate_directory_exists() {
  local dir_path="$1"
  local description="${2:-Directory}"
  
  if [[ ! -d "$dir_path" ]]; then
    echo "Error: $description not found: $dir_path"
    return 1
  fi
  
  return 0
}

# Function to log info messages
function info() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[INFO] [${timestamp}] $1"
}

# Function to log error messages
function error() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[ERROR] [${timestamp}] $1" >&2
}

# Function to log success messages
function success() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[SUCCESS] [${timestamp}] $1"
}

# Function to log warning messages
function warning() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[WARNING] [${timestamp}] $1"
}

# Function to validate multiple environment variables are set
function validate_env() {
  local missing=false
  
  for var_name in "$@"; do
    if [[ -z "${!var_name}" ]]; then
      error "Required environment variable not set: $var_name"
      missing=true
    fi
  done
  
  if [[ "$missing" == "true" ]]; then
    return 1
  fi
  
  return 0
}

# Function to check if a command exists
function check_command_exists() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    error "Command not found: $cmd"
    return 1
  fi
  return 0
}

# Function to check if a variable is set
function check_variable_set() {
  local var_name="$1"
  local var_value="${!var_name}"
  
  if [[ -z "$var_value" ]]; then
    error "Required variable not set: $var_name"
    return 1
  fi
  return 0
}

# Function to get desired clusters from a foundation
function get_desired_clusters() {
  local foundation="$1"
  local config_repo_path="$2"
  local clusters_file="${config_repo_path}/foundations/${foundation}/clusters.yml"
  
  # Try to parse the clusters file using Python or jq
  if command -v python &> /dev/null; then
    python -c "import yaml,sys;print(' '.join([c['name'] for c in yaml.safe_load(open('$clusters_file'))['clusters']]))"
  elif command -v jq &> /dev/null; then
    jq -r '.clusters[].name' "$clusters_file" | tr '\n' ' '
  else
    # Fallback to grep and awk
    grep 'name:' "$clusters_file" | awk '{print $2}' | tr '\n' ' '
  fi
}

# Function to format output as JSON
function output_json() {
  local data="$1"
  local output_file="$2"
  
  if [[ -z "$output_file" ]]; then
    echo "$data"
  else
    echo "$data" > "$output_file"
  fi
}

# Function to set up TKGI credentials from previous step
function setup_tkgi_credentials() {
  if [[ -f "pks-config/credentials" ]]; then
    info "Loading TKGI credentials from pks-config/credentials"
    # shellcheck disable=SC1091
    source pks-config/credentials
    
    # Set TLS verification flag
    SKIP_TLS_VERIFICATION="${SKIP_TLS_VERIFICATION:-false}"
    TLS_VERIFICATION=""
    if [[ "$SKIP_TLS_VERIFICATION" == "true" ]]; then
      TLS_VERIFICATION="-k"
    fi
    
    # Login to TKGI
    info "Logging into TKGI API: $pks_api_url"
    if ! tkgi login -a "$pks_api_url" -u "$pks_user" -p "$pks_password" $TLS_VERIFICATION; then
      error "Failed to log in to TKGI API"
      exit 1
    fi
    
    # If cluster is specified, get credentials
    if [[ -n "$CLUSTER" ]]; then
      info "Getting Kubernetes credentials for cluster: $CLUSTER"
      if ! tkgi get-credentials "$CLUSTER"; then
        error "Failed to get credentials for cluster: $CLUSTER"
        exit 1
      fi
    fi
  else
    warning "No TKGI credentials found, assuming direct kubectl access"
  fi
}

# Function to create a namespace if it doesn't exist
function create_namespace_if_not_exists() {
  local namespace="$1"
  
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    info "Creating namespace: $namespace"
    kubectl create namespace "$namespace"
  else
    info "Namespace already exists: $namespace"
  fi
}

# Function to ensure Helm is installed and initialized
function ensure_helm() {
  if ! command -v helm &>/dev/null; then
    error "Helm is not installed"
    exit 1
  fi
  
  info "Using Helm version: $(helm version --short)"
}
