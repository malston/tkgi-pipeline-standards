#!/bin/bash

set -e

##
## This script will install gatekeeper templates and constraints on any cluster
## if gatekeeper is already installed
##

##
## Grab the "top-level" of the directory inside our task container
##
TOP_DIR=$(pwd)

if [[ -z $FOUNDATION ]]; then
  error "FOUNDATION param not set"
  exit 1
fi

if [[ -z $OPSMAN_DOMAIN_OR_IP_ADDRESS ]]; then
  error "OPSMAN_DOMAIN_OR_IP_ADDRESS env variable is not set"
  exit 1
fi

if [[ -z $OPSMAN_CLIENT_ID ]]; then
  error "OPSMAN_CLIENT_ID env variable is not set"
  exit 1
fi

if [[ -z $OPSMAN_CLIENT_SECRET ]]; then
  error "OPSMAN_CLIENT_SECRET env variable is not set"
  exit 1
fi

if [[ -z $PKS_API_ENDPOINT ]]; then
  error "PKS_API_ENDPOINT env variable is not set"
  exit 1
fi

##
## Source helpers.sh to grab all clusters in foundation later on
##
source ${TOP_DIR}/gatekeeper-repo/scripts/helpers.sh || exit 1

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
YELLOW='\033[0;33m'
NOCOLOR='\033[0m'

##
## Global variables
##
declare -a ERR_MESSAGES=()

##
## Get the excluded namespaces and apply the constraints of a given type to the cluster
##
function process_constraints() {
  local foundation=$1
  local cluster=$2
  local constraints_type=$3
  local constraints
  local excluded_namespaces

  constraints=$(yq4 -o=json ".gatekeeper_constraints_${constraints_type}" "${TOP_DIR}/config-repo/foundations/${foundation}/gatekeeper.yml")
  if [[ $constraints != "" && $constraints != "[]" ]]; then
    printf "${cluster}: ${GREEN}%s:%s${NOCOLOR}\n" "Applying the following constraints in ${constraints_type} mode as per the foundation gatekeeper.yml" "${constraints}"
  else
    printf "${cluster}: ${YELLOW}%s${NOCOLOR}\n" "No ${constraints_type} constraints to apply per gatekeeper.yml"
    return
  fi

  excluded_namespaces=$(get_excluded_namespaces "${foundation}" "${cluster}" "${constraints_type}")
  printf "${cluster}: ${GREEN}Excluding the following namespaces from ${constraints_type} mode: %s${NOCOLOR}\n" "${excluded_namespaces}"

  apply_constraints "${cluster}" "${constraints_type}" "${excluded_namespaces}"
}

