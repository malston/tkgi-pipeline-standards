#!/usr/bin/env bash
# Command implementation for set-pipeline

function cmd_set_pipeline_usage() {
  cat <<EOF
Usage: ./fly.sh set-pipeline [options]

Set or update a pipeline in Concourse.

Options:
  -p, --pipeline  PIPELINE      Pipeline name (required)
  -d, --datacenter DATACENTER   Datacenter (cml, cic)
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01, cic-vxrail-n-02)
  -P, --params-repo REPO_PATH   Path to params repository (required if not set in config)
  -n, --non-interactive         Non-interactive mode
  -s, --self-update             Update this pipeline itself
  -h, --help                    Display this help message

Examples:
  ./ci/fly.sh set-pipeline -t dev -p main -d cml -f cml-k8s-n-01
  ./ci/fly.sh set-pipeline -t dev -p release -d cic -f cic-vxrail-n-02 -n
  ./ci/fly.sh set-pipeline -t dev -p main -P ~/repos/params -d cml -f cml-k8s-n-01
EOF
  exit 1
}

function cmd_set_pipeline() {
  check_fly
  
  local pipeline=""
  local datacenter=""
  local foundation=""
  local params_repo=""
  local non_interactive=false
  local self_update=false

  # Parse command-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--pipeline)
        pipeline="$2"
        shift 2
        ;;
      -d|--datacenter)
        datacenter="$2"
        shift 2
        ;;
      -f|--foundation)
        foundation="$2"
        shift 2
        ;;
      -P|--params-repo)
        params_repo="$2"
        shift 2
        ;;
      -n|--non-interactive)
        non_interactive=true
        shift
        ;;
      -s|--self-update)
        self_update=true
        shift
        ;;
      -h|--help)
        cmd_set_pipeline_usage
        ;;
      *)
        error "Unknown option: $1"
        cmd_set_pipeline_usage
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$pipeline" ]]; then
    error "Pipeline name not specified. Use -p or --pipeline option."
    cmd_set_pipeline_usage
  fi
  
  # Try to read params repo from config if not provided
  if [[ -z "$params_repo" ]]; then
    if [[ -f "${REPO_ROOT}/.pipeline-config" ]]; then
      params_repo=$(grep "^params_repo=" "${REPO_ROOT}/.pipeline-config" | cut -d= -f2)
    fi
    
    if [[ -z "$params_repo" ]]; then
      error "Params repository not specified. Use -P or --params-repo option."
      cmd_set_pipeline_usage
    fi
  fi
  
  # Validate params repo exists
  if [[ ! -d "$params_repo" ]]; then
    error "Params repository directory does not exist: $params_repo"
    cmd_set_pipeline_usage
  fi
  
  # For self-update, we're updating the pipeline management pipeline
  if [[ "$self_update" == "true" ]]; then
    info "Setting up self-update pipeline"
    pipeline="pipeline-manager"
    
    # Construct pipeline file path
    local pipeline_file="${CI_DIR}/pipelines/set-pipeline.yml"
    
    # Validate pipeline file exists
    if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
      exit 1
    fi
    
    local vars_files=(
      "-l" "${params_repo}/global.yml"
    )
    
    # Execute the command
    info "Setting pipeline: ${pipeline}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
      info "DRY RUN: Would execute:"
      info "fly -t \"$TARGET\" set-pipeline -p \"${pipeline}\" -c \"${pipeline_file}\" ${vars_files[@]} ${non_interactive:+-n}"
    else
      fly -t "$TARGET" set-pipeline \
        -p "${pipeline}" \
        -c "${pipeline_file}" \
        "${vars_files[@]}" \
        ${non_interactive:+-n}
        
      success "Self-update pipeline '${pipeline}' set successfully"
    fi
    
    return 0
  fi
  
  # Regular component pipeline
  if [[ -z "$datacenter" ]]; then
    error "Datacenter not specified. Use -d or --datacenter option."
    cmd_set_pipeline_usage
  fi
  
  if [[ -z "$foundation" ]]; then
    error "Foundation not specified. Use -f or --foundation option."
    cmd_set_pipeline_usage
  fi
  
  # Validate datacenter is valid
  if [[ ! "$datacenter" =~ ^(cml|cic)$ ]]; then
    error "Invalid datacenter: $datacenter. Must be one of: cml, cic"
    cmd_set_pipeline_usage
  fi
  
  # Validate foundation follows naming convention
  if [[ "$datacenter" == "cml" && ! "$foundation" =~ ^cml-k8s-n-[0-9]{2}$ ]]; then
    error "Invalid CML foundation name: $foundation. Must follow pattern: cml-k8s-n-XX"
    cmd_set_pipeline_usage
  elif [[ "$datacenter" == "cic" && ! "$foundation" =~ ^cic-vxrail-n-[0-9]{2}$ ]]; then
    error "Invalid CIC foundation name: $foundation. Must follow pattern: cic-vxrail-n-XX"
    cmd_set_pipeline_usage
  fi
  
  # Get component name from repo directory
  local component=$(basename "$REPO_ROOT" | sed 's/-mgmt//')
  
  # Construct pipeline file path
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
  
  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    exit 1
  fi
  
  # Build the list of vars files in the correct hierarchy
  local vars_files=(
    "-l" "${params_repo}/global.yml"
    "-l" "${params_repo}/k8s-global.yml"
    "-l" "${params_repo}/global-lab.yml"
    "-l" "${params_repo}/${datacenter}/${datacenter}.yml"
    "-l" "${params_repo}/${datacenter}/${foundation}.yml"
  )
  
  # Add component-specific common vars if they exist
  if [[ -f "${CI_DIR}/vars/common.yml" ]]; then
    vars_files+=("-l" "${CI_DIR}/vars/common.yml")
  fi
  
  # Add component-specific datacenter vars if they exist
  if [[ -f "${CI_DIR}/vars/${datacenter}.yml" ]]; then
    vars_files+=("-l" "${CI_DIR}/vars/${datacenter}.yml")
  fi
  
  # Add component-specific foundation vars if they exist
  if [[ -f "${CI_DIR}/vars/${foundation}.yml" ]]; then
    vars_files+=("-l" "${CI_DIR}/vars/${foundation}.yml")
  fi
  
  # Add component-specific pipeline vars if they exist
  if [[ -f "${CI_DIR}/vars/${pipeline}.yml" ]]; then
    vars_files+=("-l" "${CI_DIR}/vars/${pipeline}.yml")
  fi
  
  # Construct the pipeline name: component-pipeline-foundation
  local pipeline_name="${component}-${pipeline}-${foundation}"
  
  # Execute the command
  info "Setting pipeline: ${pipeline_name}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" set-pipeline -p \"${pipeline_name}\" -c \"${pipeline_file}\" ${vars_files[@]} -v \"foundation=${foundation}\" -v \"datacenter=${datacenter}\" -v \"component=${component}\" ${non_interactive:+-n}"
  else
    fly -t "$TARGET" set-pipeline \
      -p "${pipeline_name}" \
      -c "${pipeline_file}" \
      "${vars_files[@]}" \
      -v "foundation=${foundation}" \
      -v "datacenter=${datacenter}" \
      -v "component=${component}" \
      ${non_interactive:+-n}
      
    success "Pipeline '${pipeline_name}' set successfully"
  fi
  
  # Save the params repo location for future use
  if [[ ! -f "${REPO_ROOT}/.pipeline-config" ]] || ! grep -q "^params_repo=" "${REPO_ROOT}/.pipeline-config"; then
    echo "params_repo=${params_repo}" > "${REPO_ROOT}/.pipeline-config"
    info "Saved params repository location to .pipeline-config"
  fi
}

