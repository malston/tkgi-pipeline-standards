#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="${SCRIPT_DIR}/pipelines"

# Source repository helper functions if available
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
if [[ -f "${REPO_ROOT}/scripts/helpers.sh" ]]; then
  source "${REPO_ROOT}/scripts/helpers.sh"
fi

usage() {
  echo "Usage: $0 -t TARGET [-p PIPELINE] [-f FOUNDATION] [-c CONFIG_REPO] [-v]"
  echo "  -t TARGET       Concourse target to use"
  echo "  -p PIPELINE     Pipeline to set (main or release)"
  echo "  -f FOUNDATION   Foundation to use (cml-k8s-n-01, etc.)"
  echo "  -c CONFIG_REPO  Path to config repository (default: ../config-lab)"
  echo "  -v              Verbose output"
  echo ""
  echo "Note: For more advanced options, use ci/scripts/fly.sh which provides additional functionality."
  exit 1
}

# Default values
PIPELINE="main"
FOUNDATION="cml-k8s-n-01"
CONFIG_REPO="../config-lab"
VERBOSE="false"

# Parse command line arguments
while getopts ":t:p:f:c:v" opt; do
  case ${opt} in
    t )
      TARGET=$OPTARG
      ;;
    p )
      PIPELINE=$OPTARG
      ;;
    f )
      FOUNDATION=$OPTARG
      ;;
    c )
      CONFIG_REPO=$OPTARG
      ;;
    v )
      VERBOSE="true"
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

if [[ -z "${TARGET}" ]]; then
  echo "Error: Concourse target (-t) is required."
  usage
fi

echo "Setting pipeline: ${PIPELINE} for foundation: ${FOUNDATION} using config: ${CONFIG_REPO}"

# Determine which DC the foundation belongs to
if [[ "${FOUNDATION}" == *"cml"* ]]; then
  DC="cml"
elif [[ "${FOUNDATION}" == *"cic"* ]]; then
  DC="cic"
else
  echo "Error: Could not determine DC from foundation name: ${FOUNDATION}"
  exit 1
fi

# Set pipeline
fly -t "${TARGET}" set-pipeline \
  -p "${PIPELINE}-${FOUNDATION}" \
  -c "${PIPELINE_DIR}/${PIPELINE}.yml" \
  -l "${CONFIG_REPO}/../params/${DC}/${FOUNDATION}.yml" \
  -l "${CONFIG_REPO}/../params/${DC}/${DC}-k8s.yml" \
  -l "${CONFIG_REPO}/../params/${DC}/${DC}.yml" \
  -l "${CONFIG_REPO}/../params/k8s-global.yml" \
  -l "${CONFIG_REPO}/../params/global.yml" \
  -v foundation="${FOUNDATION}" \
  -v foundation_path="${DC}/${FOUNDATION}" \
  -v verbose="${VERBOSE}"

echo "Pipeline ${PIPELINE}-${FOUNDATION} set successfully."