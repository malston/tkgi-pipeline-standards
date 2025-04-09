#!/usr/bin/env bash
#
# Script: helpers.sh
# Description: Helper functions for repository scripts
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

# Function to parse YAML files using yq (if available)
function parse_yaml() {
  local yaml_file="$1"
  local yaml_path="$2"

  if ! check_command_exists "yq"; then
    error "yq command not found. Cannot parse YAML."
    return 1
  fi

  if ! validate_file_exists "$yaml_file" "YAML file"; then
    return 1
  fi

  yq eval "$yaml_path" "$yaml_file"
  return $?
}

# Function to update YAML files using yq (if available)
function update_yaml() {
  local yaml_file="$1"
  local yaml_path="$2"
  local yaml_value="$3"

  if ! check_command_exists "yq"; then
    error "yq command not found. Cannot update YAML."
    return 1
  fi

  if ! validate_file_exists "$yaml_file" "YAML file"; then
    return 1
  fi

  yq eval "$yaml_path = $yaml_value" -i "$yaml_file"
  return $?
}
