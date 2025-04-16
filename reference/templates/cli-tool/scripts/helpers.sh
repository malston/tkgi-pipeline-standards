#
# Script: helpers.sh
# Description: Helper functions for CLI tool scripts
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

# Function to check if a command exists
function check_command_exists() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    error "Command not found: $cmd"
    return 1
  fi
  return 0
}

# Function to get cluster information
function get_cluster_external_hostname() {
  local cluster_file="$1"

  # Try to parse the cluster file using Python or jq
  if command -v python &>/dev/null; then
    python -c "import yaml,sys;print(yaml.safe_load(open('$cluster_file'))['external_hostname'])"
  elif command -v jq &>/dev/null; then
    grep 'external_hostname' "$cluster_file" | cut -d':' -f2 | tr -d ' '
  else
    error "Neither python nor jq is available to parse the cluster file"
    return 1
  fi
}

# Function to determine if YAML file exists
function check_yaml_file_exists() {
  local file_path="$1"

  if [[ -f "${file_path}" ]]; then
    echo "${file_path}"
    return 0
  elif [[ -f "${file_path}.yaml" ]]; then
    echo "${file_path}.yaml"
    return 0
  elif [[ -f "${file_path}.yml" ]]; then
    echo "${file_path}.yml"
    return 0
  else
    return 1
  fi
}

# Function to get desired clusters from a foundation
function get_desired_clusters() {
  local foundation="$1"
  local config_repo_path="$2"
  local clusters_file="${config_repo_path}/foundations/${foundation}/clusters.yml"

  # Check if clusters file exists
  if ! clusters_file=$(check_yaml_file_exists "$clusters_file"); then
    error "Clusters file not found at ${clusters_file}"
    return 1
  fi

  # Try to parse the clusters file using Python or jq
  if command -v python &>/dev/null; then
    python -c "import yaml,sys;print(' '.join([c['name'] for c in yaml.safe_load(open('$clusters_file'))['clusters']]))"
  elif command -v jq &>/dev/null; then
    jq -r '.clusters[].name' "$clusters_file" | tr '\n' ' '
  else
    # Fallback to grep and awk
    grep 'name:' "$clusters_file" | awk '{print $2}' | tr '\n' ' '
  fi
}

# Function to get all clusters in a foundation
function get_all_clusters() {
  local foundation="$1"
  local api_url="$2"
  local username="$3"
  local password="$4"

  # Check if tkgi command exists (preferred)
  if command -v tkgi &>/dev/null; then
    TKGI_CMD="tkgi"
  # Check if pks command exists (legacy)
  elif command -v pks &>/dev/null; then
    TKGI_CMD="pks"
  else
    error "Neither tkgi nor pks command found"
    return 1
  fi

  # Login to PKS/TKGi
  info "Logging into PKS/TKGi API at ${api_url}"
  $TKGI_CMD login -a "${api_url}" -u "${username}" -p "${password}" -k >/dev/null 2>&1

  # Get clusters
  $TKGI_CMD clusters --json | jq -r ".[] | select(.name | startswith(\"${foundation}\")) | .name" | tr '\n' ' '
}

# Function to format output as JSON
function output_json() {
  local data="$1"
  local output_file="$2"

  if [[ -z "$output_file" ]]; then
    echo "$data"
  else
    echo "$data" >"$output_file"
  fi
}

# Function to kubectl apply manifests with a specific pattern
function kubectl_apply_manifests() {
  local manifests_dir="$1"
  local pattern="${2:-*.yaml}"

  if [[ ! -d "$manifests_dir" ]]; then
    error "Manifests directory not found: $manifests_dir"
    return 1
  fi

  find "$manifests_dir" -name "$pattern" -print0 | while IFS= read -r -d '' manifest; do
    info "Applying manifest: $manifest"
    kubectl apply -f "$manifest"
  done
}
