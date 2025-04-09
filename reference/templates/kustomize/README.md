# Kustomize-based Repository Template

This template provides a standardized structure for repositories that use Kustomize for Kubernetes resource management.

## Repository Structure

```
repository-root/
├── ci/
│   ├── pipelines/
│   │   ├── main.yml                # Main pipeline
│   │   ├── release.yml             # Release pipeline
│   │   └── set-pipeline.yml        # Pipeline management pipeline
│   ├── scripts/
│   │   ├── fly.sh                  # Pipeline management script
│   │   └── helpers.sh              # Helper functions for CI
│   ├── tasks/
│   │   ├── common/
│   │   │   ├── kustomize/
│   │   │   │   ├── task.yml        # Task definition
│   │   │   │   └── task.sh         # Task implementation
│   │   │   ├── kubectl-apply/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── prepare-kustomize/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── k8s/
│   │   │   ├── create-resources/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── validate-resources/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── tkgi/
│   │   │   └── tkgi-login/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   └── testing/
│   │       └── run-tests/
│   │           ├── task.yml
│   │           └── task.sh
│   └── vars/
│       ├── common.yml              # Common variables
│       ├── lab.yml                 # Environment-specific variables
│       └── nonprod.yml             # Environment-specific variables
├── scripts/
│   ├── apply.sh                    # Apply resources script
│   ├── build.sh                    # Build kustomize resources
│   ├── helpers.sh                  # Common helper functions
│   └── validate.sh                 # Validate resources
├── base/                           # Kustomize base configurations
│   ├── kustomization.yaml
│   └── resources.yaml
├── components/                     # Kustomize components 
│   └── component1/
│       └── kustomization.yaml
├── overlays/                       # Kustomize overlays
│   ├── lab/
│   │   └── kustomization.yaml
│   └── nonprod/
│       └── kustomization.yaml
└── test/                           # Tests
    ├── scripts/
    │   └── test-resources.sh
    └── tests.sh                    # Main test script
```

## Task Organization

Each task is organized in its own directory with two key files:

1. `task.yml` - The Concourse task definition
2. `task.sh` - The task implementation script

This structure provides clear organization and makes it easy to locate task definitions and implementations.

### Task Script Pattern

Task scripts follow a standard pattern:

1. They validate required environment variables
2. They invoke corresponding repository scripts when possible
3. They maintain a consistent interface

### Relationship with Repository Scripts

The task scripts (`ci/tasks/*/task.sh`) serve as pipeline-specific wrappers that:

1. Handle pipeline-specific aspects (inputs, outputs, etc.)
2. Call into the repository scripts in `scripts/` for core functionality
3. Format outputs for pipeline consumption

This approach allows:
- Scripts to be used directly from the command line
- Tasks to focus on pipeline integration
- Core functionality to be tested independently of the pipeline

## Implementation Notes

See the example files in this template for concrete implementations.