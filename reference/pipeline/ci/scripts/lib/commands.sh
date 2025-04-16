#!/usr/bin/env bash

# Enable strict mode
set -o errexit
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

#
# commands.sh - Command implementations for the fly.sh script
#

# Command: Set pipeline
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

    # Validate required pipeline file exists
    local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
    if ! verify_file_exists "${pipeline_file}"; then
        error "Pipeline file not found: ${pipeline_file}"
        return 1
    fi

    # Build pipeline name
    local pipeline_name="${pipeline}-${foundation}"
    if [[ -n "${version}" ]]; then
        pipeline_name="${pipeline_name}-${version}"
    fi

    # Build the fly command
    local fly_cmd=(
        "fly" "-t" "${target}" "set-pipeline"
        "-p" "${pipeline_name}"
        "-c" "${pipeline_file}"
    )

    # Add params files
    if [[ -f "${PARAMS_REPO}/${datacenter}/${foundation}.yml" ]]; then
        fly_cmd+=("-l" "${PARAMS_REPO}/${datacenter}/${foundation}.yml")
    fi

    if [[ -f "${PARAMS_REPO}/${datacenter}/${datacenter}-${datacenter_type}.yml" ]]; then
        fly_cmd+=("-l" "${PARAMS_REPO}/${datacenter}/${datacenter}-${datacenter_type}.yml")
    fi

    if [[ -f "${PARAMS_REPO}/${datacenter}/${datacenter}.yml" ]]; then
        fly_cmd+=("-l" "${PARAMS_REPO}/${datacenter}/${datacenter}.yml")
    fi

    if [[ -f "${PARAMS_REPO}/${datacenter_type}-global.yml" ]]; then
        fly_cmd+=("-l" "${PARAMS_REPO}/${datacenter_type}-global.yml")
    fi

    if [[ -f "${PARAMS_REPO}/global.yml" ]]; then
        fly_cmd+=("-l" "${PARAMS_REPO}/global.yml")
    fi

    # Add variables
    fly_cmd+=(
        "-v" "branch=${branch}"
        "-v" "foundation=${foundation}"
        "-v" "foundation_path=${foundation_path}"
        "-v" "verbose=${verbose}"
    )

    # Add optional variables
    if [[ -n "${environment}" ]]; then
        fly_cmd+=("-v" "environment=${environment}")
    fi

    if [[ -n "${git_uri}" ]]; then
        fly_cmd+=("-v" "git_uri=${git_uri}")
    fi

    if [[ -n "${config_git_uri}" ]]; then
        fly_cmd+=("-v" "config_git_uri=${config_git_uri}")
    fi

    if [[ -n "${config_git_branch}" ]]; then
        fly_cmd+=("-v" "config_git_branch=${config_git_branch}")
    fi

    if [[ -n "${params_git_branch}" ]]; then
        fly_cmd+=("-v" "params_git_branch=${params_git_branch}")
    fi

    if [[ -n "${version}" ]]; then
        fly_cmd+=("-v" "version=${version}")
    fi

    if [[ -n "${version_file}" ]]; then
        fly_cmd+=("-v" "version_file=${version_file}")
    fi

    if [[ -n "${timer_duration}" ]]; then
        fly_cmd+=("-v" "timer_duration=${timer_duration}")
    fi

    # Execute or show the command
    if [[ "${dry_run}" == "true" ]]; then
        info "DRY RUN: Would execute: ${fly_cmd[*]}"
    else
        info "Setting pipeline: ${pipeline_name}"
        debug "Executing: ${fly_cmd[*]}"
        if ! "${fly_cmd[@]}"; then
            error "Failed to set pipeline: ${pipeline_name}"
            return 1
        fi
        success "Pipeline set successfully: ${pipeline_name}"
    fi

    return 0
}

