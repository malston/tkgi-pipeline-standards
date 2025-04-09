#!/usr/bin/env bash
# Command implementation for promote-pipeline

function cmd_promote_pipeline_usage() {
  cat <<EOF
Usage: ./fly.sh promote-pipeline [options]

Promote a pipeline from development to the Ops Concourse instance.

Options:
  -p, --pipeline  PIPELINE      Pipeline to promote (install, upgrade, test)
  -d, --datacenter DATACENTER   Datacenter (cml, cic)
  -f, --foundation FOUNDATION   Foundation name (e.g., cml-k8s-n-01)
  -P, --params-repo REPO_PATH   Path to params repository
  -o, --ops-target OPS_TARGET   Ops Concourse target name
  -v, --version   VERSION       Version to tag the promotion with
  -t, --team      TEAM          Ops Concourse team to promote to (default: platform-team)
  --no-validation               Skip pipeline validation step
  -d, --dry-run                 Print commands without executing them
  -h, --help                    Display this help message

Examples:
  ./ci/fly.sh promote-pipeline -p install -d cml -f cml-k8s-n-01 --ops-target ops-concourse
  ./ci/fly.sh promote-pipeline -p upgrade -d cic -f cic-vxrail-n-02 -v 1.2.3 --dry-run
EOF
  exit 1
}

