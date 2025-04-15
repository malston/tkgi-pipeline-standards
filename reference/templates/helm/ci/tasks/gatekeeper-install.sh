#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

##
## This script will install gatekeeper on any cluster
##

##
## Grab the "top-level" of the directory inside our task container
##
TOP_DIR=$(pwd)

##
## Source helpers.sh to grab all clusters in foundation later on
##
# shellcheck disable=SC1091
source ./gatekeeper-repo/scripts/helpers.sh || exit 1

##
## Log into the foundation once before we loop through the cluster(s)
##
ADMIN_PASSWORD=$(./gatekeeper-repo/scripts/common/login-pks.sh)
if [[ -z ${ADMIN_PASSWORD} ]]; then
  printf "${CLUSTER}: ${RED}Error retrieving the pks admin password. Goodbye.${NOCOLOR}\n\n"
  exit 1
fi

##
## Color definitions
##
GREEN='\033[0;32m'
RED='\033[0;31m'
NOCOLOR='\033[0m'

##
## Waits until condition is met or timeout occurs
##
wait_for_process() {
  wait_time="$1"
  sleep_time="$2"
  cmd="$3"
  while [ "$wait_time" -gt 0 ]; do
    if eval "$cmd"; then
      return 0
    else
      sleep "$sleep_time"
      wait_time=$((wait_time - sleep_time))
    fi
  done
  return 1
}

##
## Get the list of clusters from the output of the cluster-create-delete task
##
IFS=" " read -r -a DESIRED_CLUSTERS <<<"$(get_desired_clusters "$FOUNDATION" "${TOP_DIR}/config-repo")"
if [ "${#DESIRED_CLUSTERS[@]}" -eq 0 ]; then
  printf "${RED}%s\n" "No clusters running in $FOUNDATION"
  pks clusters
  exit 1
fi

