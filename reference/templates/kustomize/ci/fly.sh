#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="${SCRIPT_DIR}/pipelines"

# Source repository helper functions if available
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
if [[ -f "${REPO_ROOT}/scripts/helpers.sh" ]]; then
  source "${REPO_ROOT}/scripts/helpers.sh"
fi

# Default values
PIPELINE="main"
FOUNDATION=""
PARAMS_REPO="$(realpath "${REPO_ROOT}/../../../../params")"
BRANCH="develop"
VERBOSE="false"

usage() {
  echo "Usage: $0 -f FOUNDATION [-p PIPELINE] [-t TARGET] [-d PARAMS_REPO] [-v]"
  echo "  -f FOUNDATION   Foundation to use (cml-k8s-n-01, etc.)"
  echo "  -p PIPELINE     Pipeline to set (main or release)"
  echo "  -t TARGET       Concourse target to use"
  echo "  -d PARAMS_REPO  Path to config repository (default: $PARAMS_REPO)"
  echo "  -p BRANCH       Branch to use (default: $BRANCH)"
  echo "  -v              Verbose output"
  echo ""
  echo "Note: For more advanced options, use ci/scripts/fly.sh which provides:"
  echo "  - Command support (set, unpause, destroy, validate, release)"
  echo "  - Command-specific help (try: scripts/fly.sh --help set)"
  echo "  - Improved params handling"
  echo "  - More configuration options"
  echo ""
  echo "Run: ${SCRIPT_DIR}/scripts/fly.sh --help for full details"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

# Parse command line arguments
while getopts ":ht:b:p:f:d:v" opt; do
  case ${opt} in
  t)
    TARGET=$OPTARG
    ;;
  p)
    PIPELINE=$OPTARG
    ;;
  f)
    FOUNDATION=$OPTARG
    ;;
  b)
    BRANCH=$OPTARG
    ;;
  d)
    PARAMS_REPO=$OPTARG
    ;;
  v)
    VERBOSE="true"
    ;;
  h)
    usage
    exit 0
    ;;
  \?)
    echo "Invalid option: $OPTARG" 1>&2
    usage
    exit 1
    ;;
  :)
    echo "Invalid option: $OPTARG requires an argument" 1>&2
    usage
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "${TARGET}" ]]; then
  TARGET="${FOUNDATION}"
fi

# Determine which DC the foundation belongs to
DC=$(echo "${FOUNDATION}" | cut -d"-" -f1)
DCTYPE=$(echo "${FOUNDATION}" | cut -d"-" -f2)

# Set pipeline
fly -t "${TARGET}" set-pipeline \
  -p "${PIPELINE}-${FOUNDATION}" \
  -c "${PIPELINE_DIR}/${PIPELINE}.yml" \
  -l "${PARAMS_REPO}/${DC}/${FOUNDATION}.yml" \
  -l "${PARAMS_REPO}/${DC}/${DC}-${DCTYPE}.yml" \
  -l "${PARAMS_REPO}/${DC}/${DC}.yml" \
  -l "${PARAMS_REPO}/${DCTYPE}-global.yml" \
  -l "${PARAMS_REPO}/global.yml" \
  -v "branch=${BRANCH}" \
  -v foundation="${FOUNDATION}" \
  -v foundation_path="${DC}/${FOUNDATION}" \
  -v verbose="${VERBOSE}"

echo "Pipeline ${PIPELINE}-${FOUNDATION} set successfully."
