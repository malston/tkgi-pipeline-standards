#!/usr/bin/env bash
#
# Command implementations for fly.sh
# Contains the implementation of the various commands supported by the script
#

# Implementation of set pipeline command
function cmd_set_pipeline() {
  check_fly

  # Prepare variables
  local pipeline_name="${PIPELINE}-${FOUNDATION}"
  local pipeline_file="${CI_DIR}/pipelines/${PIPELINE}.yml"

  # Handle release pipeline
  if [[ "$PIPELINE" == "release" ]]; then
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
    "-v" "foundation=${FOUNDATION}"
    "-v" "environment=${ENVIRONMENT}"
    "-v" "branch=${BRANCH}"
    "-v" "timer_duration=${TIMER_DURATION}"
    "-v" "verbose=${VERBOSE}"
  )

  # Add version if set
  if [[ -n "${VERSION}" ]]; then
    vars+=("-v" "version=${VERSION}")
  fi

  # Add datacenter if available
  if [[ -n "${DATACENTER}" ]]; then
    vars+=("-v" "datacenter=${DATACENTER}")
  fi

  # Add foundation path
  if [[ -n "${DATACENTER}" ]]; then
    vars+=("-v" "foundation_path=${DATACENTER}/${FOUNDATION}")
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
    if [[ -d "${params_path}/${DATACENTER}" ]]; then
      if [[ -f "${params_path}/${DATACENTER}/${DATACENTER}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${DATACENTER}/${DATACENTER}.yml")
      fi

      if [[ -f "${params_path}/${DATACENTER}/${FOUNDATION}.yml" ]]; then
        vars_files+=("-l" "${params_path}/${DATACENTER}/${FOUNDATION}.yml")
      fi
    fi
  fi

  # Execute the command
  info "Setting pipeline: ${pipeline_name}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" set-pipeline -p \"${pipeline_name}\" -c \"${pipeline_file}\" ${vars_files[*]} ${vars[*]}"
  else
    # With vars_files
    if [[ ${#vars_files[@]} -gt 0 ]]; then
      fly -t "$TARGET" set-pipeline \
        -p "${pipeline_name}" \
        -c "${pipeline_file}" \
        "${vars_files[@]}" \
        "${vars[@]}"
    else
      # Without vars_files
      fly -t "$TARGET" set-pipeline \
        -p "${pipeline_name}" \
        -c "${pipeline_file}" \
        "${vars[@]}"
    fi

    success "Pipeline '${pipeline_name}' set successfully"
  fi
}

# Implementation of unpause pipeline command
function cmd_unpause_pipeline() {
  # First set the pipeline
  cmd_set_pipeline

  local pipeline_name="${PIPELINE}-${FOUNDATION}"

  info "Unpausing pipeline: ${pipeline_name}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" unpause-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$TARGET" unpause-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' unpaused successfully"
  fi
}

# Implementation of destroy pipeline command
function cmd_destroy_pipeline() {
  check_fly

  local pipeline_name="${PIPELINE}-${FOUNDATION}"
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

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" destroy-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$TARGET" destroy-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' destroyed successfully"
  fi
}

# Implementation of validate pipeline command
function cmd_validate_pipeline() {
  # Determine pipeline file
  local pipeline_file="${CI_DIR}/pipelines/${PIPELINE}.yml"

  # Handle special pipeline names
  if [[ "$PIPELINE" == "release" ]]; then
    pipeline_file="${CI_DIR}/pipelines/release.yml"
  fi

  # Validate all pipelines if requested
  if [[ "$PIPELINE" == "all" ]]; then
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

  info "Validating pipeline: ${PIPELINE}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly validate-pipeline -c \"${pipeline_file}\""
  else
    fly validate-pipeline -c "${pipeline_file}" || {
      error "Pipeline validation failed: ${PIPELINE}"
      return 1
    }

    success "Pipeline validated successfully: ${PIPELINE}"
  fi
}

# Implementation of release pipeline command (legacy behavior)
function cmd_release_pipeline() {
  # Switch to release pipeline
  PIPELINE="release"

  # Set the pipeline
  cmd_set_pipeline
}