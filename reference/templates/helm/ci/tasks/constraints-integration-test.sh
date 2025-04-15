#!/bin/bash

##
## This script will test all constraints to make sure they are working as
## expected
##

##
## Grab the "top-level" of the directory inside our task container
##
TOP_DIR=$(pwd)

##
## Source helpers.sh to grab all clusters in foundation later on
##
source ./gatekeeper-repo/scripts/helpers.sh || exit 1

##
## Color definitions
##
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NOCOLOR='\033[0m'

##
## Global variables
##
declare -a ERR_MESSAGES=()
declare HAS_ERRORS=false

##
## Log into the foundation once before we loop through the cluster(s)
##
ADMIN_PASSWORD=$(./gatekeeper-repo/scripts/common/login-pks.sh)
if [[ -z ${ADMIN_PASSWORD} ]]; then
    printf "${CLUSTER}:${RED} Error retrieving the pks admin password. Goodbye.${NOCOLOR}\n"
    exit 1
fi

printf "${BLUE}%s${NOCOLOR}\n" "####################################################################################"
printf "${YELLOW}%s: ${CYAN}%s${NOCOLOR}\n\n" "Testing starting" "Checking if each gatekeeper constraint works as expected."

##
## Get the list of clusters from the output of the cluster-create-delete task
##
for CLUSTER in $(get_desired_clusters "$FOUNDATION" "${TOP_DIR}/config-repo"); do
    ##
    ## Ensure you have created a directory to house your clusters files
    ##
    if [[ ! -d ${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER} ]]; then
        printf "${CLUSTER}:${RED} The following was in the clusters.yml file but did not have a corresponding directory defined${NOCOLOR}\n"
        printf "${CLUSTER}:${RED} Please add a directory for ${CLUSTER} before continuing${NOCOLOR}\n"
        continue
    fi

    ##
    ## If dry_run is set to true, then we will skip wiping istio on this cluster
    ##
    if [[ ${PIPELINE_DRY_RUN} == true ]]; then
        printf "${CLUSTER}: ${GREEN}Skipping ${CLUSTER} since we are running in dry_run mode.${NOCOLOR}\n\n"
        continue
    fi

    ##
    ## Get the name for cluster description file (old vs. new)
    ##
    cluster_file="${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/cluster.yml"
    if ! cluster_file=$(check_yaml_file_exists "$cluster_file"); then
        cluster_file="${TOP_DIR}/config-repo/foundations/$FOUNDATION/$CLUSTER/clusterInfo.yml}"
        if ! cluster_file=$(check_yaml_file_exists "$cluster_file"); then
            error "Failed to find cluster_file in ${TOP_DIR}/config-repo/foundations/$FOUNDATION/$CLUSTER"
            error "$cluster_file"
            exit 1
        fi
    fi

    ##
    ## Now get the credentials for the cluster
    ##
    external_hostname=$(get_cluster_external_hostname "$cluster_file")
    echo "${ADMIN_PASSWORD}" | pks get-credentials ${external_hostname} >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        printf "${RED}Could not retrieve credentials for ${external_hostname}. Skipping.${NOCOLOR}\n\n"
        continue
    fi
    output=$(kubectl config use-context ${external_hostname})
    printf "${GREEN}${output}${NOCOLOR}\n"

    cat >/tmp/bad-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: basic-pv-pod
  namespace: default
spec:
  containers:
  - name: busybox
    image: harbor.cml-k8s-n-06.k8s.wellsfargo.net/prometheus-debug/busybox:1.36.1
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    - "3600"
    securityContext:
      capabilities:
        drop: ["must_drop"]
EOF
    if ! kubectl apply -f /tmp/bad-pod.yaml &>/dev/null; then
        printf "${GREEN}%s ${CYAN}%s.${NOCOLOR}\n" "Constraint violation:" "Constraint [alwayspullimages] was violated as expected"
    else
        ERR_MESSAGES+=("alwayspullimages constraint violation test FAILED.")
    fi

    ##
    ## Surface any errors collected during the process
    ##
    if [ "${#ERR_MESSAGES[@]}" -gt 0 ]; then
        for err in "${ERR_MESSAGES[@]}"; do
            printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n" "${err}"
        done
        HAS_ERRORS=true
        ERR_MESSAGES=()
    fi
done

printf "${YELLOW}%s ${CYAN}%s.${NOCOLOR}\n" "Testing completed:" "Constraint testing completed"
printf "${BLUE}%s${NOCOLOR}\n\n" "####################################################################################"

##
## Exit 1 if errors
##
if [ "$HAS_ERRORS" = true ]; then
    exit 1
fi