# Command: Set and unpause pipeline
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
    if ! cmd_set_pipeline "$@"; then
        return 1
    fi

    # Build pipeline name
    local pipeline_name="${pipeline}-${foundation}"
    if [[ -n "${version}" ]]; then
        pipeline_name="${pipeline_name}-${version}"
    fi

    # Build unpause command
    local fly_cmd=("fly" "-t" "${target}" "unpause-pipeline" "-p" "${pipeline_name}")

    # Execute or show the command
    if [[ "${dry_run}" == "true" ]]; then
        info "DRY RUN: Would execute: ${fly_cmd[*]}"
    else
        info "Unpausing pipeline: ${pipeline_name}"
        debug "Executing: ${fly_cmd[*]}"
        if ! "${fly_cmd[@]}"; then
            error "Failed to unpause pipeline: ${pipeline_name}"
            return 1
        fi
        success "Pipeline unpaused successfully: ${pipeline_name}"
    fi

    return 0
}

# Command: Destroy pipeline
function cmd_destroy_pipeline() {
    local pipeline="$1"
    local foundation="$2"
    local target="$3"
    local dry_run="$4"

    # Build pipeline name
    local pipeline_name="${pipeline}-${foundation}"

    # Build command
    local fly_cmd=("fly" "-t" "${target}" "destroy-pipeline" "-p" "${pipeline_name}")

    # Ask for confirmation in interactive mode
    if [[ -t 0 && "${TEST_MODE}" != "true" && "${dry_run}" != "true" ]]; then
        read -rp "Are you sure you want to destroy pipeline ${pipeline_name}? [y/N] " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            info "Aborting pipeline destruction"
            return 0
        fi
        # Add non-interactive flag if user confirmed
        fly_cmd+=("-n")
    else
        # Always add non-interactive flag in non-interactive mode
        fly_cmd+=("-n")
    fi

    # Execute or show the command
    if [[ "${dry_run}" == "true" ]]; then
        info "DRY RUN: Would execute: ${fly_cmd[*]}"
    else
        info "Destroying pipeline: ${pipeline_name}"
        debug "Executing: ${fly_cmd[*]}"
        if ! "${fly_cmd[@]}"; then
            # Don't consider it an error if pipeline doesn't exist
            if [[ $? -eq 2 ]]; then
                warn "Pipeline does not exist: ${pipeline_name}"
                return 0
            fi
            error "Failed to destroy pipeline: ${pipeline_name}"
            return 1
        fi
        success "Pipeline destroyed successfully: ${pipeline_name}"
    fi

    return 0
}

# Command: Validate pipeline YAML
function cmd_validate_pipeline() {
    local pipeline="$1"
    local dry_run="$2"

    # Always treat this as a dry run
    dry_run="true"

    # Validate required pipeline file exists
    local pipeline_file="${CI_DIR}/pipelines/${pipeline}.yml"
    if ! verify_file_exists "${pipeline_file}"; then
        error "Pipeline file not found: ${pipeline_file}"
        return 1
    fi

    info "Validating pipeline file: ${pipeline_file}"

    # Use fly format-pipeline to validate syntax
    local fly_cmd=("fly" "format-pipeline" "-c" "${pipeline_file}" "--write-result")

    debug "Executing: ${fly_cmd[*]}"
    if ! "${fly_cmd[@]}" >/dev/null; then
        error "Pipeline validation failed: ${pipeline_file}"
        return 1
    fi

    success "Pipeline file is valid: ${pipeline_file}"
    return 0
}

# Command: Create release pipeline
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

    # Version is required for release pipeline
    if [[ -z "${version}" ]]; then
        error "Version is required for release pipeline (use --version)"
        return 1
    fi

    # Normalize the version
    version=$(normalize_version "${version}")

    # Set release pipeline name
    local release_pipeline="release"

    # Call set_pipeline with the release pipeline
    if ! cmd_set_pipeline "${release_pipeline}" "${foundation}" "${repo_name}" "${target}" "${environment}" "${datacenter}" "${datacenter_type}" "${branch}" "${git_release_branch}" "${version_file}" "${timer_duration}" "${version}" "${dry_run}" "${verbose}" "${foundation_path}" "${git_uri}" "${config_git_uri}" "${config_git_branch}" "${params_git_branch}"; then
        return 1
    fi

    success "Release pipeline created successfully for version ${version}"
    return 0
}
