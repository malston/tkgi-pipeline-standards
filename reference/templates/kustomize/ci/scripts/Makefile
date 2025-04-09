.PHONY: build test clean

# Variables
SRC_DIR := .
LIB_DIR := $(SRC_DIR)/lib
SCRIPT := $(SRC_DIR)/fly.sh
TEST_DIR := $(SRC_DIR)/tests

# Default target
all: build test

# Build the script
build:
	@echo "Building script..."
	@chmod +x $(SCRIPT)
	@chmod +x $(LIB_DIR)/*.sh

# Test the script
test:
	@echo "Testing script..."
	@cd $(TEST_DIR) && ./test_help_commands.sh
	# @cd $(TEST_DIR) && ./test_commands.sh
	# @cd $(TEST_DIR) && ./test_fly.sh
	# @cd $(TEST_DIR) && ./tests/validate_fly.sh

# Clean up
clean:
	@echo "Cleaning up..."
	@rm -f $(SRC_DIR)/*.bak

# Help target
help:
	@echo "Makefile for fly.sh script"
	@echo ""
	@echo "Targets:"
	@echo "  all          Build and test the script"
	@echo "  build        Build the script"
	@echo "  test         Run tests"
	@echo "  clean        Clean up temporary files"
	@echo "  help         Show this help message"