##
## Create a list of namespaces that should be excluded from the constraints
##
function get_excluded_namespaces() {
  local foundation=$1
  local cluster=$2
  local constraints_type=$3
  local exclusions
  local excluded_namespaces

  for constraint in $(yq4 -o=json ".gatekeeper_constraints_${constraints_type}" "${TOP_DIR}/config-repo/foundations/${foundation}/gatekeeper.yml" | jq -r '.[]'); do
    specific_constraints+=("$constraint")
  done

  ##
  ## For each defined constraint we create a list of namespaces to exclude
  ## based on the nameSpaceInfo.yml file
  ##
  cd "${TOP_DIR}/gatekeeper-repo/src/constraints" &>/dev/null || exit 1
  for constraint in $(find ./* -type d -prune -print | tr -d "./"); do
    found=false
    for value in "${specific_constraints[@]}"; do
      if [[ "$constraint" = "$value" ]]; then
        found=true
        break
      fi
    done
    ##
    ## If the constraint is listed in the values we get from gatekeeper.yml, then
    ## we check nameSpaceInfo.yml to see if we should exclude it
    ##
    if [ "$found" = true ]; then
      pushd "${TOP_DIR}/config-repo/foundations/$foundation/$cluster" &>/dev/null || exit 1
      for namespace in $(find ./* -type d -prune -print | tr -d "./" | grep -v 'network-profiles' | grep -v 'compute-profiles'); do
        if yq4 '.opaExclusions' "${namespace}/nameSpaceInfo.yml" | grep -qE "$constraint$"; then
          if [[ ! $exclusions =~ $namespace* ]]; then
            exclusions+="\"$namespace\""
          fi
        fi
      done
      excluded_namespaces="${exclusions//\"\"/\", \"}"
      popd &>/dev/null || exit 1
    fi
  done
  echo "${excluded_namespaces}"
}

##
## Apply constraint templates to the cluster
##
function apply_constraint_templates() {
  local cluster=$1

  pushd "${TOP_DIR}/gatekeeper-repo/src/constrainttemplates" &>/dev/null || exit 1
  for template in $(find ./* -type d -prune -print | tr -d "./"); do
    if [[ ! -f "${template}/template.yaml" ]]; then
      printf "${cluster}: ${YELLOW}%s${NOCOLOR}\n" "No template.yaml for ${template} found. Skipping..."
      continue
    fi
    constraint_template_name=$(yq4 eval '.metadata.name' "${template}/template.yaml")
    printf "${cluster}: ${GREEN}%s${NOCOLOR}\n" "Applying constrainttemplate: ${constraint_template_name}..."

    if ! kubectl apply -f "${template}/template.yaml"; then
      printf "${cluster}: ${RED}%s${NOCOLOR}\n" "Failed to apply constrainttemplate: ${constraint_template_name}"
      exit 1
    fi

    ##
    ## Wait for constrainttemplate and respective crd to reconcile
    ##
    seconds_to_wait=30
    printf "${cluster}: ${GREEN}%s${NOCOLOR}\n" "Waiting for constrainttemplate/${constraint_template_name} status"
    now=$SECONDS
    time_limit=$((now + seconds_to_wait))
    while ! kubectl get "constrainttemplate/${constraint_template_name}" &>/dev/null; do
      now=$SECONDS
      if [[ $now -gt $time_limit ]]; then
        printf "${cluster}: ${RED}%s${NOCOLOR}\n" "Failed to install constrainttemplate: ${constraint_template_name}. Timeout exceeded."
        kubectl get "constrainttemplate/${constraint_template_name}"
        exit 1
      fi
      printf "."
    done
    printf "${cluster}: ${GREEN}%s${NOCOLOR}\n" "Waiting for constrainttemplate to create ${constraint_template_name} crd..."
    now=$SECONDS
    time_limit=$((now + seconds_to_wait))
    while ! kubectl get crd "${constraint_template_name}.constraints.gatekeeper.sh" &>/dev/null; do
      now=$SECONDS
      if [[ $now -gt $time_limit ]]; then
        printf "${cluster}: ${RED}%s${NOCOLOR}\n" "Failed to install: ${constraint_template_name}. Timeout exceeded."
        kubectl get crd "${constraint_template_name}.constraints.gatekeeper.sh"
        exit 1
      fi
      printf "."
      sleep 1
    done
    kubectl wait --for condition=established --timeout="${seconds_to_wait}s" "crd/${constraint_template_name}.constraints.gatekeeper.sh" || exit 1
  done
  popd &>/dev/null || exit 1
}

##
## Apply constraints to the cluster
##
function apply_constraints() {
  local cluster=$1
  local enforcement=$2
  local excluded_namespaces=$3

  pushd "${TOP_DIR}/gatekeeper-repo/src/constraints" &>/dev/null || exit 1

  for constraint in $(find ./* -type d -prune -print | tr -d "./" | grep -v templates); do
    found=false
    # Skip if the constraint dir doesn't match one of the constraints
    for c in $(yq4 -o=json ".gatekeeper_constraints_${enforcement}" "${TOP_DIR}/config-repo/foundations/${foundation}/gatekeeper.yml" | jq -r '.[]'); do
      if [[ $constraint = "$c" ]]; then
        found=true
        break
      fi
    done
    if [ "$found" != true ]; then
      continue
    fi
    pushd "${constraint}" &>/dev/null || exit 1
    ##
    ## Create the override file using the excluded namespaces and apply.
    ##
    for c in *.yml; do
      if [[ $c =~ override.yml ]]; then
        continue
      fi
      constraint_name=$(yq4 eval '.metadata.name' "${c}")
      ytt -f "${c}" \
        -f "${TOP_DIR}/gatekeeper-repo/charts/gatekeeper/ytt-vars/constraint-var.yml" \
        --data-value-yaml excludednamespace="[${excluded_namespaces}]" \
        --data-value-yaml enforcementAction="${enforcement}" \
        >"${constraint_name}-override.yml"

      ##
      ## Apply constraints to the cluster
      ##
      crd=$(yq4 eval '.kind' "${c}" | tr '[:upper:]' '[:lower:]')
      printf "${cluster}: ${GREEN}%s${NOCOLOR}\n" "Creating constraint: ${constraint_name}..."
      if ! kubectl apply -f "${constraint_name}-override.yml"; then
        printf "${cluster}: ${RED}%s${NOCOLOR}\n" "Failed to apply constraint: ${constraint_name}"
        exit 1
      fi
      enforcement_action="$(kubectl get "${crd}/${constraint_name}" -o jsonpath='{.spec.enforcementAction}')"
      if [[ ${enforcement_action} != "${enforcement}" ]]; then
        ERR_MESSAGES+=("Enforcement action '${enforcement_action}' for ${crd}/${constraint_name} is not equal to expected value of ${ENFORCEMENT}.")
      fi
    done
    popd &>/dev/null || exit 1
  done

  popd &>/dev/null || exit 1
}

##
## If any constraints are installed but not defined in the foundation file remove them
##
function remove_undefined_constraints() {
  local foundation=$1
  local cluster=$2

  IFS=" " read -r -a all_constraints <<<"$(get_gatekeeper_constraints "$foundation")"

  pushd "${TOP_DIR}/gatekeeper-repo/src/constraints" &>/dev/null || exit 1
  printf "${cluster}: ${GREEN}%s${NOCOLOR}\n" "Removing undefined constraints..."
  ##
  ## Remove any contraints that listed in the constraints dir and not in the gatekeeper.yml in the config repo
  ##
  for constraint in $(find ./* -type d -prune -print | tr -d "./" | grep -v templates); do
    found=false
    # if the constraint from gatekeeper.yml exists in the dir then we move on to the next one
    for value in "${all_constraints[@]}"; do
      if [[ "$constraint" = "$value" ]]; then
        found=true
        break
      fi
    done
    if [ "$found" = true ]; then
      continue
    fi
    printf "${cluster}: ${YELLOW}%s${NOCOLOR}\n" "Removing all $constraint constraints..."
    # if it doesn't exist then we need to delete all the contraints in the dir
    pushd "${constraint}" &>/dev/null || exit 1
    for c in *.yml; do
      crd=$(yq4 eval '.kind' "${c}" | tr '[:upper:]' '[:lower:]')
      constraint_name=$(yq4 eval '.metadata.name' "${c}")
      if kubectl get "${crd}/${constraint_name}" >/dev/null 2>&1; then
        kubectl delete "${crd}/${constraint_name}"
      fi
    done
    popd &>/dev/null || exit 1
  done
}

function get_gatekeeper_constraints() {
  local foundation=$1
  local constraints_types=(dryrun deny warn)
  local all_constraints=()
  for type in "${constraints_types[@]}"; do
    for constraint in $(yq4 -o=json ".gatekeeper_constraints_${type}" "${TOP_DIR}/config-repo/foundations/${foundation}/gatekeeper.yml" | jq -r '.[]'); do
      all_constraints+=("$constraint")
    done
  done
  echo "${all_constraints[@]}"
}

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
  ## If there is a 'no-constraints' file at the top level then we will skip
  ## installing gatekeeper constraints on this cluster
  ##
  if [[ -f "${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/no-constraints" ]]; then
    printf "${CLUSTER}: ${GREEN}Skipping ${CLUSTER} as it has a 'no-constraints' file.${NOCOLOR}\n\n"
    continue
  elif [[ -f "${TOP_DIR}/config-repo/foundations/${FOUNDATION}/${CLUSTER}/no-gatekeeper" ]]; then
    printf "${CLUSTER}: ${GREEN}Skipping ${CLUSTER} as it has a 'no-gatekeeper' file.${NOCOLOR}\n\n"
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
    printf "${CLUSTER}: ${RED}Could not retrieve credentials for ${external_hostname}. Skipping.${NOCOLOR}\n\n"
    continue
  fi
  output=$(kubectl config use-context ${external_hostname})
  printf "${CLUSTER}: ${GREEN}${output}${NOCOLOR}\n"

  ##
  ## Check if gatekeeper is installed and if not skip constraints
  ##
  if ! kubectl get deployments gatekeeper-controller-manager -n gatekeeper-system >/dev/null 2>&1; then
    printf "${CLUSTER}: ${GREEN}Gatekeeper is not installed on this cluster. Skipping constraints..${NOCOLOR}\n\n"
    continue
  fi

  ##
  ## Apply constraint templates before applying constraints
  ##
  apply_constraint_templates "$CLUSTER"

  ##
  ## Apply deny, dryrun and warn constraints
  ##
  process_constraints "$FOUNDATION" "$CLUSTER" "deny"
  process_constraints "$FOUNDATION" "$CLUSTER" "dryrun"
  process_constraints "$FOUNDATION" "$CLUSTER" "warn"

  ##
  ## Remove constraints from cluster that are no longer in config-repo
  ##
  remove_undefined_constraints "$FOUNDATION" "$CLUSTER"

  ##
  ## Surface any errors collected during the process
  ##
  if [ "${#ERR_MESSAGES[@]}" -gt 0 ]; then
    for err in "${ERR_MESSAGES[@]}"; do
      printf "${CLUSTER}: ${RED}%s${NOCOLOR}\n" "${err}"
    done
    exit 1
  fi

  printf "${CLUSTER}: ${GREEN}Gatekeeper constraint install is complete for ${CLUSTER}.${NOCOLOR}\n\n"
done
