# Helm Component Template

This template is designed for components that use Helm charts for deployment and management.

## Directory Structure

```sh
helm-component-template/
├── ci/
│   ├── pipelines/
│   │   ├── main.yml      # Uses helm tasks
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
│   │   ├── helm/                   # Helm-specific tasks
│   │   │   ├── helm-deploy/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   ├── helm-test/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── helm-delete/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── tkgi/
│   │   │   └── tkgi-login/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   └── testing/
│   │       └── validate-helm-release/
│   │           ├── task.yml
│   │           └── task.sh
│   └── README.md
├── charts/                         # Helm charts
│   └── component-name/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── configmap.yaml
│       └── values/                 # Environment-specific values
│           ├── lab.yaml
│           ├── nonprod.yaml
│           └── prod.yaml
└── README.md
```

## Component Management Pipeline

The main pipeline for deploying and managing the component using Helm:

```yaml
groups:
  - name: management
    jobs:
      - prepare
      - deploy-component
      - test-component
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
  - name: prepare
    plan:
      - in_parallel:
          - get: component-repo
            trigger: true
          - get: config-repo
            trigger: true

  - name: deploy-component
    plan:
      - in_parallel:
          - get: component-repo
            passed: [prepare]
          - get: config-repo
            passed: [prepare]
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
      - task: helm-deploy
        file: component-repo/ci/tasks/helm/helm-deploy/task.yml
        params:
          FOUNDATION: ((foundation))
          NAMESPACE: ((component_namespace))
          RELEASE_NAME: ((release_name))
          CHART_PATH: component-repo/charts/((component_name))
          VALUES_FILE: component-repo/charts/((component_name))/values/((environment)).yaml
          TIMEOUT: 10m

  - name: test-component
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
      - task: helm-test
        file: component-repo/ci/tasks/helm/helm-test/task.yml
        params:
          FOUNDATION: ((foundation))
          NAMESPACE: ((component_namespace))
          RELEASE_NAME: ((release_name))

  - name: validate-deployment
    plan:
      - in_parallel:
          - get: component-repo
            passed: [test-component]
          - get: config-repo
            passed: [test-component]
            trigger: true
      - task: tkgi-login
        file: component-repo/ci/tasks/tkgi/tkgi-login/task.yml
        params:
          PKS_API_URL: ((pks_api_url))
          PKS_USER: ((pks_api_admin))
          PKS_PASSWORD: ((pks_api_admin_pw))
      - task: validate-helm-release
        file: component-repo/ci/tasks/testing/validate-helm-release/task.yml
        params:
          FOUNDATION: ((foundation))
          NAMESPACE: ((component_namespace))
          RELEASE_NAME: ((release_name))
```

## Example Tasks

### Helm Deploy Task (ci/tasks/helm/helm-deploy/task.sh)

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

if [[ -z $NAMESPACE ]]; then
  error "Namespace variable is required"
  exit 1
fi

if [[ -z $RELEASE_NAME ]]; then
  error "Release name is required"
  exit 1
fi

if [[ -z $CHART_PATH ]]; then
  error "Chart path is required"
  exit 1
fi

echo "Deploying Helm chart $CHART_PATH as $RELEASE_NAME to $NAMESPACE in foundation $FOUNDATION"

# Set up Helm command parameters
HELM_ARGS=""

# Add values file if specified
if [[ -n $VALUES_FILE && -f $VALUES_FILE ]]; then
  HELM_ARGS="$HELM_ARGS --values $VALUES_FILE"
fi

# Add timeout if specified
if [[ -n $TIMEOUT ]]; then
  HELM_ARGS="$HELM_ARGS --timeout $TIMEOUT"
fi

# Execute Helm upgrade/install
helm upgrade --install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  $HELM_ARGS \
  --atomic \
  --wait

echo "Helm deployment completed successfully"
```

### Helm Test Task (ci/tasks/helm/helm-test/task.sh)

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

if [[ -z $NAMESPACE ]]; then
  error "Namespace variable is required"
  exit 1
fi

if [[ -z $RELEASE_NAME ]]; then
  error "Release name is required"
  exit 1
fi

echo "Testing Helm release $RELEASE_NAME in namespace $NAMESPACE in foundation $FOUNDATION"

# Run helm test
helm test $RELEASE_NAME -n $NAMESPACE

echo "Helm tests completed successfully"
```

## Using This Template

To use this template for a new component:

1. Copy the template structure to your new repository
2. Update the component name and other specifics
3. Create or customize the Helm chart in the charts directory
4. Create environment-specific values files
5. Adjust the pipelines as needed for your specific requirements
6. Set up your params in the params repository

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
# Example params structure for a Helm component
git_uri: git@github.com:org-name/component-name.git
git_branch: develop
config_git_uri: git@github.com:org-name/config-repo.git
config_git_branch: master
foundation: cml-k8s-n-01
component_namespace: component-name
component_name: component-name
release_name: component-name
environment: lab
```

## Best Practices

- Keep Helm charts simple and focused
- Use environment-specific values files for configuration differences
- Include Helm tests in your chart
- Use atomic installations to ensure rollback on failure
- Document chart values clearly
- Follow Helm best practices for template organization
