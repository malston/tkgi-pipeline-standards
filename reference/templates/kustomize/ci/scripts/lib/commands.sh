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
# @param foundation_path The path to foundation in the config repo
# @param git_uri The git URI for the main repository
# @param config_git_uri The git URI for the configuration repository
# @param config_git_branch The git branch for the configuration repository
function cmd_set_pipeline() {
  # Parse parameters
  local pipeline="$1"
  local foundation="$2"
  local repo="$3"
  local target="$4"
  local environment="$5"
  local datacenter="$6"
  local datacenter_type="$7"
  local branch="$8"
  local git_release_branch="${9:-release}"
  local version_file="${10:-version}"
  local timer_duration="${11}"
  local version="${12}"
  local dry_run="${13}"
  local verbose="${14}"
  local foundation_path="${15}"
  local git_uri="${16}"
  local config_git_uri="${17}"
  local config_git_branch="${18:-master}"

  # If we're calling from the main script, pass by reference
  if [[ "$#" -ge 10 ]]; then
    check_fly TARGET TEST_MODE
  else
    # Otherwise, use the parameter directly
    check_fly "$target"
  fi

  # Prepare variables
  local pipeline_name="${pipeline}-${foundation}"
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"

  # Handle release pipeline
  if [[ "$pipeline" == "release" ]]; then
    pipeline_file="${CI_DIR}/pipelines/release.yml"
  fi

  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    error "Available pipelines under ${CI_DIR}/pipelines:"
    find "${CI_DIR}/pipelines/" -name "*.yml" -exec basename {} \; | sort
    exit 1
  fi

  # Params directory path - check if it exists
  local params_path="${REPO_ROOT}/../params"

  # release_body
  # worker_tags
  # git_uri
  # owner
  # concourse_s3_access_key_id
  # concourse-s3-bucket
  # concourse-s3-endpoint
  # cflinux_current_image
  # cflinux_current_image
  # concourse_s3_secret_access_key

  # Build variables array
  local vars=(
    "-v" "foundation=${foundation}"
    "-v" "environment=${environment}"
    "-v" "branch=${branch}"
    "-v" "git_release_branch=${git_release_branch}"
    "-v" "version_file=${version_file}"
    "-v" "timer_duration=${timer_duration}"
    "-v" "verbose=${verbose}"
  )

  # Add version if set
  if [[ -n "${version}" ]]; then
    vars+=("-v" "version=${version}")
  fi
  # Add datacenter if available
  if [[ -n "${datacenter}" ]]; then
    vars+=("-v" "dc=${datacenter}")
  fi

  # Add datacenter type if available
  if [[ -n "${datacenter_type}" ]]; then
    vars+=("-v" "dc_type=${datacenter_type}")
  fi

  # Add foundation path
  if [[ -n "${foundation_path}" ]]; then
    vars+=("-v" "foundation_path=${foundation_path}")
  elif [[ -n "${datacenter}" ]]; then
    vars+=("-v" "foundation_path=${datacenter}/${foundation}")
  fi

  # Add repo
  if [[ -n "${repo}" ]]; then
    vars+=("-v" "repository=${repo}")
  fi

  # Add git URIs if available
  if [[ -n "${git_uri}" ]]; then
    vars+=("-v" "git_uri=${git_uri}")
  fi

  if [[ -n "${config_git_uri}" ]]; then
    vars+=("-v" "config_git_uri=${config_git_uri}")
  fi

  if [[ -n "${config_git_branch}" ]]; then
    vars+=("-v" "config_git_branch=${config_git_branch}")
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

      if [[ -f "${params_path}/${datacenter}/${datacenter}-${datacenter_type}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${datacenter}/${datacenter}-${datacenter_type}.yml")
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
# @param foundation_path The path to foundation in the config repo
# @param git_uri The git URI for the main repository
# @param config_git_uri The git URI for the configuration repository
# @param config_git_branch The git branch for the configuration repository
function cmd_unpause_pipeline() {
  # Parse parameters
  local pipeline="$1"
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
  local config_git_branch="${15:-master}"

  # Check if fly is installed and the target exists
  if [[ "$#" -ge 10 ]]; then
    check_fly TARGET TEST_MODE
  else
    # Otherwise, use the parameter directly
    check_fly "$target"
  fi

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

  # If we're calling from the main script, pass by reference
  if [[ "$#" -ge 10 ]]; then
    check_fly TARGET TEST_MODE
  else
    # Otherwise, use the parameter directly
    check_fly "$target"
  fi

  local pipeline_name="${pipeline}-${foundation}"
  local confirmation=""

  # Confirm destruction
  if [[ -z "$confirmation" ]]; then
    echo "!!! this will remove all data for pipeline '${pipeline_name}'"
    echo
    read -p "are you sure? [yN]: " confirmation
  fi

  if [[ "${confirmation}" != "y" && "${confirmation}" != "Y" && "${confirmation}" != "yes" ]]; then
    info "Pipeline destruction cancelled"
    return 0
  fi

  # Execute the command
  info "Destroying pipeline: ${pipeline_name}"

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$target\" destroy-pipeline -p \"${pipeline_name}\" --non-interactive"
  else
    fly -t "$target" destroy-pipeline -p "${pipeline_name}" --non-interactive
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
    error "Available pipelines under ${CI_DIR}/pipelines:"
    find "${CI_DIR}/pipelines/" -name "*.yml" -exec basename {} \; | sort
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

# Command: Set set-pipeline pipeline
function cmd_set_pipeline_pipeline() {
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

    # Set set pipeline name
    local set_pipeline="set-release-pipeline"

    # Call set_pipeline with the release pipeline
    if ! cmd_set_pipeline "${set_pipeline}" "${foundation}" "${repo_name}" "${target}" "${environment}" "${datacenter}" "${datacenter_type}" "${branch}" "${git_release_branch}" "${version_file}" "${timer_duration}" "${version}" "${dry_run}" "${verbose}" "${foundation_path}" "${git_uri}" "${config_git_uri}" "${config_git_branch}" "${params_git_branch}"; then
        return 1
    fi
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
# @param foundation_path The path to foundation in the config repo
# @param git_uri The git URI for the main repository
# @param config_git_uri The git URI for the configuration repository
# @param config_git_branch The git branch for the configuration repository
function cmd_release_pipeline() {
  # Parse parameters - all except pipeline
  local foundation="$1"
  local repo="$2"
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
  local config_git_branch="${17:-master}"

  # Get repo name from repo directory if not provided
  if [[ -z "$repo" ]]; then
    repo=$(basename "$REPO_ROOT")
  fi

  # Set the pipeline using the release pipeline
  cmd_set_pipeline "release" "$foundation" "$repo" "$target" "$environment" "$datacenter" "$datacenter_type" "$branch" "$git_release_branch" "$version_file" "$timer_duration" "$version" "$dry_run" "$verbose" "$foundation_path" "$git_uri" "$config_git_uri" "$config_git_branch"

  return 0
}
