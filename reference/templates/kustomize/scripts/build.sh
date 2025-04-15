#!/usr/bin/env bash
#
# Script: build.sh
# Description: Builds Kubernetes resources using kustomize
#
# Usage: ./build.sh [options]
#
# Options:
#   -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
#   -c, --config PATH             Path to configuration directory
#   -o, --output PATH             Path to output directory (default: ./build)
#   -v, --verbose                 Enable verbose output
#   -h, --help                    Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd "${__DIR}/.." &>/dev/null && pwd)"

# Source common functions if available
HELPERS="${__DIR}/helpers.sh"
if [[ -f "${HELPERS}" ]]; then
  source "${HELPERS}"
fi

# Default values
FOUNDATION=""
CONFIG_PATH=""
OUTPUT_DIR="${REPO_ROOT}/build"
VERBOSE=false

# Function to display usage
function show_usage() {
  cat <<EOF
Script: build.sh
Description: Builds Kubernetes resources using kustomize

Usage: ./build.sh [options]

Options:
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -c, --config PATH             Path to configuration directory
  -o, --output PATH             Path to output directory (default: ./build)
  -v, --verbose                 Enable verbose output
  -h, --help                    Show this help message
EOF
  exit 1
}

# Function to log messages
function log() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[${timestamp}] $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--foundation)
      FOUNDATION="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      echo "Error: Unknown option: $1"
      show_usage
      ;;
  esac
done

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

# Validate required arguments
if [[ -z "${FOUNDATION}" ]]; then
  echo "Error: Foundation name not specified. Use -f or --foundation option."
  show_usage
fi

if [[ -z "${CONFIG_PATH}" ]]; then
  echo "Error: Configuration path not specified. Use -c or --config option."
  show_usage
fi

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Main function to build resources
function build_resources() {
  log "Building resources for foundation: ${FOUNDATION}"
  log "Using configuration from: ${CONFIG_PATH}"
  log "Output will be written to: ${OUTPUT_DIR}"

  # Check if kustomize is installed
  if ! command -v kustomize &> /dev/null; then
    echo "Error: kustomize command not found"
    echo "Please install kustomize: https://kubectl.docs.kubernetes.io/installation/kustomize/"
    exit 1
  fi

  # Determine kustomize base directory
  KUSTOMIZE_DIR="${REPO_ROOT}/overlays/${FOUNDATION}"
  if [[ ! -d "${KUSTOMIZE_DIR}" ]]; then
    echo "Error: Kustomize directory not found: ${KUSTOMIZE_DIR}"
    echo "Available overlay directories:"
    find "${REPO_ROOT}/overlays" -type d -maxdepth 1 -mindepth 1 -exec basename {} \; | sort
    exit 1
  fi

  # Run kustomize build
  log "Running kustomize build..."
  kustomize build "${KUSTOMIZE_DIR}" > "${OUTPUT_DIR}/manifests.yaml"
  
  # Check if build was successful
  if [[ $? -eq 0 ]]; then
    log "Kustomize build completed successfully"
    log "Generated manifests saved to: ${OUTPUT_DIR}/manifests.yaml"
  else
    log "Kustomize build failed"
    exit 1
  fi
}

# Execute the build function
build_resources