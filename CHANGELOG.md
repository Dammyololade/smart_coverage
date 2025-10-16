# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2024-10-16

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
