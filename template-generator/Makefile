# Makefile for template-generator

# Variables
VENV_DIR = ../.venv
PYTHON = python3
PIP = $(VENV_DIR)/bin/pip
PYTHON_VENV = $(VENV_DIR)/bin/python

# Default target
.PHONY: all
all: help

# Help
.PHONY: help
help:
	@echo "Template Generator Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make setup              Create virtual environment and install dependencies"
	@echo "  make generate           Generate a template using default settings"
	@echo "  make generate-kustomize Generate a kustomize template"
	@echo "  make generate-helm      Generate a helm template"
	@echo "  make generate-cli       Generate a CLI tool template"
	@echo "  make test               Run template filtering tests"
	@echo "  make validate           Run template compliance validation"
	@echo "  make clean              Remove generated output and cache files"
	@echo ""
	@echo "Examples:"
	@echo "  make generate OUTPUT_DIR=~/my-new-project ORG_NAME=MyOrg REPO_NAME=my-service"
	@echo "  make generate-helm OUTPUT_DIR=~/my-helm-chart"
	@echo "  make validate PROJECT_DIR=~/my-helm-chart"

# Setup virtual environment
.PHONY: setup
setup:
	@echo "Setting up virtual environment..."
	$(PYTHON) -m venv $(VENV_DIR)
	$(PIP) install pyyaml

# Generate template with default settings
.PHONY: generate
generate:
	@echo "Generating template..."
	$(PYTHON_VENV) generate-reference-template.py \
		--output-dir $(OUTPUT_DIR) \
		$(if $(ORG_NAME),--org-name "$(ORG_NAME)") \
		$(if $(REPO_NAME),--repo-name "$(REPO_NAME)") \
		$(if $(TEMPLATE_TYPE),--template-type "$(TEMPLATE_TYPE)") \
		$(if $(DEFAULT_BRANCH),--default-branch "$(DEFAULT_BRANCH)") \
		$(if $(DEFAULT_FOUNDATION),--default-foundation "$(DEFAULT_FOUNDATION)") \
		$(if $(CONFIG),--config "$(CONFIG)")

# Generate kustomize template
.PHONY: generate-kustomize
generate-kustomize:
	@echo "Generating kustomize template..."
	$(PYTHON_VENV) generate-reference-template.py \
		--output-dir $(OUTPUT_DIR) \
		--template-type kustomize \
		$(if $(ORG_NAME),--org-name "$(ORG_NAME)") \
		$(if $(REPO_NAME),--repo-name "$(REPO_NAME)") \
		$(if $(DEFAULT_BRANCH),--default-branch "$(DEFAULT_BRANCH)") \
		$(if $(DEFAULT_FOUNDATION),--default-foundation "$(DEFAULT_FOUNDATION)") \
		$(if $(CONFIG),--config "$(CONFIG)")

# Generate helm template
.PHONY: generate-helm
generate-helm:
	@echo "Generating helm template..."
	$(PYTHON_VENV) generate-reference-template.py \
		--output-dir $(OUTPUT_DIR) \
		--template-type helm \
		$(if $(ORG_NAME),--org-name "$(ORG_NAME)") \
		$(if $(REPO_NAME),--repo-name "$(REPO_NAME)") \
		$(if $(DEFAULT_BRANCH),--default-branch "$(DEFAULT_BRANCH)") \
		$(if $(DEFAULT_FOUNDATION),--default-foundation "$(DEFAULT_FOUNDATION)") \
		$(if $(CONFIG),--config "$(CONFIG)")

# Generate CLI tool template
.PHONY: generate-cli
generate-cli:
	@echo "Generating CLI tool template..."
	$(PYTHON_VENV) generate-reference-template.py \
		--output-dir $(OUTPUT_DIR) \
		--template-type cli-tool \
		$(if $(ORG_NAME),--org-name "$(ORG_NAME)") \
		$(if $(REPO_NAME),--repo-name "$(REPO_NAME)") \
		$(if $(DEFAULT_BRANCH),--default-branch "$(DEFAULT_BRANCH)") \
		$(if $(DEFAULT_FOUNDATION),--default-foundation "$(DEFAULT_FOUNDATION)") \
		$(if $(CONFIG),--config "$(CONFIG)")

# Run template filtering tests
.PHONY: test
test:
	@echo "Running template filtering tests..."
	$(PYTHON_VENV) test-task-filtering.py $(if $(VERBOSE),--verbose)

# Run template compliance validation
.PHONY: validate
validate:
	@echo "Running template compliance validation..."
	$(PYTHON_VENV) validate-template-compliance.py \
		--project-dir $(PROJECT_DIR) \
		$(if $(TEMPLATE_TYPE),--template-type "$(TEMPLATE_TYPE)") \
		$(if $(VERBOSE),--verbose)

# Clean output directories and cache files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -rf __pycache__
	rm -rf *.pyc
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
