#!/usr/bin/env bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the helpers.sh file
source "$__DIR/helpers.sh"

PIPELINE="tkgi-ns-mgmt"
RELEASE_PIPELINE_NAME="$PIPELINE-release"
PIPELINE_FILE_TEMPLATE="$__DIR/pipelines/ns-mgmt.yml"
GITHUB_ORG="Utilities-tkgieng"
GIT_RELEASE_BRANCH="release"
CONFIG_GIT_BRANCH="master"
PARAMS_GIT_BRANCH="master"
VERSION_FILE="version"
VERSION="$(get_latest_version)"
CREATE_RELEASE=false
SET_RELEASE_PIPELINE=false
DRY_RUN=false
VERBOSE=false
ENABLE_VALIDATION_TESTING=false
ENVIRONMENT=""
TIMER_DURATION=3h

usage() {
    cat <<EOF
Usage:
    $0 -f <foundation> [-t <target>] [-e <environment>] [-b <git_branch>] [-c <config_git_branch>] [-p <pipeline_name>] [-r] [-s] [-v <version>] [-o <github_org>] [--enable-validation-testing]

Options:
   -f <foundation>          Sets the foundation to use for params, creds, etc.

   -t <target>              Sets the name of the concourse target to use. If omitted the foundation name will be used for the target. [default: <foundation>]

   -e <environment>         Sets the name of the environment. [default: (lab, nonprod, or prod) depending on the value of the foundation]

   -v <version>             Sets the version of the pipeline and release used by the pipeline. [default: $VERSION]

   -b <ns-mgmt git branch>  Sets the name of a git branch. [default: (environment == lab ? develop : master)]

   -c <config git branch>   Sets the name of a config repo git branch. [default: $CONFIG_GIT_BRANCH]

   -n <config repo name>    Sets the name of a config repo. [default: $CONFIG_REPO_NAME]

   -d <params git branch>   Sets the name of a params repo git branch. [default: $PARAMS_GIT_BRANCH]

   -o <github org>          Sets the github org from where to clone the config and ns-mgmt repos.

   -p <pipeline name>       Sets the pipeline name to use when flying pipeline. [default: $PIPELINE-<foundation>]

   -r                       Sets the release pipeline.

   -s                       Sets the set-release-pipeline, which when executed will set the $PIPELINE-<foundation> pipeline.

   --dry-run                Will only output the command that will be run when set to true (default: $DRY_RUN)

   --verbose                Will increase the amount of output from kustomize (default: $VERBOSE)

   --timer                  Sets the duration of the timer to trigger the jobs (default: $TIMER_DURATION)

   -h Help. Displays this message

Examples:
  Fly the pipeline on a branch for pipeline and a branch for the config repo (triggers everytime a config change is made and bumps the build version):
    $0 -f cml-k8s-n-08 -b BJSB-000-update-ns-mgmt -c BJSB-000-update-ns-mgmt

  Fly the 'release' pipeline (merges the develop branch into the release branch, bumps the build version to a final version, tags release with the final version):
    $0 -f cml-k8s-n-08 -r "Includes all the corrective action work."

  Fly the set-pipeline pipeline in a lab foundation:
  $0 -f cml-k8s-n-08 -s

  Fly the set-pipeline pipeline in a nonprod foundation:
  $0 -f temr-k8s-n-02 -s -e nonprod

  Fly the set-pipeline pipeline for nonprod in a lab foundation (in case you want to test a nonprod pipeline):
    $0 -f cml-k8s-n-08 -o Utilities-tkgieng -n config-lab -s -e nonprod
EOF
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
    case $1 in
    -f | --foundation)
        shift
        FOUNDATION=$1
        PIPELINE_NAME="$PIPELINE-$FOUNDATION"
        if [[ -z $TARGET ]]; then
            TARGET=$FOUNDATION
        fi
        ;;
    -t | --target)
        shift
        TARGET=$1
        ;;
    -p | --pipeline)
        shift
        PIPELINE_NAME=$1
        PIPELINE=$PIPELINE_NAME
        RELEASE_PIPELINE_NAME="$PIPELINE"
        ;;
    -o | --github-org)
        shift
        GITHUB_ORG=$1
        ;;
    -b | --branch)
        shift
        GIT_RELEASE_TAG=$1
        ;;
    -c | --config-branch)
        shift
        CONFIG_GIT_BRANCH=$1
        ;;
    -d | --params-branch)
        shift
        PARAMS_GIT_BRANCH=$1
        ;;
    -n | --config-repo-name)
        shift
        CONFIG_REPO_NAME=$1
        ;;
    -v | --version)
        shift
        VERSION=$1
        ;;
    -r | --release)
        if [[ $2 =~ ^- ]]; then
            RELEASE_BODY=""
        elif [ -n "$2" ]; then
            shift
            RELEASE_BODY=$1
        else
            shift
            RELEASE_BODY=$1
        fi
        CREATE_RELEASE=true
        ;;
    -s | --set-release-pipeline)
        if [[ $2 =~ ^- ]]; then
            SET_PIPELINE_NAME="$PIPELINE_NAME-set-release-pipeline"
        elif [ -n "$2" ]; then
            shift
            SET_PIPELINE_NAME="$1"
        else
            SET_PIPELINE_NAME="$PIPELINE_NAME-set-release-pipeline"
        fi
        SET_RELEASE_PIPELINE=true
        ;;
    -e | --environment)
        shift
        ENVIRONMENT=$1
        ;;
    --timer | --duration)
        shift
        TIMER_DURATION=$1
        ;;
    --dry-run)
        DRY_RUN=true
        ;;
    --enable-validation-testing)
        ENABLE_VALIDATION_TESTING=true
        ;;
    --verbose)
        VERBOSE=true
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    esac
    shift
