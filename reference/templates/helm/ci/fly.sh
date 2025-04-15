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
# Use realpath only if not in TEST_MODE
if [[ "${TEST_MODE}" != "true" ]]; then
    PARAMS_REPO="$(realpath "${REPO_ROOT}/../../../../params" 2>/dev/null || echo "/path/to/params")"
else
    PARAMS_REPO="/test/path/to/params"
fi
PARAMS_GIT_BRANCH="master"
BRANCH="develop"

usage() {
    cat <<EOF
Usage: $0 -f FOUNDATION [-p PIPELINE] [-t TARGET] [-P PARAMS_REPO] [-d PARAMS_BRANCH]
  -f FOUNDATION    Foundation to use (cml-k8s-n-01, etc.)
  -p PIPELINE      Pipeline to set (main or release)
  -t TARGET        Concourse target to use
  -P PARAMS_REPO   Path to params repository (default: $PARAMS_REPO)
  -d PARAMS_BRANCH Params git branch to use (default: $PARAMS_GIT_BRANCH)
  -b BRANCH        Branch to use (default: $BRANCH)

Note: For more advanced options, use ci/scripts/fly.sh which provides:
  - Command support (set, unpause, destroy, validate, release)
  - Command-specific help (try: scripts/fly.sh --help set)
  - Improved params handling
  - More configuration options

Run: ${SCRIPT_DIR}/scripts/fly.sh --help for full details
EOF
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

# Parse command line arguments
while getopts ":ht:b:p:f:P:d:" opt; do
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
    P)
        PARAMS_REPO=$OPTARG
        ;;
    d)
        PARAMS_GIT_BRANCH=$OPTARG
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

if [[ -z "${FOUNDATION}" ]]; then
    echo "Error: Foundation not specified"
    usage
    exit 1
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
    -v params_git_branch="${PARAMS_GIT_BRANCH}"

echo "Helm pipeline ${PIPELINE}-${FOUNDATION} set successfully."