for CLUSTER in "${DESIRED_CLUSTERS[@]}"; do
  printf "${CLUSTER}:${GREEN}%s${NOCOLOR}\n" "---------------------------------------------------------------------------------------------"
  ##
  ## Ensure you have created a directory to house your clusters files
  ##
  if [[ ! -d ${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER} ]]; then
    printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n" "Directory \"${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}\" does not exist."
    printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n" "Please create a directory for \"${CLUSTER}\" in \"${TOP_DIR}/config-repo/foundations/${FOUNDATION}\" before continuing"
    continue
  fi

  ##
  ## If dry_run is set to true, then we will skip wiping istio on this cluster
  ##
  if [[ ${PIPELINE_DRY_RUN} == true ]]; then
    printf "${CLUSTER}: ${GREEN}%s${NOCOLOR}\n\n" "Skipping ${CLUSTER} since we are running in dry_run mode."
    continue
  fi

  ##
  ## If there is a 'no-gatekeeper' file at the top level then we will skip installing gatekeeper on this cluster
  ##
  if [[ -f "${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/no-gatekeeper" ]]; then
    printf "${CLUSTER}: ${GREEN}%s${NOCOLOR}\n\n" "Skipping ${CLUSTER} as it has a 'no-gatekeeper' file."
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
    printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n\n" "Could not retrieve credentials for ${external_hostname}. Skipping."
    continue
  fi
  output=$(kubectl config use-context ${external_hostname})
  printf "${CLUSTER}: ${GREEN}%s${NOCOLOR}\n" "${output}"

  ##
  ## Perform the install
  ##
  printf "\n${CLUSTER}: ${GREEN}%s${NOCOLOR}\n" "Beginning installation of Gatekeeper via helm..."

  cd "${TOP_DIR}/gatekeeper-repo" &>/dev/null || exit 1

  ##
  ## Create the gatekeeper namespace with proper annotations
  ##
  if ! kubectl apply -f config/k8s/gatekeeper-ns.yml; then
    printf "\n${CLUSTER}: ${RED}%s${NOCOLOR}\n" "Creating gatekeeper-system namespace failed."
    exit 1
  fi

  ##
  ## Check for a current gatekeeper installation so we know whether to helm install or upgrade
  ##
  cd "${TOP_DIR}/gatekeeper-repo/gatekeeper-${GATEKEEPER_VERSION}" &>/dev/null || exit 1

  for i in crds/*.yaml; do
    kubectl apply -f "$i"
  done

  # Make sure the istio-injection label is disabled
  kubectl patch namespace gatekeeper-system -p '{"metadata":{"labels":{"istio-injection":"disabled"}}}'

  if [[ -f "${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/gatekeeper-system/gatekeeper.yml" ]]; then
    ytt -f "${TOP_DIR}/gatekeeper-repo/charts/gatekeeper/values/default.yaml" \
      -f "${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/gatekeeper-system/gatekeeper.yml" \
      >"/tmp/gatekeeper-values.yml"
  else
    cp "${TOP_DIR}/gatekeeper-repo/charts/gatekeeper/values/default.yaml" "/tmp/gatekeeper-values.yml"
  fi

  if ! helm status gatekeeper -n gatekeeper-system >/dev/null 2>&1; then
    echo "Installing gatekeeper version ${GATEKEEPER_VERSION} via the helm charts"
    helm install gatekeeper . -n gatekeeper-system --no-hooks \
      --values "/tmp/gatekeeper-values.yml" \
      --set image.repository="${GATEKEEPER_DOCKERREPO}/openpolicyagent/gatekeeper" \
      --set image.pullPolicy="Always" \
      --set logDenies="true" \
      --set psp.enabled="false" \
      --set postInstall.labelNamespace.enabled="false"
  else
    echo "Upgrading gatekeeper version ${GATEKEEPER_VERSION} via the helm charts"
    helm upgrade gatekeeper . -n gatekeeper-system --no-hooks \
      --values "/tmp/gatekeeper-values.yml" \
      --set image.repository="${GATEKEEPER_DOCKERREPO}/openpolicyagent/gatekeeper" \
      --set image.pullPolicy="Always" \
      --set logDenies="true" \
      --set psp.enabled="false" \
      --set postInstall.labelNamespace.enabled="false"
  fi

  cd "${TOP_DIR}/gatekeeper-repo" &>/dev/null || exit 1

  if ! wait_for_process 30 5 "kubectl -n gatekeeper-system wait --for=condition=Ready --timeout=60s pod -l control-plane=controller-manager"; then
    printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n\n" "Gatekeeper install failed. Gatekeeper controller-manager pods timed out."
    exit 1
  fi

  ##
  ## CRDs are not immediately ready so loop until the config is able to be applied
  ##
  if ! wait_for_process 10 1 "kubectl apply -f config/k8s/gatekeeper-config.yml"; then
    printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n\n" "Gatekeeper install failed. Gatekeeper config apply timed out."
    exit 1
  fi

  ##
  ## Setup splunk logging for gatekeeper
  ##
  kubectl apply -n gatekeeper-system -f <(ytt -f config/templates/gatekeeper-logsink-template.yml \
    -f charts/gatekeeper/ytt-vars/gatekeeper-logsink-var.yml \
    -v splunk_token="${SPLUNK_TOKEN}")

  if ! wait_for_process 30 5 "kubectl -n gatekeeper-system wait --for=condition=Ready --timeout=60s pod -l control-plane=audit-controller"; then
    printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n\n" "Gatekeeper install failed. Gatekeeper audit-controller pods timed out."
    exit 1
  fi

  ##
  ## Delete any network policies which will interfere with gatekeeper
  ##
  printf "${CLUSTER}: ${GREEN}%s${NOCOLOR}\n\n" "Removing network policies from gatekeeper namespace."
  kubectl delete networkpolicies.networking.k8s.io --all -n gatekeeper-system

  printf "${CLUSTER}: ${GREEN}%s${NOCOLOR}\n\n" "Gatekeeper install is complete for ${CLUSTER}."
done
