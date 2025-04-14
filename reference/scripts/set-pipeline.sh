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
  ./ci/fly.sh set-pipeline -t dev -p install -d cml -f cml-k8s-n-01
  ./ci/fly.sh set-pipeline -t dev -p upgrade -d cic -f cic-vxrail-n-02 -n
  ./ci/fly.sh set-pipeline -t dev -p install -P ~/repos/params -d cml -f cml-k8s-n-01
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
    local pipeline_file="${CI_DIR}/pipelines/pipeline-manager.yml"
    
    # Validate pipeline file exists
    if ! validate_file_exists "$pipeline_file" "Pipeline file"; then
      exit 1
    fi
    
    local vars_files=(
      "-l" "${params_repo}/global.yml"
    )
    
    # Execute the command
    info "Setting pipeline: ${pipeline}"
    fly -t "$TARGET" set-pipeline \
      -p "${pipeline}" \
      -c "${pipeline_file}" \
      "${vars_files[@]}" \
      ${non_interactive:+-n}
      
    success "Self-update pipeline '${pipeline}' set successfully"
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
  local component=$(basename "$REPO_ROOT")
  
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
  fly -t "$TARGET" set-pipeline \
    -p "${pipeline_name}" \
    -c "${pipeline_file}" \
    "${vars_files[@]}" \
    -v "foundation=${foundation}" \
    -v "datacenter=${datacenter}" \
    -v "component=${component}" \
    ${non_interactive:+-n}
    
  success "Pipeline '${pipeline_name}' set successfully"
  
  # Save the params repo location for future use
  if [[ ! -f "${REPO_ROOT}/.pipeline-config" ]] || ! grep -q "^params_repo=" "${REPO_ROOT}/.pipeline-config"; then
    echo "params_repo=${params_repo}" > "${REPO_ROOT}/.pipeline-config"
    info "Saved params repository location to .pipeline-config"
  fi
}