#!/usr/bin/env bash
#
# Foundation Environment Detection Helper Module
#
# This module determines the appropriate environment type, GitHub organization,
# and configuration repository name based on the foundation's datacenter prefix.
#
# The main function maps foundation datacenter codes (cml, temr, oxdc, etc.)
# to their corresponding environment types and repositories.
#
# Usage:
#   FOUNDATION_RESULT=$(determine_foundation_environment "$DC" "$ENVIRONMENT" "$GITHUB_ORG" "$CONFIG_REPO_NAME")
#   IFS=':' read -r ENVIRONMENT GITHUB_ORG CONFIG_REPO_NAME <<< "$FOUNDATION_RESULT"
#
# Returns:
#   A colon-separated string with ENVIRONMENT:GITHUB_ORG:CONFIG_REPO_NAME
function determine_foundation_environment() {
    local DC=$1
    local ENVIRONMENT=$2
    local GITHUB_ORG=$3
    local CONFIG_REPO_NAME=$4

    if [ -z "$ENVIRONMENT" ]; then
        case $DC in
        cic | cml)
            ENVIRONMENT="lab"
            if [ -z "$GITHUB_ORG" ]; then
                GITHUB_ORG="Utilities-tkgieng"
            fi
            if [ -z "$CONFIG_REPO_NAME" ]; then
                CONFIG_REPO_NAME=config-lab
            fi
            ;;
        temr | tmpe)
            ENVIRONMENT="nonprod"
            if [ -z "$GITHUB_ORG" ]; then
                GITHUB_ORG="Utilities-tkgiops"
            fi
            if [ -z "$CONFIG_REPO_NAME" ]; then
                CONFIG_REPO_NAME=config-nonprod
            fi
            ;;
        oxdc | svdc)
            ENVIRONMENT="prod"
            if [ -z "$GITHUB_ORG" ]; then
                GITHUB_ORG="Utilities-tkgiops"
            fi
            if [ -z "$CONFIG_REPO_NAME" ]; then
                CONFIG_REPO_NAME=config-prod
            fi
            ;;
        esac
    fi

    case $ENVIRONMENT in
    lab)
        GIT_RELEASE_TAG=${GIT_RELEASE_TAG:-develop}
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

    echo "$ENVIRONMENT:$GITHUB_ORG:$CONFIG_REPO_NAME"
}
