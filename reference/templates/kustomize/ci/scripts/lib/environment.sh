#!/usr/bin/env bash
#
# Environment Configuration Helper Module
#
# This module handles environment-specific configuration settings, providing
# consistent configuration based on the environment type (lab, nonprod, prod).
#
# The main function configures branch strategy, GitHub organization, and 
# config repository names appropriate for the given environment.
#
# Usage:
#   ENV_RESULT=$(configure_environment "$ENVIRONMENT" "$GIT_RELEASE_TAG" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
#   IFS=':' read -r GIT_RELEASE_TAG GITHUB_ORG CONFIG_REPO_NAME <<< "$ENV_RESULT"
#
# Returns:
#   A colon-separated string with GIT_RELEASE_TAG:GITHUB_ORG:CONFIG_REPO_NAME
configure_environment() {
    local ENVIRONMENT=$1
    local GIT_RELEASE_TAG=$2
    local GITHUB_ORG=$3
    local CONFIG_REPO_NAME=$4

    case $ENVIRONMENT in
    lab)
        GIT_RELEASE_TAG=${GIT_RELEASE_TAG:-develop}
        if [ -z "$GITHUB_ORG" ]; then
            GITHUB_ORG="Utilities-tkgieng"
        fi
        if [ -z "$CONFIG_REPO_NAME" ]; then
            CONFIG_REPO_NAME=config-lab
        fi
        ;;
    nonprod)
        GIT_RELEASE_TAG=${GIT_RELEASE_TAG:-master}
        if [ -z "$GITHUB_ORG" ]; then
            GITHUB_ORG="Utilities-tkgiops"
        fi
        if [ -z "$CONFIG_REPO_NAME" ]; then
            CONFIG_REPO_NAME=config-nonprod
        fi
        ;;
    prod)
        GIT_RELEASE_TAG=${GIT_RELEASE_TAG:-master}
        if [ -z "$GITHUB_ORG" ]; then
            GITHUB_ORG="Utilities-tkgiops"
        fi
        if [ -z "$CONFIG_REPO_NAME" ]; then
            CONFIG_REPO_NAME=config-prod
        fi
        ;;
    esac

    echo "$GIT_RELEASE_TAG:$GITHUB_ORG:$CONFIG_REPO_NAME"
}