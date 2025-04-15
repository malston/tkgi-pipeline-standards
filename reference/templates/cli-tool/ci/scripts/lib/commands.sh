#!/usr/bin/env bash
#
# Command implementations for fly.sh
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Function to set pipeline
function cmd_set_pipeline() {
  local pipeline_name="$1"
  local foundation="$2"
  local repo_name="$3"
  local target="$4"
  local environment="$5"
  local datacenter="$6"
  local datacenter_type="$7"
  local branch="$8"
  local git_release_branch="$9"
  local version_file="${10}"
  local timer_duration="${11}"
  local version="${12}"
  local dry_run="${13}"
  local verbose="${14}"
  local foundation_path="${15}"
  local git_uri="${16}"
  local config_git_uri="${17}"
  local config_git_branch="${18}"
  local params_git_branch="${19}"

  info "Setting pipeline: ${pipeline_name}-${foundation}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would set pipeline ${pipeline_name}-${foundation}"
    return 0
  fi

  # Set pipeline using fly
  fly -t "${target}" set-pipeline \
    -p "${pipeline_name}-${foundation}" \
    -c "${__DIR}/../../pipelines/${pipeline_name}.yml" \
    -v branch="${branch}" \
    -v foundation="${foundation}" \
    -v foundation_path="${foundation_path}" \
    -v params_git_branch="${params_git_branch}" \
    -v git_uri="${git_uri}" \
    -v config_git_uri="${config_git_uri}" \
    -v config_git_branch="${config_git_branch}" \
    -v git_release_branch="${git_release_branch}" \
    -v version_file="${version_file}" \
    -v timer_duration="${timer_duration}" \
    -v environment="${environment}" \
    ${version:+-v version="${version}"} \
    -n

  success "Pipeline ${pipeline_name}-${foundation} set successfully."
}

# Function to unpause a pipeline
function cmd_unpause_pipeline() {
  local pipeline_name="$1"
  local foundation="$2"
  local target="$3"
  local environment="$4"
  local datacenter="$5"
  local datacenter_type="$6"
  local branch="$7"
  local timer_duration="$8"
  local version="$9"
  local dry_run="${10}"
  local verbose="${11}"
  local foundation_path="${12}"
  local git_uri="${13}"
  local config_git_uri="${14}"
  local config_git_branch="${15}"
  local params_git_branch="${16}"

  info "Setting and unpausing pipeline: ${pipeline_name}-${foundation}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would set and unpause pipeline ${pipeline_name}-${foundation}"
    return 0
  fi

  # First set the pipeline
  cmd_set_pipeline "$@"

  # Then unpause it
  fly -t "${target}" unpause-pipeline -p "${pipeline_name}-${foundation}"

  success "Pipeline ${pipeline_name}-${foundation} set and unpaused successfully."
}

# Function to destroy a pipeline
function cmd_destroy_pipeline() {
  local pipeline_name="$1"
  local foundation="$2"
  local target="$3"
  local dry_run="$4"

  info "Destroying pipeline: ${pipeline_name}-${foundation}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would destroy pipeline ${pipeline_name}-${foundation}"
    return 0
  fi

  # Destroy the pipeline
  fly -t "${target}" destroy-pipeline -p "${pipeline_name}-${foundation}" -n

  success "Pipeline ${pipeline_name}-${foundation} destroyed successfully."
}

# Function to validate a pipeline YAML
function cmd_validate_pipeline() {
  local pipeline_name="$1"
  local dry_run="$2"

  info "Validating pipeline YAML: ${pipeline_name}.yml"

  # Validate the pipeline YAML
  if [[ "${pipeline_name}" == "all" ]]; then
    # Find all pipeline YAMLs
    local pipelines=("main" "release" "set-pipeline")
    local exit_code=0

    for p in "${pipelines[@]}"; do
      info "Validating pipeline: ${p}.yml"
      if [[ -f "${__DIR}/../../pipelines/${p}.yml" ]]; then
        if ! fly validate-pipeline -c "${__DIR}/../../pipelines/${p}.yml"; then
          error "Pipeline ${p}.yml validation failed"
          exit_code=1
        else
          success "Pipeline ${p}.yml validated successfully"
        fi
      else
        warning "Pipeline file ${p}.yml not found"
      fi
    done

    if [[ ${exit_code} -eq 0 ]]; then
      success "All pipelines validated successfully"
    else
      error "One or more pipelines failed validation"
      return 1
    fi
  else
    # Validate a specific pipeline
    if [[ -f "${__DIR}/../../pipelines/${pipeline_name}.yml" ]]; then
      if fly validate-pipeline -c "${__DIR}/../../pipelines/${pipeline_name}.yml"; then
        success "Pipeline ${pipeline_name}.yml validated successfully"
      else
        error "Pipeline ${pipeline_name}.yml validation failed"
        return 1
      fi
    else
      error "Pipeline file ${pipeline_name}.yml not found"
      return 1
    fi
  fi
}

# Function to create a release pipeline
function cmd_release_pipeline() {
  local foundation="$1"
  local repo_name="$2"
  local target="$3"
  local environment="$4"
  local datacenter="$5"
  local datacenter_type="$6"
  local branch="$7"
  local git_release_branch="$8"
  local version_file="$9"
  local timer_duration="${10}"
  local version="${11}"
  local dry_run="${12}"
  local verbose="${13}"
  local foundation_path="${14}"
  local git_uri="${15}"
  local config_git_uri="${16}"
  local config_git_branch="${17}"
  local params_git_branch="${18}"

  info "Creating release pipeline for foundation: ${foundation}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would create release pipeline for ${foundation}"
    return 0
  fi

  # Normalize the version if provided
  if [[ -n "${version}" ]]; then
    version=$(normalize_version "${version}")
    info "Using version: ${version}"
  else
    info "No version specified, will use version from repository"
  fi

  # Set the release pipeline
  fly -t "${target}" set-pipeline \
    -p "release-${foundation}" \
    -c "${__DIR}/../../pipelines/release.yml" \
    -v branch="${branch}" \
    -v foundation="${foundation}" \
    -v foundation_path="${foundation_path}" \
    -v params_git_branch="${params_git_branch}" \
    -v git_uri="${git_uri}" \
    -v config_git_uri="${config_git_uri}" \
    -v config_git_branch="${config_git_branch}" \
    -v git_release_branch="${git_release_branch}" \
    -v version_file="${version_file}" \
    -v timer_duration="${timer_duration}" \
    -v environment="${environment}" \
    ${version:+-v version="${version}"} \
    -n

  success "Release pipeline for ${foundation} created successfully."
}

# Function to create a set-pipeline pipeline
function cmd_set_pipeline_pipeline() {
  local foundation="$1"
  local repo_name="$2"
  local target="$3"
  local branch="$4"
  local timer_duration="$5"
  local dry_run="$6"
  local verbose="$7"
  local git_uri="$8"

  info "Creating set-pipeline pipeline for foundation: ${foundation}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would create set-pipeline pipeline for ${foundation}"
    return 0
  fi

  # Set the pipeline that sets pipelines
  fly -t "${target}" set-pipeline \
    -p "set-pipeline-${foundation}" \
    -c "${__DIR}/../../pipelines/set-pipeline.yml" \
    -v branch="${branch}" \
    -v foundation="${foundation}" \
    -v git_uri="${git_uri}" \
    -v timer_duration="${timer_duration}" \
    -n

  success "Set-pipeline pipeline for ${foundation} created successfully."
}
