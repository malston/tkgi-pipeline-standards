# Makefile for fly-script-tools

# Variables
VENV_DIR = ../../.venv
PYTHON = python3
PIP = $(VENV_DIR)/bin/pip
PYTHON_VENV = $(VENV_DIR)/bin/python
TOOLS_DIR = $(shell pwd)

# Default target
.PHONY: all
all: help

# Help
.PHONY: help
help:
	@echo "Fly Script Tools Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make setup                Setup virtual environment and install dependencies"
	@echo "  make generate             Generate a fly.sh script using default settings"
	@echo "  make generate-kustomize   Generate a kustomize fly.sh script"
	@echo "  make generate-helm        Generate a helm fly.sh script"
	@echo "  make generate-cli         Generate a CLI tool fly.sh script"
	@echo "  make validate             Validate a fly.sh script"
	@echo "  make migrate              Migrate an existing fly.sh script"
	@echo "  make test                 Run all tests for the tools"
	@echo "  make clean                Remove cache files and temporary outputs"
	@echo ""
	@echo "Parameters:"
	@echo "  OUTPUT_DIR             Output directory for generated files"
	@echo "  INPUT_FILE             Input fly.sh file for migration"
	@echo "  SCRIPT_DIR             Directory containing fly.sh script for validation"
	@echo "  PIPELINE_NAME          Name of the pipeline (default: tkgi-app)"
	@echo "  ALTERNATIVE_TESTS      Set to use alternative test framework (default: false)"
	@echo "  VERBOSE                Enable verbose output"
	@echo ""
	@echo "Examples:"
	@echo "  make generate OUTPUT_DIR=~/project/ci/scripts PIPELINE_NAME=my-pipeline"
	@echo "  make validate SCRIPT_DIR=~/project/ci/scripts VERBOSE=true"
	@echo "  make migrate INPUT_FILE=~/project/ci/scripts/fly.sh OUTPUT_DIR=~/project/ci/scripts-new"
	@echo "  make generate-helm OUTPUT_DIR=~/project/ci/scripts PIPELINE_NAME=my-helm-chart ALTERNATIVE_TESTS=true"

# Setup virtual environment
.PHONY: setup
setup:
	@echo "Setting up virtual environment..."
	$(PYTHON) -m venv $(VENV_DIR)
	$(PIP) install pyyaml jinja2

# Generate fly.sh script with default settings
.PHONY: generate
generate:
	@if [ -z "$(OUTPUT_DIR)" ]; then \
		echo "Error: OUTPUT_DIR is not set. Please set it to the output directory."; \
		exit 1; \
	fi
	@echo "Generating fly.sh script..."
	$(PYTHON_VENV) $(TOOLS_DIR)/generate_fly_script.py \
		--output-dir "$(OUTPUT_DIR)" \
		$(if $(PIPELINE_NAME),--pipeline-name "$(PIPELINE_NAME)") \
		$(if $(TEMPLATE_TYPE),--template "$(TEMPLATE_TYPE)") \
		$(if $(CONFIG),--config "$(CONFIG)") \
		$(if $(ALTERNATIVE_TESTS),--alternative-tests)

# Generate kustomize fly.sh script
.PHONY: generate-kustomize
generate-kustomize:
	@if [ -z "$(OUTPUT_DIR)" ]; then \
		echo "Error: OUTPUT_DIR is not set. Please set it to the output directory."; \
		exit 1; \
	fi
	@echo "Generating kustomize fly.sh script..."
	$(PYTHON_VENV) $(TOOLS_DIR)/generate_fly_script.py \
		--output-dir "$(OUTPUT_DIR)" \
		--template kustomize \
		$(if $(PIPELINE_NAME),--pipeline-name "$(PIPELINE_NAME)") \
		$(if $(CONFIG),--config "$(CONFIG)") \
		$(if $(ALTERNATIVE_TESTS),--alternative-tests)

# Generate helm fly.sh script
.PHONY: generate-helm
generate-helm:
	@if [ -z "$(OUTPUT_DIR)" ]; then \
		echo "Error: OUTPUT_DIR is not set. Please set it to the output directory."; \
		exit 1; \
	fi
	@echo "Generating helm fly.sh script..."
	$(PYTHON_VENV) $(TOOLS_DIR)/generate_fly_script.py \
		--output-dir "$(OUTPUT_DIR)" \
		--template helm \
		$(if $(PIPELINE_NAME),--pipeline-name "$(PIPELINE_NAME)") \
		$(if $(CONFIG),--config "$(CONFIG)") \
		$(if $(ALTERNATIVE_TESTS),--alternative-tests)

# Generate CLI tool fly.sh script
.PHONY: generate-cli
generate-cli:
	@if [ -z "$(OUTPUT_DIR)" ]; then \
		echo "Error: OUTPUT_DIR is not set. Please set it to the output directory."; \
		exit 1; \
	fi
	@echo "Generating CLI tool fly.sh script..."
	$(PYTHON_VENV) $(TOOLS_DIR)/generate_fly_script.py \
		--output-dir "$(OUTPUT_DIR)" \
		--template cli-tool \
		$(if $(PIPELINE_NAME),--pipeline-name "$(PIPELINE_NAME)") \
		$(if $(CONFIG),--config "$(CONFIG)") \
		$(if $(ALTERNATIVE_TESTS),--alternative-tests)

# Validate a fly.sh script
.PHONY: validate
validate:
	@if [ -z "$(SCRIPT_DIR)" ]; then \
		echo "Error: SCRIPT_DIR is not set. Please set it to the directory containing fly.sh."; \
		exit 1; \
	fi
	@echo "Validating fly.sh script..."
	$(PYTHON_VENV) $(TOOLS_DIR)/validate_fly_script.py \
		--directory "$(SCRIPT_DIR)" \
		$(if $(OUTPUT_FILE),--output "$(OUTPUT_FILE)") \
		$(if $(VERBOSE),--verbose)

# Migrate an existing fly.sh script
.PHONY: migrate
migrate:
	@if [ -z "$(INPUT_FILE)" ]; then \
		echo "Error: INPUT_FILE is not set. Please set it to the existing fly.sh script."; \
		exit 1; \
	fi
	@if [ -z "$(OUTPUT_DIR)" ]; then \
		echo "Error: OUTPUT_DIR is not set. Please set it to the output directory."; \
		exit 1; \
	fi
	@echo "Migrating fly.sh script..."
	$(PYTHON_VENV) $(TOOLS_DIR)/migrate_fly_script.py \
		--input "$(INPUT_FILE)" \
		--output-dir "$(OUTPUT_DIR)" \
		$(if $(BACKUP),--backup) \
		$(if $(ALTERNATIVE_TESTS),--alternative-tests) \
		$(if $(VERBOSE),--verbose)

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	$(PYTHON_VENV) -m unittest discover -s $(TOOLS_DIR)/tests

# Clean cache files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -rf $(TOOLS_DIR)/__pycache__
	rm -rf $(TOOLS_DIR)/*.pyc
	find $(TOOLS_DIR) -name "*.pyc" -delete
	find $(TOOLS_DIR) -name "__pycache__" -delete