function cmd_promote_pipeline() {
  local pipeline=""
  local datacenter=""
  local foundation=""
  local params_repo=""
  local ops_target=""
  local version=""
  local team="platform-team"
  local skip_validation=false
  local dry_run=false

  # Parse command-specific options
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -p | --pipeline)
      pipeline="$2"
      shift 2
      ;;
    -d | --datacenter)
      datacenter="$2"
      shift 2
      ;;
    -f | --foundation)
      foundation="$2"
      shift 2
      ;;
    -P | --params-repo)
      params_repo="$2"
      shift 2
      ;;
    -o | --ops-target)
      ops_target="$2"
      shift 2
      ;;
    -v | --version)
      version="$2"
      shift 2
      ;;
    -t | --team)
      team="$2"
      shift 2
      ;;
    --no-validation)
      skip_validation=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h | --help)
      cmd_promote_pipeline_usage
      ;;
    *)
      error "Unknown option: $1"
      cmd_promote_pipeline_usage
      ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$pipeline" ]]; then
    error "Pipeline not specified. Use -p or --pipeline option."
    cmd_promote_pipeline_usage
  fi

  if [[ -z "$datacenter" ]]; then
    error "Datacenter not specified. Use -d or --datacenter option."
    cmd_promote_pipeline_usage
  fi

  if [[ -z "$foundation" ]]; then
    error "Foundation not specified. Use -f or --foundation option."
    cmd_promote_pipeline_usage
  fi

  if [[ -z "$ops_target" ]]; then
    error "Ops Concourse target not specified. Use -o or --ops-target option."
    cmd_promote_pipeline_usage
  fi

  # Try to read params repo from config if not provided
  if [[ -z "$params_repo" ]]; then
    if [[ -f "${REPO_ROOT}/.pipeline-config" ]]; then
      params_repo=$(grep "^params_repo=" "${REPO_ROOT}/.pipeline-config" | cut -d= -f2)
    fi

    if [[ -z "$params_repo" ]]; then
      error "Params repository not specified. Use -P or --params-repo option."
      cmd_promote_pipeline_usage
    fi
  fi

  # Validate params repo exists
  if [[ ! -d "$params_repo" ]]; then
    error "Params repository directory does not exist: $params_repo"
    cmd_promote_pipeline_usage
  fi

  # Validate datacenter is valid
  if [[ ! "$datacenter" =~ ^(cml|cic)$ ]]; then
    error "Invalid datacenter: $datacenter. Must be one of: cml, cic"
    cmd_promote_pipeline_usage
  fi

  # Validate foundation follows naming convention
  if [[ "$datacenter" == "cml" && ! "$foundation" =~ ^cml-k8s-n-[0-9]{2}$ ]]; then
    error "Invalid CML foundation name: $foundation. Must follow pattern: cml-k8s-n-XX"
    cmd_promote_pipeline_usage
  elif [[ "$datacenter" == "cic" && ! "$foundation" =~ ^cic-vxrail-n-[0-9]{2}$ ]]; then
    error "Invalid CIC foundation name: $foundation. Must follow pattern: cic-vxrail-n-XX"
    cmd_promote_pipeline_usage
  fi

  # Get component name from repo directory
  local component=$(basename "$REPO_ROOT")

  # Set default version if not provided
  if [[ -z "$version" ]]; then
    if [[ -f "${REPO_ROOT}/release/versions.yml" ]]; then
      version=$(yq e ".${component}.version" "${REPO_ROOT}/release/versions.yml")
      info "Using current version from versions.yml: $version"
    else
      error "Version not specified and versions.yml not found."
      exit 1
    fi
  fi

  # Validate pipeline file exists
  local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
  if [[ ! -f "$pipeline_file" ]]; then
    error "Pipeline file not found: $pipeline_file"
    exit 1
  fi

  # Ensure we're logged in to both targets
  check_fly_target "$TARGET"
  check_fly_target "$ops_target"

  # Validate pipeline if required
  if [[ "$skip_validation" == "false" ]]; then
    info "Validating pipeline before promotion"
    if ! fly -t "$TARGET" validate-pipeline -c "$pipeline_file"; then
      error "Pipeline validation failed"
      exit 1
    fi
    success "Pipeline validation passed"
  fi

  # Create pipeline name for ops instance
  local ops_pipeline_name="${component}-${pipeline}-${foundation}"

  # Inform about the promotion
  info "Promoting pipeline '${pipeline}' for ${foundation} to ${team} team"
  info "Target Concourse: ${ops_target}"
  info "Component: ${component}"
  info "Version: ${version}"

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

  # Construct the fly command for promotion
  local promotion_cmd=(
    "fly" "-t" "${ops_target}"
    "set-pipeline"
    "-p" "${ops_pipeline_name}"
    "-c" "${pipeline_file}"
    "-v" "foundation=${foundation}"
    "-v" "datacenter=${datacenter}"
    "-v" "component=${component}"
    "-v" "version=${version}"
    "-n"
  )

  # Add all vars files
  for var_file in "${vars_files[@]}"; do
    promotion_cmd+=("$var_file")
  done

  # Add team if specified
  if [[ -n "$team" ]]; then
    promotion_cmd+=("-t" "$team")
  fi

  # Execute or simulate the promotion
  if [[ "$dry_run" == "true" ]]; then
    info "DRY RUN: Would execute:"
    echo "${promotion_cmd[*]}"
  else
    info "Executing promotion command"
    "${promotion_cmd[@]}"

    # Update the versions file
    if [[ -f "${REPO_ROOT}/release/versions.yml" ]]; then
      info "Updating versions.yml with promotion details"
      tmp_versions=$(mktemp)
      yq e ".${component}.version = \"${version}\" | 
            .${component}.promotions.${datacenter}.${foundation}.pipeline = \"${pipeline}\" | 
            .${component}.promotions.${datacenter}.${foundation}.date = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
        "${REPO_ROOT}/release/versions.yml" >"$tmp_versions"
      mv "$tmp_versions" "${REPO_ROOT}/release/versions.yml"
    else
      warn "versions.yml not found, creating a new one"
      mkdir -p "${REPO_ROOT}/release"
      cat >"${REPO_ROOT}/release/versions.yml" <<EOF
${component}:
  version: "${version}"
  promotions:
    ${datacenter}:
      ${foundation}:
        pipeline: "${pipeline}"
        date: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EOF
    fi

    success "Pipeline successfully promoted to ${ops_target} as ${ops_pipeline_name}"
  fi
}

# Check if a fly target exists and is logged in
function check_fly_target() {
  local target="$1"

  if ! fly targets | grep -q "$target"; then
    error "Target '$target' does not exist. Please login first."
    info "Try: ./ci/fly.sh login -t $target"
    exit 1
  fi

  # Check if we need to relogin by attempting a simple fly command
  if ! fly -t "$target" containers &>/dev/null; then
    error "Session for target '$target' has expired. Please login again."
    info "Try: ./ci/fly.sh login -t $target"
    exit 1
  fi
}
