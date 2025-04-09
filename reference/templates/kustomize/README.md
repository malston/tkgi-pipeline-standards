# Kustomize-based Repository Template

This template provides a standardized structure for repositories that use Kustomize for Kubernetes resource management. It follows the CI/CD standardization approach implemented in the ns-mgmt repository migration while also providing more advanced options.

## Repository Structure

```
repository-root/
├── ci/
│   ├── fly.sh                  # Simple pipeline management script (ns-mgmt style)
│   ├── pipelines/
│   │   ├── main.yml            # Main pipeline
│   │   ├── release.yml         # Release pipeline
│   │   └── set-pipeline.yml    # Pipeline management pipeline
│   ├── scripts/
│   │   ├── fly.sh              # Advanced pipeline management script
│   │   └── cmd_set_pipeline.sh # Command implementations
│   ├── tasks/
│   │   ├── common/             # Common/shared tasks
│   │   │   ├── kustomize/
│   │   │   │   ├── task.yml    # Task definition
│   │   │   │   └── task.sh     # Task implementation
│   │   │   ├── kubectl-apply/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── prepare-kustomize/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── k8s/                # Kubernetes-specific tasks
│   │   │   ├── create-resources/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── validate-resources/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── tkgi/               # TKGi-specific tasks
│   │   │   └── tkgi-login/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   └── testing/            # Testing-related tasks
│   │       └── run-tests/
│   │           ├── task.yml
│   │           └── task.sh
│   └── README.md               # Documentation for CI process
├── scripts/                    # Repository-level scripts
│   ├── apply.sh                # Apply resources script
│   ├── build.sh                # Build kustomize resources
│   ├── helpers.sh              # Common helper functions
│   └── validate.sh             # Validate resources
├── base/                       # Kustomize base configurations
│   ├── kustomization.yaml
│   └── resources.yaml
├── components/                 # Kustomize components 
│   └── component1/
│       └── kustomization.yaml
├── overlays/                   # Kustomize overlays
│   ├── lab/
│   │   └── kustomization.yaml
│   └── nonprod/
│       └── kustomization.yaml
└── test/                       # Tests
    ├── scripts/
    │   └── test-resources.sh
    └── tests.sh                # Main test script
```

## CI Structure Overview

This template provides a hybrid approach that combines:

1. **NS-MGMT Style Structure**: 
   - Simple `fly.sh` script in the root of the `ci` directory
   - Task organization by functional category (common, k8s, tkgi, testing)
   - Task structure with task.yml and task.sh files in each directory

2. **Advanced Functionality**:
   - More comprehensive `fly.sh` script in the `ci/scripts` directory
   - Additional command implementations for advanced pipeline management
   - Support for various environments, configurations, and options

This hybrid approach allows you to use the simpler style following the ns-mgmt pattern while still having access to more advanced functionality when needed.

## Task Organization

Tasks are organized into the following categories:

### Common Tasks
General-purpose tasks used across different pipelines:
- `common/kustomize/`: Builds Kubernetes resources using kustomize
- `common/kubectl-apply/`: Applies Kubernetes resources to clusters
- `common/prepare-kustomize/`: Prepares configurations for kustomize
- `common/set-pipeline/`: Sets or updates pipelines

### Kubernetes (k8s) Tasks
Kubernetes-specific tasks:
- `k8s/create-resources/`: Creates Kubernetes resources
- `k8s/validate-resources/`: Validates Kubernetes resources

### TKGi Tasks
TKGi-specific operations:
- `tkgi/tkgi-login/`: Authenticates with TKGi/PKS

### Testing Tasks
Test execution and validation:
- `testing/run-tests/`: Executes tests for the repository

## Task Structure

Each task is composed of two files:

1. **task.yml**: The Concourse task definition containing:
   - Platform specification
   - Input/output definitions
   - Run command
   - Parameter definitions

2. **task.sh**: The task implementation script containing:
   - Parameter validation
   - Main implementation logic
   - Error handling

