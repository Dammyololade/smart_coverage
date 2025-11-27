# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-27

### ✨ New Features

#### Dependent Files Analysis
- Added `--include-dependents` flag to include files that depend on modified files
- Builds a dependency graph by parsing imports/exports
- Shows coverage for modified files AND all files that import them
- Helps understand the full test coverage impact of a change
- Configurable via CLI, config file (`include_dependents:`), or environment variable

#### Custom Test Command Support
- Added `--test-command` / `-t` option to specify custom test commands
- Supports any test runner: `flutter test`, `dart test`, `very_good test`, `melos run test`, etc.
- Configurable via CLI, config file (`test_command:`), or environment variable (`SMART_COVERAGE_TEST_COMMAND`)
- Auto-detects Flutter vs Dart projects when no custom command is specified

#### Shell Tab-Completion Setup
- Added `completion-setup` command for easy shell completion configuration
- Automatically detects shell type (zsh, bash, fish)
- Handles `compinit` setup for vanilla zsh users
- Includes `--check` flag to verify completion status
- Works with the existing `cli_completion` package infrastructure

### 📝 Documentation
- Streamlined README with cleaner structure and tables
- Added shell completion setup instructions
- Removed redundant sections and examples

### 🔧 Improvements
- New `DependencyAnalyzer` service for parsing Dart imports and building dependency graphs
- Better error messages for test command failures
- Improved configuration service with `testCommand` and `includeDependents` support
- Environment variable support for new options

---

## [0.0.1] - 2025-10-16

### 🎉 Initial Release

First public release of Smart Coverage - a modern Dart CLI tool for intelligent coverage analysis with AI-powered insights.

### ✨ Features

#### Core Functionality
- **Intelligent Coverage Analysis**: Analyzes test coverage with focus on modified files using git integration
- **Git Integration**: Automatically detects modified files by comparing against base branches
- **Multiple Output Formats**: Supports HTML, JSON, console, and LCOV report formats
- **Configurable Workflow**: Flexible configuration via YAML files or command-line arguments

#### Commands
- **`init` Command**: Quick generation of `smart_coverage.yaml` configuration files with sensible defaults
  - `--minimal` flag for minimal configuration
  - `--with-ai` flag to include AI configuration
  - `--force` flag to overwrite existing configuration
- **`analyze` Command**: Core coverage analysis with intelligent file detection
  - Git-based modified file detection
  - Support for skipping tests with `--skip-tests`
  - Configurable output formats and directories
  - Performance profiling with `--profile` flag
- **`setup` Command**: Interactive setup wizard for advanced configuration
  - Project type detection (Flutter/Dart)
  - AI provider configuration
  - Advanced options (dark mode, skip tests, etc.)
  - Validation and retry logic
- **`update` Command**: CLI self-update functionality
