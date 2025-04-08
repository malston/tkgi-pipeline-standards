# CLI Tool Component Template

This template is designed for components that use specialized CLI tools (like `istioctl` or `tridentctl`) for deployment and management.

## Directory Structure

```
cli-tool-component-template/
├── ci/
│   ├── pipelines/
│   │   ├── component-mgmt.yml      # Uses CLI tool tasks
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
│   │   ├── k8s/
│   │   │   ├── create-namespace/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── validate-deployment/
│   │   │       ├── task.yml
│   │   │       └── task.sh
│   │   ├── cli-tool/               # Generalized CLI tool tasks
│   │   │   ├── download-tool/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   ├── deploy-component/
│   │   │   │   ├── task.yml
│   │   │   │   └── task.sh
│   │   │   └── validate-component/
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
├── config/                         # Component-specific configurations
│   ├── istio/                      # Example for Istio
│   │   ├── profiles/
│   │   │   ├── lab.yaml
│   │   │   ├── nonprod.yaml
│   │   │   └── prod.yaml
│   │   └── operators/
│   └── trident/                    # Example for Trident
│       ├── backend-config/
│       └── installation-params/
└── README.md
```

## Component Management Pipeline

The main pipeline for deploying and managing the component using a specialized CLI tool:

```yaml
groups:
  - name: management
    jobs:
      - prepare
      - deploy-component
      - validate-component

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
      - task: download-tool
        file: component-repo/ci/tasks/cli-tool/download-tool/task.yml
        params:
          TOOL_NAME: ((tool_name))
          TOOL_VERSION: ((tool_version))
          DOWNLOAD_URL: ((tool_download_url))
      - task: deploy-component
        file: component-repo/ci/tasks/cli-tool/deploy-component/task.yml
        params:
          FOUNDATION: ((foundation))
          TOOL_NAME: ((tool_name))
          CONFIG_PATH: config-repo/foundations/((foundation))/((tool_name))-config
          TOOL_OPTIONS: ((tool_options))

  - name: validate-component
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
      - task: download-tool
        file: component-repo/ci/tasks/cli-tool/download-tool/task.yml
        params:
          TOOL_NAME: ((tool_name))
          TOOL_VERSION: ((tool_version))
          DOWNLOAD_URL: ((tool_download_url))
      - task: validate-component
        file: component-repo/ci/tasks/cli-tool/validate-component/task.yml
        params:
          FOUNDATION: ((foundation))
          TOOL_NAME: ((tool_name))
```

## Example Tasks

### Download Tool Task (ci/tasks/cli-tool/download-tool/task.sh)

```bash
#!/usr/bin/env bash
set -o errexit
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source helper functions
source "${__DIR}/../../../../scripts/helpers.sh"

# Validate required parameters
if [[ -z $TOOL_NAME ]]; then
  error "Tool name is required"
  exit 1
fi

if [[ -z $TOOL_VERSION ]]; then
  error "Tool version is required"
  exit 1
fi

echo "Downloading $TOOL_NAME version $TOOL_VERSION"

# Create output directory
mkdir -p cli-tool-bin

# Download and install the CLI tool based on its name
case $TOOL_NAME in
  "istioctl")
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$TOOL_VERSION sh -
    mkdir -p cli-tool-bin
    cp "istio-$TOOL_VERSION/bin/istioctl" cli-tool-bin/
    chmod +x cli-tool-bin/istioctl
    ;;
    
  "tridentctl")
    curl -L -o trident-installer-$TOOL_VERSION.tar.gz \
      https://github.com/NetApp/trident/releases/download/v$TOOL_VERSION/trident-installer-$TOOL_VERSION.tar.gz
    tar -xf trident-installer-$TOOL_VERSION.tar.gz
    cp trident-installer/tridentctl cli-tool-bin/
    chmod +x cli-tool-bin/tridentctl
    ;;
    
  *)
    # For other tools, try using the provided download URL
    if [[ -z $DOWNLOAD_URL ]]; then
      error "Download URL is required for tool: $TOOL_NAME"
      exit 1
    fi
    
    curl -L -o cli-tool-bin/$TOOL_NAME $DOWNLOAD_URL
    chmod +x cli-tool-bin/$TOOL_NAME
    ;;
esac

# Verify the tool was installed correctly
export PATH=$PWD/cli-tool-bin:$PATH
$TOOL_NAME version || $TOOL_NAME --version || echo "Version command not supported for $TOOL_NAME"

echo "$TOOL_NAME downloaded successfully to cli-tool-bin/"
```

