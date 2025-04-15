# Pipeline CI Scripts

This directory contains scripts for CI/CD pipeline management for deployments.

## Main Scripts

- `fly.sh`: Main script for managing Concourse pipelines

## Usage

```bash
./fly.sh [options] [command] [pipeline_name]
```

### Commands

- `set`: Set pipeline (default)
- `unpause`: Set and unpause pipeline
- `destroy`: Destroy specified pipeline
- `validate`: Validate pipeline YAML without setting
- `release`: Create a release pipeline

### Options

- `-h, --help`: Show help message
- `-f, --foundation FOUNDATION`: Foundation to target (required)
- `-t, --target TARGET`: Concourse target (defaults to foundation name)
- `-p, --pipeline PIPELINE`: Pipeline name (default: main)
- `-b, --branch BRANCH`: Git branch to use (default: develop)
- `-r, --release`: Set release pipeline
- `-e, --environment ENV`: Environment (lab, nonprod, prod)
- `--version VERSION`: Version to use for release
- `--verbose`: Enable verbose output
- `-d, --params-branch BRANCH`: Params repo branch (default: master)
- `-P, --params-repo PATH`: Path to params repo
- `--dry-run`: Print commands without executing

## Examples

Set a pipeline for a foundation:
```bash
./fly.sh -f cml-k8s-n-01 -t my-target
```

Deploy a release pipeline:
```bash
./fly.sh -f cml-k8s-n-01 -r
```

Validate a pipeline without setting it:
```bash
./fly.sh validate main
```

Use custom params repository branch:
```bash
./fly.sh -f cml-k8s-n-01 -d feature-branch
```