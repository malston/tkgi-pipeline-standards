# CI/CD Standardization Implementation Checklist

Use this checklist when implementing the standardized CI/CD structure in a repository.

## Initial Assessment

- [ ] Identify the component type (Kustomize, Helm, or CLI Tool)
- [ ] Review current CI/CD structure
- [ ] Identify custom tasks or requirements specific to this component
- [ ] Review pipeline dependencies on other repositories

## Repository Structure

- [ ] Create standard CI directory structure:
  - [ ] `ci/pipelines/` directory
  - [ ] `ci/scripts/` directory
  - [ ] `ci/tasks/` directory with category subdirectories

- [ ] Implement task directories based on component type:
  - [ ] Common tasks
  - [ ] Component-specific tasks (kustomize, helm, or cli-tool)
  - [ ] K8s tasks
  - [ ] TKGi tasks
  - [ ] Testing tasks

## Task Implementation

- [ ] Create task YAML files:
  - [ ] Use standardized inputs/outputs
  - [ ] Reference task.sh scripts with correct paths
  - [ ] Include all required parameters

- [ ] Create task shell scripts:
  - [ ] Use standardized headers
  - [ ] Include parameter validation
  - [ ] Update path references
  - [ ] Add proper error handling

## Pipeline Configuration

- [ ] Implement standardized pipelines:
  - [ ] Component management pipeline
  - [ ] Release pipeline
  - [ ] Set-pipeline pipeline

- [ ] Use consistent resource naming
- [ ] Use task references with the correct paths
- [ ] Include appropriate triggers
- [ ] Ensure all requirements are present

## fly.sh Script

- [ ] Implement standardized `fly.sh` script:
  - [ ] Support for all standard commands
  - [ ] Support for special commands (release, set-pipeline)
  - [ ] Standard options for foundation, environment, etc.
  - [ ] Component-specific options if needed

## Documentation

- [ ] Create CI/README.md with:
  - [ ] Directory structure explanation
  - [ ] Pipeline descriptions
  - [ ] Task descriptions
  - [ ] Usage examples

- [ ] Update main README.md with CI/CD information

## Params Repository Updates

- [ ] Update params repository with required parameters:
  - [ ] Foundation-specific parameters
  - [ ] Component-specific parameters
  - [ ] Environment-specific parameters
  - [ ] Ensure release tags are properly configured

## Testing

- [ ] Validate pipeline files:
  ```bash
  ./ci/scripts/fly.sh validate all
  ```

- [ ] Test pipeline setting with dry run:
  ```bash
  ./ci/scripts/fly.sh -f <foundation> --dry-run
  ```

- [ ] Test component pipeline in lab environment:
  ```bash
  ./ci/scripts/fly.sh -f <foundation>
  ```

- [ ] Test release pipeline in lab environment:
  ```bash
  ./ci/scripts/fly.sh -f <foundation> -r "Test release"
  ```

- [ ] Test set-pipeline pipeline in lab environment:
  ```bash
  ./ci/scripts/fly.sh -f <foundation> -s
  ```

## Backward Compatibility

- [ ] Verify wrapper scripts are in place for existing tasks
- [ ] Ensure original paths still work in existing pipelines
- [ ] Verify no disruption to automated processes

## Final Steps

- [ ] Remove any unused files or scripts
- [ ] Create pull request with detailed description of changes
- [ ] Update component catalog or documentation with standardization status
- [ ] Schedule migration of other pipeline references