function cmd_unpause_pipeline() {
  # Similar to cmd_set_pipeline but also unpauses the pipeline
  cmd_set_pipeline "$@"
  
  local pipeline_name="${component}-${pipeline}-${foundation}"
  
  info "Unpausing pipeline: ${pipeline_name}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "DRY RUN: Would execute:"
    info "fly -t \"$TARGET\" unpause-pipeline -p \"${pipeline_name}\""
  else
    fly -t "$TARGET" unpause-pipeline -p "${pipeline_name}"
    success "Pipeline '${pipeline_name}' unpaused successfully"
  fi
}

function cmd_destroy_pipeline() {
  # Implementation of pipeline destruction command
  check_fly
  
  local pipeline=""
  local confirmation=""
  
  # Parse command-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--pipeline)
        pipeline="$2"
        shift 2
        ;;
      -y|--yes)
        confirmation="yes"
        shift
        ;;
      -h|--help)
        cmd_destroy_pipeline_usage
        ;;
      *)
        if [[ -z "$pipeline" ]]; then
          pipeline="$1"
        else
          error "Unknown option: $1"
          cmd_destroy_pipeline_usage
        fi
        shift
        ;;
    esac
  done
  
  # Validate required parameters
  if [[ -z "$pipeline" ]]; then
    error "Pipeline name not specified. Use -p or --pipeline option."
    cmd_destroy_pipeline_usage
  fi
  
  # Get component name from repo directory
  local component=$(basename "$REPO_ROOT" | sed 's/-mgmt//')
  
  # Construct the pipeline name: component-pipeline-foundation
  local pipeline_name="${component}-${pipeline}-${foundation}"
  
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

function cmd_validate_pipeline() {
  # Implementation of pipeline validation command
  local pipeline=""
  
  # Parse command-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--pipeline)
        pipeline="$2"
        shift 2
        ;;
      -h|--help)
        cmd_validate_pipeline_usage
        ;;
      *)
        if [[ -z "$pipeline" && "$1" != "all" ]]; then
          pipeline="$1"
        elif [[ "$1" == "all" ]]; then
          pipeline="all"
        else
          error "Unknown option: $1"
          cmd_validate_pipeline_usage
        fi
        shift
        ;;
    esac
  done
  
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
  if [[ -z "$pipeline" ]]; then
    error "Pipeline name not specified. Use -p or --pipeline option."
    cmd_validate_pipeline_usage
  fi
  
  # Construct pipeline file path
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
  
  # Validate pipeline file exists
  if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
    exit 1
  fi
  
  info "Validating pipeline: ${pipeline}"
  
  fly validate-pipeline -c "${pipeline_file}" || {
    error "Pipeline validation failed: ${pipeline}"
    return 1
  }
  
  success "Pipeline validated successfully: ${pipeline}"
}