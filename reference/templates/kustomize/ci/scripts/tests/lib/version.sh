#!/usr/bin/env bash

# Enable strict mode
set -o errexit
set -o pipefail
# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
#
# Version Normalization Helper Module
#
# This module standardizes version formatting, providing consistent version handling
# across different formats and special cases.
#
# The main function removes common prefixes and handles special version labels.
#
# Usage:
#   VERSION=$(normalize_version "$VERSION")
#
# Returns:
#   A standardized version string
function normalize_version() {
    local VERSION=$1
    
    if [[ $VERSION =~ release-v* ]]; then
        VERSION="${VERSION##*release-v}"
    elif [[ $VERSION = v* ]]; then
        VERSION="${VERSION##*v}"
    fi

    if [[ $VERSION = "latest" ]]; then
        VERSION="$(get_latest_version)"
    fi
    
    echo "$VERSION"
}
