#!/usr/bin/env bash
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