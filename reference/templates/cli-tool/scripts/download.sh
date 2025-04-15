#!/usr/bin/env bash
#
# Script: download.sh
# Description: Downloads a CLI tool
#
# Usage: ./download.sh [options]
#
# Options:
#   -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
#   -v, --version VERSION         Tool version
#   -o, --output-dir DIRECTORY    Output directory (default: ./bin)
#   -u, --url URL                 Custom download URL
#   -h, --harbor HOSTNAME         Harbor registry hostname
#   -V, --verbose                 Enable verbose output
#   --help                        Show this help message
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions if available
source "${__DIR}/helpers.sh"

# Default values
TOOL_NAME=""
TOOL_VERSION=""
OUTPUT_DIR="./bin"
DOWNLOAD_URL=""
HARBOR_HOSTNAME=""
VERBOSE=false

# Function to display usage
function show_usage() {
  cat <<EOF
Script: download.sh
Description: Downloads a CLI tool

Usage: ./download.sh [options]

Options:
  -t, --tool TOOL_NAME          Tool name (e.g., tridentctl)
  -v, --version VERSION         Tool version
  -o, --output-dir DIRECTORY    Output directory (default: ./bin)
  -u, --url URL                 Custom download URL
  -h, --harbor HOSTNAME         Harbor registry hostname
  -V, --verbose                 Enable verbose output
  --help                        Show this help message
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tool)
      TOOL_NAME="$2"
      shift 2
      ;;
    -v|--version)
      TOOL_VERSION="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -u|--url)
      DOWNLOAD_URL="$2"
      shift 2
      ;;
    -h|--harbor)
      HARBOR_HOSTNAME="$2"
      shift 2
      ;;
    -V|--verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_usage
      ;;
    *)
      error "Unknown option: $1"
      show_usage
      ;;
  esac
done

# Enable verbose output if requested
if [[ "${VERBOSE}" == "true" ]]; then
  set -x
fi

# Validate required arguments
if [[ -z "${TOOL_NAME}" ]]; then
  error "Tool name not specified. Use -t or --tool option."
  show_usage
fi

if [[ -z "${TOOL_VERSION}" ]]; then
  error "Tool version not specified. Use -v or --version option."
  show_usage
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Download the CLI tool based on its name
case "${TOOL_NAME}" in
  "tridentctl")
    info "Downloading tridentctl version ${TOOL_VERSION}"
    
    if [[ -n "${DOWNLOAD_URL}" ]]; then
      # Use provided download URL
      curl -L -o "${OUTPUT_DIR}/trident-installer-${TOOL_VERSION}.tar.gz" "${DOWNLOAD_URL}"
    else
      # Use default download URL
      curl -L -o "${OUTPUT_DIR}/trident-installer-${TOOL_VERSION}.tar.gz" \
        "https://github.com/NetApp/trident/releases/download/v${TOOL_VERSION}/trident-installer-${TOOL_VERSION}.tar.gz"
    fi
    
    tar -xzf "${OUTPUT_DIR}/trident-installer-${TOOL_VERSION}.tar.gz" -C "${OUTPUT_DIR}"
    
    # Copy tridentctl to the output directory
    cp "${OUTPUT_DIR}/trident-installer/tridentctl" "${OUTPUT_DIR}/"
    chmod +x "${OUTPUT_DIR}/tridentctl"
    
    # Clean up
    rm -rf "${OUTPUT_DIR}/trident-installer-${TOOL_VERSION}.tar.gz"
    ;;
    
  "istioctl")
    info "Downloading istioctl version ${TOOL_VERSION}"
    
    if [[ -n "${DOWNLOAD_URL}" ]]; then
      # Use provided download URL
      curl -L "${DOWNLOAD_URL}" | ISTIO_VERSION="${TOOL_VERSION}" sh -
    else
      # Use default download URL
      curl -L https://istio.io/downloadIstio | ISTIO_VERSION="${TOOL_VERSION}" sh -
    fi
    
    # Copy istioctl to the output directory
    cp "istio-${TOOL_VERSION}/bin/istioctl" "${OUTPUT_DIR}/"
    chmod +x "${OUTPUT_DIR}/istioctl"
    
    # Clean up
    rm -rf "istio-${TOOL_VERSION}"
    ;;
    
  *)
    # For other tools, try using the provided download URL
    if [[ -z "${DOWNLOAD_URL}" ]]; then
      error "Download URL is required for tool: ${TOOL_NAME}"
      exit 1
    fi
    
    info "Downloading ${TOOL_NAME} version ${TOOL_VERSION} from ${DOWNLOAD_URL}"
    curl -L -o "${OUTPUT_DIR}/${TOOL_NAME}" "${DOWNLOAD_URL}"
    chmod +x "${OUTPUT_DIR}/${TOOL_NAME}"
    ;;
esac

# Verify the tool was downloaded successfully
if [[ -f "${OUTPUT_DIR}/${TOOL_NAME}" ]]; then
  success "Tool ${TOOL_NAME} v${TOOL_VERSION} downloaded successfully to ${OUTPUT_DIR}/${TOOL_NAME}"
else
  error "Failed to download ${TOOL_NAME}"
  exit 1
fi

# Add the tool to PATH and try to get its version
export PATH="${OUTPUT_DIR}:${PATH}"
info "Verifying ${TOOL_NAME} version:"
${TOOL_NAME} version 2>/dev/null || ${TOOL_NAME} --version 2>/dev/null || echo "Note: ${TOOL_NAME} does not support version checking"