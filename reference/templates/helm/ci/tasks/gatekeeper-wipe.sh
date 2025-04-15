#!/bin/bash

##
## This script will delete gatekeeper on any cluster
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
## Log into the foundation once before we loop through the cluster(s)
##
ADMIN_PASSWORD=$(./gatekeeper-repo/scripts/common/login-pks.sh)
if [[ -z ${ADMIN_PASSWORD} ]]; then
  printf "${CLUSTER}:${RED}%s${NOCOLOR}\n" "Error retrieving the pks admin password. Goodbye."
  exit 1
fi

##
## Color definitions
##
GREEN='\033[0;32m'
RED='\033[0;31m'
NOCOLOR='\033[0m'

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
  ## If there is a 'no-gatekeeper' file at the top level or the wipe override flag is set then we will wipe gatekeeper from this cluster
  ##
  if [[ -f "${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/no-gatekeeper" ]] || [[ ${WIPE_OVERRIDE} == "true" ]]; then
    printf "\n${CLUSTER}:${GREEN} Wiping gatekeeper from ${CLUSTER}${NOCOLOR}\n"
  else
    printf "\n${CLUSTER}:${GREEN} Not wiping gatekeeper for ${CLUSTER}${NOCOLOR}\n"
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
  echo "${ADMIN_PASSWORD}" | pks get-credentials ${external_hostname} > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    printf "${RED}Could not retrieve credentials for ${external_hostname}. Skipping.${NOCOLOR}\n\n"
    continue
  fi
  output=$(kubectl config use-context ${external_hostname})
  printf "${GREEN}${output}${NOCOLOR}\n"


  ##
  ## Perform the uninstall
  ##
  printf "\n${CLUSTER}:${GREEN} Removing Gatekeeper via helm...${NOCOLOR}\n"

  cd "${TOP_DIR}/gatekeeper-repo" &>/dev/null || exit 1

  helm uninstall gatekeeper -n gatekeeper-system
  kubectl delete crd -l gatekeeper.sh/system=yes
  kubectl delete namespace gatekeeper-system

  printf "${CLUSTER}: ${GREEN}%s${NOCOLOR}\n" "Gatekeeper uninstall is complete for ${CLUSTER}"
done
