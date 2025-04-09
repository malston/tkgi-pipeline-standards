# Reference Scripts

This directory contains reference implementations of scripts that were used during the development of the standardized CI structure. These scripts are kept for historical context and should not be used directly.

## Contents

- `fly.sh.original`: The initial version of the advanced fly.sh script
- `ns-mgmt-fly.sh`: Original implementation from the ns-mgmt repository (pre-migration)
- `ns-mgmt-helpers.sh`: Helper functions from the ns-mgmt repository (pre-migration)
- `ns-mgmt-refactored.sh`: Intermediate refactored version that led to the current fly.sh

## Purpose

These scripts are provided for:

1. **Historical Context**: Understanding the evolution of the pipeline management scripts
2. **Reference Implementation**: Seeing alternative approaches to script organization
3. **Migration Examples**: Demonstrating how scripts were migrated and enhanced

## Usage

These scripts should not be used directly. Instead, use the current implementations:

- For simple pipeline management: `ci/fly.sh`
- For advanced pipeline management: `ci/scripts/fly.sh`