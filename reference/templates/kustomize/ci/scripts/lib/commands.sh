#!/usr/bin/env bash
#
# Command implementations for fly.sh
# Contains the implementation of the various commands supported by the script
#

# Implementation of set pipeline command
# This function takes parameters instead of using global variables
# @param pipeline_name The name of the pipeline without foundation
# @param foundation The foundation name
# @param target The concourse target
# @param environment The environment (lab, nonprod, prod)
# @param datacenter The datacenter
# @param branch The git branch
# @param timer_duration The timer trigger duration
# @param version The pipeline version (optional)
# @param dry_run Whether to perform a dry run (true/false)
# @param verbose Whether to be verbose (true/false)
function cmd_set_pipeline() {
  # Parse parameters
  local pipeline="$1"
  local foundation="$2"
  local target="$3"
  local environment="$4"
  local datacenter="$5"
  local branch="$6"
  local timer_duration="$7"
  local version="$8"
  local dry_run="$9"
  local verbose="${10}"

  check_fly "$target"

  # Prepare variables
  local pipeline_name="${pipeline}-${foundation}"
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"

  # Handle release pipeline
  if [[ "$pipeline" == "release" ]]; then
    pipeline_file="${CI_DIR}/pipelines/release.yml"
  fi

  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    error "Available pipelines:"
    find "${CI_DIR}/pipelines/" -name "*.yml" -exec basename {} \; | sort | sed 's/\.yml$//'
    exit 1
  fi

  # Params directory path - check if it exists
  local params_path="${REPO_ROOT}/../params"

  # Build variables array
  local vars=(
    "-v" "foundation=${foundation}"
    "-v" "environment=${environment}"
    "-v" "branch=${branch}"
    "-v" "timer_duration=${timer_duration}"
    "-v" "verbose=${verbose}"
  )

  # Add version if set
  if [[ -n "${version}" ]]; then
    vars+=("-v" "version=${version}")
  fi

  # Add datacenter if available
  if [[ -n "${datacenter}" ]]; then
    vars+=("-v" "datacenter=${datacenter}")
  fi

  # Add foundation path
  if [[ -n "${datacenter}" ]]; then
    vars+=("-v" "foundation_path=${datacenter}/${foundation}")
  fi

  # Build vars files array if params directory exists
  local vars_files=()

  if [[ -d "$params_path" ]]; then
    # Add global params if they exist
    if [[ -f "${params_path}/global.yml" ]]; then
      vars_files+=("-l" "${params_path}/global.yml")
    fi

    if [[ -f "${params_path}/k8s-global.yml" ]]; then
      vars_files+=("-l" "${params_path}/k8s-global.yml")
    fi

    # Add datacenter params if they exist
    if [[ -d "${params_path}/${datacenter}" ]]; then
      if [[ -f "${params_path}/${datacenter}/${datacenter}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${datacenter}/${datacenter}.yml")
      fi

      if [[ -f "${params_path}/${datacenter}/${foundation}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${datacenter}/${foundation}.yml")
      fi
    fi
  fi

  # Execute the command
  info "Setting pipeline: ${pipeline_name}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$target\" set-pipeline -p \"${pipeline_name}\" -c \"${pipeline_file}\" ${vars_files[*]} ${vars[*]}"
  else
    # With vars_files
    if [[ ${#vars_files[@]} -gt 0 ]]; then
      fly -t "$target" set-pipeline \
        -p "${pipeline_name}" \
        -c "${pipeline_file}" \
        "${vars_files[@]}" \
        "${vars[@]}"
    else
      # Without vars_files
      fly -t "$target" set-pipeline \
        -p "${pipeline_name}" \
        -c "${pipeline_file}" \
        "${vars[@]}"
    fi

    success "Pipeline '${pipeline_name}' set successfully"
  fi
  
  return 0
}

# Implementation of unpause pipeline command
# This function takes parameters instead of using global variables
# @param pipeline_name The name of the pipeline without foundation
# @param foundation The foundation name
# @param target The concourse target
# @param environment The environment (lab, nonprod, prod)
# @param datacenter The datacenter
# @param branch The git branch
# @param timer_duration The timer trigger duration
# @param version The pipeline version (optional)
# @param dry_run Whether to perform a dry run (true/false)
# @param verbose Whether to be verbose (true/false)
function cmd_unpause_pipeline() {
  # Parse parameters
  local pipeline="$1"
  local foundation="$2"
  local target="$3"
  local environment="$4"
  local datacenter="$5"
  local branch="$6"
  local timer_duration="$7"
  local version="$8"
  local dry_run="$9"
  local verbose="${10}"

  # First set the pipeline
  cmd_set_pipeline "$pipeline" "$foundation" "$target" "$environment" "$datacenter" "$branch" "$timer_duration" "$version" "$dry_run" "$verbose"

  local pipeline_name="${pipeline}-${foundation}"

  info "Unpausing pipeline: ${pipeline_name}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$target\" unpause-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$target" unpause-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' unpaused successfully"
  fi
  
  return 0
}

# Implementation of destroy pipeline command
# This function takes parameters instead of using global variables
# @param pipeline_name The name of the pipeline without foundation
# @param foundation The foundation name
# @param target The concourse target
# @param dry_run Whether to perform a dry run (true/false)
function cmd_destroy_pipeline() {
  # Parse parameters
  local pipeline="$1"
  local foundation="$2"
  local target="$3"
  local dry_run="$4"
  
  check_fly "$target"

  local pipeline_name="${pipeline}-${foundation}"
  local confirmation=""

  # Confirm destruction
  if [[ -z "$confirmation" ]]; then
    read -p "Are you sure you want to destroy pipeline '${pipeline_name}'? (yes/no): " confirmation
  fi

  if [[ "${confirmation}" != "yes" ]]; then
    info "Pipeline destruction cancelled"
    return 0
  fi

  # Execute the command
  info "Destroying pipeline: ${pipeline_name}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$target\" destroy-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$target" destroy-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' destroyed successfully"
  fi
  
  return 0
}

# Implementation of validate pipeline command
# This function takes parameters instead of using global variables
# @param pipeline_name The name of the pipeline without foundation
# @param dry_run Whether to perform a dry run (true/false)
function cmd_validate_pipeline() {
  # Parse parameters
  local pipeline="$1"
  local dry_run="$2"
  
  # Determine pipeline file
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"

  # Handle special pipeline names
  if [[ "$pipeline" == "release" ]]; then
    pipeline_file="${CI_DIR}/pipelines/release.yml"
  fi

  # Validate all pipelines if requested
  if [[ "$pipeline" == "all" ]]; then
    info "Validating all pipelines"

    for pipeline_file in "${CI_DIR}"/pipelines/*.yml; do
      local pipeline_name=$(basename "${pipeline_file}" .yml)
      info "Validating pipeline: ${pipeline_name}"

      fly validate-pipeline -c "${pipeline_file}" || {
        error "Pipeline validation failed: ${pipeline_name}"
        return 1
      }
    done

    success "All pipelines validated successfully"
    return 0
  fi

  # Validate a specific pipeline
  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    error "Available pipelines:"
    find "${CI_DIR}/pipelines/" -name "*.yml" -exec basename {} \; | sort | sed 's/\.yml$//'
    exit 1
  fi

  info "Validating pipeline: ${pipeline}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly validate-pipeline -c \"${pipeline_file}\""
  else
    fly validate-pipeline -c "${pipeline_file}" || {
      error "Pipeline validation failed: ${pipeline}"
      return 1
    }

    success "Pipeline validated successfully: ${pipeline}"
  fi
  
  return 0
}

# Implementation of release pipeline command (legacy behavior)
# This function takes parameters instead of using global variables
# @param foundation The foundation name
# @param target The concourse target
# @param environment The environment (lab, nonprod, prod)
# @param datacenter The datacenter
# @param branch The git branch
# @param timer_duration The timer trigger duration
# @param version The pipeline version (optional)
# @param dry_run Whether to perform a dry run (true/false)
# @param verbose Whether to be verbose (true/false)
function cmd_release_pipeline() {
  # Parse parameters - all except pipeline
  local foundation="$1"
  local target="$2"
  local environment="$3"
  local datacenter="$4"
  local branch="$5"
  local timer_duration="$6"
  local version="$7"
  local dry_run="$8"
  local verbose="$9"

  # Set the pipeline using the release pipeline
  cmd_set_pipeline "release" "$foundation" "$target" "$environment" "$datacenter" "$branch" "$timer_duration" "$version" "$dry_run" "$verbose"
  
  return 0
}