### Deploy Component Task (ci/tasks/cli-tool/deploy-component/task.sh)

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

if [[ -z $TOOL_NAME ]]; then
  error "Tool name is required"
  exit 1
fi

if [[ -z $CONFIG_PATH ]]; then
  error "Config path is required"
  exit 1
fi

echo "Deploying using $TOOL_NAME to foundation $FOUNDATION"

# Add the downloaded tool to the PATH
export PATH=$PWD/cli-tool-bin:$PATH

# Execute the appropriate command based on tool name
case $TOOL_NAME in
  "istioctl")
    CONFIG_ARGS=""
    if [[ -d $CONFIG_PATH ]]; then
      CONFIG_ARGS="-f $CONFIG_PATH/overlay.yaml"
    fi
    
    # Using the profile from the environment if provided
    PROFILE=${TOOL_OPTIONS:-default}
    
    istioctl install --set profile=$PROFILE $CONFIG_ARGS -y
    ;;
    
  "tridentctl")
    # Create trident namespace if it doesn't exist
    kubectl create namespace trident --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Trident using tridentctl
    ./tridentctl install \
      -n trident \
      --use-custom-yaml=${CONFIG_PATH} \
      --generate-custom-yaml=true \
      ${TOOL_OPTIONS}
    ;;
    
  *)
    # For other tools, execute the provided command with options
    if [[ -z $TOOL_OPTIONS ]]; then
      error "Tool options are required for custom tool: $TOOL_NAME"
      exit 1
    fi
    
    # Execute the tool with the provided options
    $TOOL_NAME $TOOL_OPTIONS
    ;;
esac

echo "$TOOL_NAME deployment completed successfully"
```

### Validate Component Task (ci/tasks/cli-tool/validate-component/task.sh)

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

if [[ -z $TOOL_NAME ]]; then
  error "Tool name is required"
  exit 1
fi

echo "Validating $TOOL_NAME deployment in foundation $FOUNDATION"

# Add the downloaded tool to the PATH
export PATH=$PWD/cli-tool-bin:$PATH

# Execute the appropriate validation based on tool name
case $TOOL_NAME in
  "istioctl")
    # Validate the Istio installation
    istioctl verify-install
    
    # Check if Istio pods are running
    kubectl get pods -n istio-system
    ;;
    
  "tridentctl")
    # Validate the Trident installation
    tridentctl version -n trident
    
    # Check Trident status
    tridentctl status -n trident
    ;;
    
  *)
    # For other tools, try a generic verification approach
    echo "Performing generic validation for $TOOL_NAME"
    
    # Try to run version or status command
    $TOOL_NAME version || $TOOL_NAME status || $TOOL_NAME --version || echo "No standard validation for $TOOL_NAME"
    
    # Check if related resources exist in Kubernetes
    kubectl get pods -n ${NAMESPACE:-default} | grep ${TOOL_NAME}
    ;;
esac

echo "$TOOL_NAME validation completed successfully"
```

## Using This Template

To use this template for a new component:

1. Copy the template structure to your new repository
2. Update the component name and other specifics
3. Choose the appropriate CLI tool (istioctl, tridentctl, etc.)
4. Create configuration files specific to your component and tool
5. Adjust the pipelines as needed for your specific requirements
6. Set up your params in the params repository

## Customizing for Specific CLI Tools

### Istio Example

For Istio components:

1. Set `TOOL_NAME` to "istioctl"
2. Create appropriate Istio profiles in the config directory
3. Add any Istio-specific validation in the validation task

### Trident Example

For Trident components:

1. Set `TOOL_NAME` to "tridentctl"
2. Create appropriate Trident configuration in the config directory
3. Ensure storage classes and backends are defined

### Other CLI Tools

For other CLI tools:

1. Define `TOOL_NAME` and `DOWNLOAD_URL` for your specific tool
2. Create appropriate configuration in the config directory
3. Customize the deployment and validation commands as needed

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
# Example params structure for a CLI tool component
git_uri: git@github.com:org-name/component-name.git
git_branch: develop
config_git_uri: git@github.com:org-name/config-repo.git
config_git_branch: master
foundation: cml-k8s-n-01
tool_name: istioctl  # or tridentctl or other
tool_version: 1.14.1
tool_download_url: https://example.com/download/tool  # For custom tools
tool_options: "profile=default"  # Tool-specific options
```

## Best Practices

- Document the CLI tool version and compatibility requirements
- Keep configuration files organized by environment
- Include comprehensive validation steps
- Handle tool-specific error conditions
- Follow the standard directory structure
- Create reusable task patterns for similar CLI tools