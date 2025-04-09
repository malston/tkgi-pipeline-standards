#!/usr/bin/env bash

# Help and usage information for fly.sh

# Function to show usage information
function show_usage() {
  local exit_code=${1:-0}
  echo "Usage: ./fly.sh [options] [command] [pipeline_name]"
  echo "Commands:"
  echo "  set          Set pipeline (default)"
  echo "  unpause      Set and unpause pipeline"
  echo "Options:"
  echo "  -f, --foundation NAME      Foundation name (required)"
  exit "${exit_code}"
}

# Function to show general usage information
function show_general_usage() {
  local exit_code=${1:-0}
  show_usage "${exit_code}"
}

# Function to show command-specific usage information
function show_command_usage() {
  local command="$1"
  local exit_code=${2:-0}
  echo "Usage for $command"
  exit "${exit_code}"
}
