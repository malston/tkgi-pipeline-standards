# Kustomize Component Template

This template is designed for components that use Kustomize to generate and manage Kubernetes manifests.

## Directory Structure

```
kustomize-component-template/
├── ci/
│   ├── pipelines/
│   │   ├── component-mgmt.yml      # Uses kustomize tasks
│   │   ├── release.yml
│   │   └── set-pipeline.yml
│   ├── scripts/
│   │   ├── fly.sh                  # Standard fly script
│   │   └── helpers.sh
│   ├── tasks/
│   │   ├── common/                 # Common tasks  
│   │   │   ├── make-git-commit/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── create-release-info/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── k8s/                    # Component-specific tasks
│   │   │   ├── create-namespace/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── validate-deployment/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── kustomize/              # Kustomize-specific tasks
│   │   │   ├── build-manifests/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── apply-manifests/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── tkgi/
│   │   │   └── tkgi-login/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   └── testing/
│   │       └── validate-resources/
│   │           ├── task.yml
│   │           └── task.sh
│   └── README.md
├── manifests/                      # Kustomize structure
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── overlays/
│       ├── lab/
│       ├── nonprod/
│       └── prod/
└── README.md
```

## Component Management Pipeline

The main pipeline for deploying and managing the component using Kustomize:

```yaml
groups:
  - name: management
    jobs:
      - prepare-manifests
      - deploy-component
      - validate-deployment

resources:
  - name: component-repo
    type: git
    source:
      uri: ((git_uri))
      branch: ((git_branch))
  
  - name: config-repo
    type: git
    source:
      uri: ((config_git_uri))
      branch: ((config_git_branch))

  - name: timer-trigger
    type: time
    source:
      interval: ((timer_duration))

jobs:
  - name: prepare-manifests
    plan:
      - in_parallel:
          - get: component-repo
            trigger: true
          - get: config-repo
            trigger: true
      - task: build-manifests
        file: component-repo/ci/tasks/kustomize/build-manifests/task.yml
        params:
          FOUNDATION: ((foundation))
          ENVIRONMENT: ((environment))
          KUSTOMIZE_PATH: manifests/overlays/((environment))
          OUTPUT_PATH: manifests

  - name: deploy-component
    plan:
      - in_parallel:
          - get: component-repo
            passed: [prepare-manifests]
          - get: config-repo
            passed: [prepare-manifests]
            trigger: true
      - task: tkgi-login
        file: component-repo/ci/tasks/tkgi/tkgi-login/task.yml
        params:
          PKS_API_URL: ((pks_api_url))
          PKS_USER: ((pks_api_admin))
          PKS_PASSWORD: ((pks_api_admin_pw))
      - task: create-namespace
        file: component-repo/ci/tasks/k8s/create-namespace/task.yml
        params:
          FOUNDATION: ((foundation))
          NAMESPACE: ((component_namespace))
      - task: apply-manifests
        file: component-repo/ci/tasks/kustomize/apply-manifests/task.yml
        params:
          FOUNDATION: ((foundation))
          MANIFESTS_PATH: manifests
          NAMESPACE: ((component_namespace))

  - name: validate-deployment
    plan:
      - in_parallel:
          - get: component-repo
            passed: [deploy-component]
          - get: config-repo
            passed: [deploy-component]
            trigger: true
      - task: tkgi-login
        file: component-repo/ci/tasks/tkgi/tkgi-login/task.yml
        params:
          PKS_API_URL: ((pks_api_url))
          PKS_USER: ((pks_api_admin))
          PKS_PASSWORD: ((pks_api_admin_pw))
      - task: validate-deployment
        file: component-repo/ci/tasks/k8s/validate-deployment/task.yml
        params:
          FOUNDATION: ((foundation))
          NAMESPACE: ((component_namespace))
          DEPLOYMENT_NAME: ((component_name))
```

## Example Tasks

### Kustomize Build Task (ci/tasks/kustomize/build-manifests/task.sh)

```bash
#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../../scripts/helpers.sh"

# Validate required parameters
if [[ -z $FOUNDATION ]]; then
  error "Foundation variable is required"
  exit 1
fi

if [[ -z $KUSTOMIZE_PATH ]]; then
  error "Kustomize path is required"
  exit 1
fi

if [[ -z $OUTPUT_PATH ]]; then
  OUTPUT_PATH="manifests"
fi

echo "Building Kustomize manifests for foundation $FOUNDATION"

# Build manifests using kustomize
mkdir -p component-repo/$OUTPUT_PATH
kustomize build component-repo/$KUSTOMIZE_PATH > component-repo/$OUTPUT_PATH/all-resources.yaml

echo "Kustomize build completed successfully"
```

### Apply Manifests Task (ci/tasks/kustomize/apply-manifests/task.sh)

```bash
#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../../scripts/helpers.sh"

# Set up TKGi credentials from previous step
mkdir -p "$HOME/.pks"
cp pks-config/creds.yml "$HOME/.pks/creds.yml"

# Validate required parameters
if [[ -z $FOUNDATION ]]; then
  error "Foundation variable is required"
  exit 1
fi

if [[ -z $MANIFESTS_PATH ]]; then
  error "Manifests path is required"
  exit 1
fi

if [[ -z $NAMESPACE ]]; then
  error "Namespace is required"
  exit 1
fi

echo "Applying Kubernetes manifests to namespace $NAMESPACE in foundation $FOUNDATION"

# Apply the manifests
kubectl apply -f component-repo/$MANIFESTS_PATH/all-resources.yaml -n $NAMESPACE

echo "Manifests applied successfully"
```

## Using This Template

To use this template for a new component:

1. Copy the template structure to your new repository
2. Update the component name and other specifics
3. Modify the Kustomize base and overlays for your component
4. Adjust the pipelines as needed for your specific requirements
5. Set up your params in the params repository

## Flying Pipelines

Use the standardized fly.sh script to set and manage pipelines:

```bash
# Set the main management pipeline
./ci/scripts/fly.sh -f cml-k8s-n-01

# Set the release pipeline
./ci/scripts/fly.sh -f cml-k8s-n-01 -r "Release notes"

# Set the set-pipeline pipeline
./ci/scripts/fly.sh -f cml-k8s-n-01 -s
```

## Params Repository Configuration

Ensure the params repository contains the necessary configuration:

```yaml
# Example params structure for a Kustomize component
git_uri: git@github.com:org-name/component-name.git
git_branch: develop
config_git_uri: git@github.com:org-name/config-repo.git
config_git_branch: master
foundation: cml-k8s-n-01
component_namespace: component-name
component_name: component-name
environment: lab
```

## Best Practices

- Keep Kustomize overlays simple and focused
- Use consistent naming for resources
- Document environment-specific configurations
- Use validation to ensure successful deployments
- Follow the standard directory structure