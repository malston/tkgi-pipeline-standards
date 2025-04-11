# TKGI Pipeline Standards - Key Points for Migration

This document highlights the most important aspects of the TKGI Pipeline Standards repository to help guide your team through the migration process.

## 1. Standardized Structure and Modularity

- Clear separation of concerns with organized directory structure (`ci/pipelines`, `ci/tasks`, `ci/scripts`)
- Task organization by category (common, k8s, tkgi, testing) rather than by pipeline
- Modular script architecture with reusable components in `lib/` directory
- Each task has its own directory with both `task.yml` and `task.sh` files

## 2. Consistent CLI Interface

- Standardized `fly.sh` script with consistent command patterns across repositories
- Support for operations like set, unpause, destroy, validate, and release
- Command-specific help with detailed documentation for each command
- Parameterized functions that reduce code duplication and increase maintainability

## 3. Environment and Foundation Handling

- Smart handling of different environments (lab, nonprod, prod) based on foundation name
- Automatic datacenter detection and environment configuration
- Version normalization for consistent version handling
- Foundation-based target selection and parameter loading

## 4. Documentation and Testing

- Comprehensive README files in all directories explaining purpose and usage
- Example templates showing proper implementation
- Built-in test framework for validating script functionality
- Self-documenting code with descriptive function names and comments

## 5. Migration Support

- Step-by-step migration guide (`reference/migration-guide.md`) for converting existing repositories
- Implementation checklist (`reference/checklist.md`) to ensure complete adoption
- Reference templates for different component types (Kustomize, Helm, CLI tools)
- Backwards compatibility considerations during transition

## 6. Code Quality Standards

- Strict error handling with `set -o errexit` and `pipefail`
- Consistent logging patterns with info/error/success functions
- Path handling that works regardless of working directory
- Parameter validation to catch errors early

## 7. Repository Integration

- Works with config repositories to separate configuration from implementation
- Integrates with params repository for foundation-specific parameters
- Support for custom GitHub organizations per environment
- Consistent parameter handling across all foundation types

## 8. Continuous Improvement

- Ongoing refactoring to improve code quality and maintainability
- Support for adding new features via modular architecture
- Gradual migration approach to minimize disruption

## Migration Priorities

When planning your migration, focus on these aspects in order:

1. **Basic Structure**: Start with creating the proper directory structure and organizing tasks
2. **Task Migration**: Move existing tasks to standard locations and align them with conventions
3. **Pipeline Updates**: Update pipeline files to reference the new task locations
4. **CLI Interface**: Implement the standardized `fly.sh` script for pipeline management
5. **Advanced Features**: Add modular script libraries and enhanced functionality

## Resources

- **README.md**: The main documentation with full standards explanation
- **reference/migration-guide.md**: Step-by-step migration instructions
- **reference/checklist.md**: Complete implementation checklist
- **reference/templates/**: Reference implementations for different project types

Refer to the ns-mgmt repository for a complete working example of these standards in practice.