done
if [[ "$1" == '--' ]]; then shift; fi

if [[ -z $FOUNDATION ]]; then
    echo "Missing -f <foundation>."
    echo ""
    usage
    exit 1
fi

DC=$(echo "$FOUNDATION" | awk -F- '{print $1}')
DCTYPE=$(echo "$FOUNDATION" | awk -F- '{print $2}')
FOUNDATION_PATH="foundations/$FOUNDATION"

if [[ -n $VERSION ]]; then
    if [[ $VERSION =~ release-v* ]]; then
        VERSION="${VERSION##*release-v}"
    elif [[ $VERSION = v* ]]; then
        VERSION="${VERSION##*v}"
    fi

    if [[ $VERSION = "latest" ]]; then
        VERSION="$(get_latest_version)"
    fi
fi

if [ -z "$ENVIRONMENT" ]; then
    case $DC in
    cic | cml)
        ENVIRONMENT="lab"
        CONFIG_REPO_NAME=config-lab
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
        GITHUB_ORG="Utilities-tkgiops"
        CONFIG_REPO_NAME=config-prod
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

GIT_URI="git@github.com:$GITHUB_ORG/ns-mgmt.git"
CONFIG_GIT_URI="git@github.com:$GITHUB_ORG/$CONFIG_REPO_NAME.git"

if [[ $CREATE_RELEASE = "true" ]]; then
    PIPELINE_FILE=$__DIR/pipelines/release.yml
    TARGET=tkgi-pipeline-upgrade
    fly -t "$TARGET" sp -p "$RELEASE_PIPELINE_NAME" -c "$PIPELINE_FILE" \
        -l "$HOME/git/params/global.yml" \
        -l "$HOME/git/params/$DC/$DC.yml" \
        -v git_uri="$GIT_URI" \
        -v git_release_branch="$GIT_RELEASE_BRANCH" \
        -v release_body="$RELEASE_BODY" \
        -v github_token="$GITHUB_TOKEN" \
        -v owner="$GITHUB_ORG" \
        -v version_file="$VERSION_FILE" \
        -v worker_tags="cml_mgt_tkgi_workers"

    pipeline_pause_check "$TARGET" "$RELEASE_PIPELINE_NAME" "$CONCOURSE_URL"

    fly -t "$TARGET" order-pipelines -a &>/dev/null

    exit
fi

