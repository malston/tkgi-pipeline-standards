#!/usr/bin/env bash
#
# Script: commands.sh
# Description: Command implementations for the fly.sh script
#

# Set a pipeline
function cmd_set_pipeline() {
  local pipeline="$1"
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

  if ! check_fly; then
    error "Failed to check fly command"
    return 1
  fi

  info "Setting pipeline: ${pipeline}-${foundation}"

  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
  if [[ ! -f "$pipeline_file" ]]; then
    error "Pipeline file not found: $pipeline_file"
    return 1
  fi

  local params_repo="${REPO_ROOT}/../../../../params"
  if [[ ! -d "$params_repo" ]]; then
    warn "Params repo not found at $params_repo. Using environment variables instead."
  fi

  # Set pipeline command
  local cmd=(
    fly -t "${target}" set-pipeline
    -p "${pipeline}-${foundation}"
    -c "${pipeline_file}"
  )

  # Add params files if they exist
  if [[ -d "${params_repo}" ]]; then
    for params_file in \
      "${params_repo}/${datacenter}/${foundation}.yml" \
      "${params_repo}/${datacenter}/${datacenter}-${datacenter_type}.yml" \
      "${params_repo}/${datacenter}/${datacenter}.yml" \
      "${params_repo}/${datacenter_type}-global.yml" \
      "${params_repo}/global.yml"; do
      if [[ -f "${params_file}" ]]; then
        cmd+=(-l "${params_file}")
      fi
    done
  fi

  # Add vars
  cmd+=(
    -v "branch=${branch}"
    -v "foundation=${foundation}"
    -v "foundation_path=${foundation_path}"
    -v "params_git_branch=${params_git_branch}"
    -v "verbose=${verbose}"
    -v "environment=${environment}"
    -v "git_uri=${git_uri}"
    -v "config_git_uri=${config_git_uri}"
    -v "config_git_branch=${config_git_branch}"
    -v "timer_duration=${timer_duration}"
  )

  # Add version if specified
  if [[ -n "${version}" ]]; then
    cmd+=(-v "version=${version}")
  fi

  # Add version_file if it exists
  if [[ -f "${REPO_ROOT}/${version_file}" ]]; then
    cmd+=(-v "version_file=${version_file}")
  fi

  # Execute the command
  run_command "${cmd[@]}"

  return $?
}

# Set and unpause a pipeline
function cmd_unpause_pipeline() {
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
  local config_git_branch="${15}"
  local params_git_branch="${16}"

  # First set the pipeline
  cmd_set_pipeline "$pipeline" "$foundation" "$REPO_NAME" "$target" "$environment" "$datacenter" "$datacenter_type" "$branch" "$GIT_RELEASE_BRANCH" "$VERSION_FILE" "$timer_duration" "$version" "$dry_run" "$verbose" "$foundation_path" "$git_uri" "$config_git_uri" "$config_git_branch" "$params_git_branch"
  local set_result=$?

  if [[ $set_result -ne 0 ]]; then
    error "Failed to set pipeline"
    return $set_result
  fi

  # Then unpause it
  info "Unpausing pipeline: ${pipeline}-${foundation}"

  run_command fly -t "${target}" unpause-pipeline -p "${pipeline}-${foundation}"
  return $?
}

# Destroy a pipeline
function cmd_destroy_pipeline() {
  local pipeline="$1"
  local foundation="$2"
  local target="$3"
  local dry_run="$4"

  if ! check_fly; then
    error "Failed to check fly command"
    return 1
  fi

  info "Destroying pipeline: ${pipeline}-${foundation}"

  # Confirm destruction
  if [[ "${dry_run}" != "true" ]]; then
    read -p "Are you sure you want to destroy pipeline ${pipeline}-${foundation}? [y/N] " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
      info "Pipeline destruction cancelled"
      return 0
    fi
  fi

  run_command fly -t "${target}" destroy-pipeline -p "${pipeline}-${foundation}"
  return $?
}

# Validate a pipeline without setting it
function cmd_validate_pipeline() {
  local pipeline="$1"
  local dry_run="$2"

  if ! check_fly; then
    error "Failed to check fly command"
    return 1
  fi

  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
  if [[ ! -f "$pipeline_file" ]]; then
    error "Pipeline file not found: $pipeline_file"
    return 1
  fi

  info "Validating pipeline: ${pipeline}"

  if [[ "${dry_run}" == "true" ]]; then
    echo "[DRY RUN] Would validate: $pipeline_file"
    return 0
  fi

  # Use fly validate-pipeline command
  fly validate-pipeline -c "${pipeline_file}"
  return $?
}

# Create a release pipeline
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

  # Get the latest version if not specified
  if [[ -z "${version}" ]]; then
    if type get_latest_version &>/dev/null; then
      version=$(get_latest_version)
      if [[ -z "${version}" ]]; then
        error "Failed to determine version for release"
        return 1
      fi
    else
      error "No version specified and get_latest_version function not available"
      return 1
    fi
  fi

  info "Creating release pipeline for version ${version}"

  # Set the release pipeline
  cmd_set_pipeline "${RELEASE_PIPELINE_NAME}" "${foundation}" "${repo_name}" "${target}" "${environment}" "${datacenter}" "${datacenter_type}" "${branch}" "${git_release_branch}" "${version_file}" "${timer_duration}" "${version}" "${dry_run}" "${verbose}" "${foundation_path}" "${git_uri}" "${config_git_uri}" "${config_git_branch}" "${params_git_branch}"
  return $?
}