### Example task.yml
```yaml
---
platform: linux

inputs:
  - name: repo         # Repository containing task scripts
  - name: config       # Configuration repository

outputs:
  - name: manifests    # Generated Kubernetes manifests

run:
  path: repo/ci/tasks/common/kustomize/task.sh

params:
  # Required parameters
  FOUNDATION: ((foundation))            # Foundation name
  
  # Optional parameters
  FOUNDATION_PATH: ((foundation_path))  # Path within config repo
  VERBOSE: ((verbose))                  # Enable verbose output
```

### Example task.sh
```bash
#!/usr/bin/env bash
#
# Task: kustomize
# Description: Builds Kubernetes resources using kustomize
#
# Required Environment Variables:
#   - FOUNDATION: Foundation name (e.g., cml-k8s-n-01)
#
# Optional Environment Variables:
#   - FOUNDATION_PATH: Path within config repo (default: foundations/${FOUNDATION})
#   - VERBOSE: Enable verbose output (default: false)
#

# Enable strict mode
set -o errexit
set -o pipefail

# Get script directory for relative paths
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Get repository root directory (4 levels up from task dir)
REPO_ROOT="$(cd "${__DIR}/../../../../.." &>/dev/null && pwd)"

# Source helper functions
source "${REPO_ROOT}/scripts/helpers.sh"

# Main task logic
# ...
```

## Pipeline Structure

Pipelines follow a standardized approach:

1. **Resource Definitions**: Clear definition of required resources
2. **Job Organization**: Jobs organized by purpose
3. **Task References**: Tasks referenced using file references, not inline definitions

### Example Pipeline (main.yml)

```yaml
---
groups:
  - name: overview
    jobs: 
      - validate
      - build-and-deploy

resources:
  - name: repo
    type: git
    source:
      uri: ((github_uri))
      branch: ((branch))

jobs:
  - name: build-and-deploy
    plan:
      - get: repo
        trigger: true
      - get: config
        trigger: true
      
      # Login to TKGi cluster
      - task: tkgi-login
        file: repo/ci/tasks/tkgi/tkgi-login/task.yml
        params:
          FOUNDATION: ((foundation))
          PKS_API_URL: ((pks_api_url))
      
      # Build kustomize manifests
      - task: build-manifests
        file: repo/ci/tasks/common/kustomize/task.yml
        params:
          FOUNDATION: ((foundation))
          FOUNDATION_PATH: ((foundation_path))
```

## Implementation Notes

This template aligns with the CI/CD standardization work done in the ns-mgmt repository migration while providing additional advanced functionality:

1. **Dual fly.sh Scripts**:
   - Simple version in `ci/fly.sh` (like ns-mgmt)
   - Advanced version in `ci/scripts/fly.sh` with more features

2. **Standard Task Structure**:
   - Tasks organized by functional category
   - Consistent task.yml and task.sh files
   - Clear separation between task definition and implementation

3. **Clear Pipeline References**:
   - Tasks referenced using file paths instead of inline definitions
   - Consistent naming and organization of pipeline components

4. **Script Organization**:
   - Repository scripts separate from CI task scripts
   - Helper functions for common operations
   - Consistent error handling and logging
   - Comprehensive test suite for script validation

By following this template, you can ensure your repository is consistent with the standardized approach implemented across TKGi repositories while still having access to more advanced functionality when needed.

## Testing

This template includes a comprehensive test suite for validating script functionality:

```
ci/scripts/tests/
├── README.md                  # Test documentation
├── run_tests.sh               # Script to run all tests
├── test_framework.sh          # Test utilities and assertions
└── test_ns_mgmt_refactored.sh # Tests for ns-mgmt-refactored.sh
```

To run the tests:

```bash
cd ci/scripts/tests
./run_tests.sh
```

The test suite validates key functionality including:
- Command handling
- Option parsing
- Environment determination
- Flag behavior
- Advanced features like dry-run and validation

This ensures that scripts continue to work correctly after modifications and helps document expected behavior.