if [ $SET_RELEASE_PIPELINE = "true" ]; then
    PIPELINE_FILE=$__DIR/pipelines/set-pipeline.yml
    fly -t "$TARGET" sp -p "$SET_PIPELINE_NAME" -c "$PIPELINE_FILE" \
        -v dc="$DC" \
        -v dc_type="$DCTYPE" \
        -l "$HOME/git/params/global.yml" \
        -l "$HOME/git/params/$DC/$DC.yml" \
        -l "$HOME/git/params/$DC/$DC-$DCTYPE.yml" \
        -l "$HOME/git/params/$DC/$FOUNDATION.yml" \
        -v owner="$GITHUB_ORG" \
        -v config_git_uri="$CONFIG_GIT_URI" \
        -v config_git_branch="$CONFIG_GIT_BRANCH" \
        -v params_git_branch="$PARAMS_GIT_BRANCH" \
        -v params_git_uri="git@github.com:$GITHUB_ORG/params.git" \
        -v release_pipeline_name="$PIPELINE_NAME" \
        -v pipeline="tkgi-ns-mgmt" \
        -v environment="$ENVIRONMENT" \
        -v foundation="$FOUNDATION" \
        -v foundation_path="$FOUNDATION_PATH" \
        -v test_cluster="cluster01"

    pipeline_pause_check "$TARGET" "$SET_PIPELINE_NAME" "$CONCOURSE_URL"

    fly -t "$TARGET" order-pipelines -a &>/dev/null

    exit
fi

PIPELINE_CONFIG_FILE=$(generate_pipeline_config "$PIPELINE_FILE_TEMPLATE" "$ENVIRONMENT" "$VERSION" "$ENABLE_VALIDATION_TESTING")

case $FOUNDATION in
cic-vxrail-n-01 | cic-vxrail-n-02 | cic-vxrail-n-03 | cic-vxrail-n-04 | cic-vxrail-n-05 | cic-vxrail-n-06)
    fly -t "$TARGET" sp -p "$PIPELINE_NAME" -c "$PIPELINE_CONFIG_FILE" \
        -l "$HOME/git/params/global.yml" \
        -l "$HOME/git/params/k8s-global.yml" \
        -l "$HOME/git/params/$DC/$DC.yml" \
        -l "$HOME/git/params/$DC/$DC-$DCTYPE.yml" \
        -l "$HOME/git/params/$DC/$FOUNDATION.yml" \
        -l "$HOME/git/creds/creds-global.yml" \
        -l "$HOME/git/creds/${DC}/creds-${DC}.yml" \
        -l "$HOME/git/creds/${DC}/creds-${DC}-${DCTYPE}.yml" \
        -l "$HOME/git/creds/${DC}/creds-${FOUNDATION}.yml" \
        -l "$HOME/git/creds/creds-git_repo_keys.yml" \
        -v foundation="$FOUNDATION" \
        -v test_cluster="cluster01" \
        -v git_uri="$GIT_URI" \
        -v git_release_tag="$GIT_RELEASE_TAG" \
        -v config_git_uri="$CONFIG_GIT_URI" \
        -v config_git_branch="$CONFIG_GIT_BRANCH" \
        -v dry_run="$DRY_RUN" \
        -v verbose="$VERBOSE" \
        -v timer_duration="$TIMER_DURATION" \
        -v foundation_path="$FOUNDATION_PATH"
    ;;
*)
    fly -t "$TARGET" sp -p "$PIPELINE_NAME" -c "$PIPELINE_CONFIG_FILE" \
        -l "$HOME/git/params/global.yml" \
        -l "$HOME/git/params/k8s-global.yml" \
        -l "$HOME/git/params/$DC/$DC.yml" \
        -l "$HOME/git/params/$DC/$DC-$DCTYPE.yml" \
        -l "$HOME/git/params/$DC/$FOUNDATION.yml" \
        -v foundation="$FOUNDATION" \
        -v test_cluster="cluster01" \
        -v git_uri="$GIT_URI" \
        -v git_release_tag="$GIT_RELEASE_TAG" \
        -v config_git_uri="$CONFIG_GIT_URI" \
        -v config_git_branch="$CONFIG_GIT_BRANCH" \
        -v dry_run="$DRY_RUN" \
        -v verbose="$VERBOSE" \
        -v timer_duration="$TIMER_DURATION" \
        -v foundation_path="$FOUNDATION_PATH"
    ;;
esac

printf "generated pipeline: %s\n\n" "$PIPELINE_CONFIG_FILE"

pipeline_pause_check "$TARGET" "$PIPELINE_NAME" "$CONCOURSE_URL"

fly -t "$TARGET" order-pipelines -a &>/dev/null
