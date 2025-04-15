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

printf "${BLUE}%s${NOCOLOR}\n" "####################################################################################"
printf "${YELLOW}%s: ${CYAN}%s${NOCOLOR}\n\n" "Testing starting" "Checking if each gatekeeper constraint works as expected."

pushd "${TOP_DIR}/gatekeeper-repo/src/constrainttemplates" &>/dev/null || exit 1
for constraint_template in $(find ./* -type d -prune -print | tr -d "./"); do
  ##
  ## Run the test suite
  ##
  if [[ -f "${constraint_template}/suite.yaml" ]]; then
    if ! gator verify "${constraint_template}/suite.yaml"; then
      ERR_MESSAGES+=("${constraint_template} test suite FAILED.")
    fi
  else
    CONSTRAINT_NAME=$(yq4 eval '.metadata.name' "${constraint_template}/samples/constraint.yaml")
    printf "\n${YELLOW}%s${NOCOLOR}\n" "${constraint_template} does not have any unit tests. Skipping ${CONSTRAINT_NAME}."
  fi
done

##
## Surface any errors collected during the process
##
if [ "${#ERR_MESSAGES[@]}" -gt 0 ]; then
  for err in "${ERR_MESSAGES[@]}"; do
    printf "${RED}%s${NOCOLOR}\n" "${err}"
  done
  HAS_ERRORS=true
  ERR_MESSAGES=()
fi

printf "${GREEN}%s ${CYAN}%s.${NOCOLOR}\n" "Testing completed:" "Constraint testing completed"
printf "${BLUE}%s${NOCOLOR}\n\n" "####################################################################################"

##
## Exit 1 if errors
##
if [ "$HAS_ERRORS" = true ]; then
  exit 1
fi
