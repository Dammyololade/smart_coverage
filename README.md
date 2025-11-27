# Smart Coverage

![coverage][coverage_badge]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A modern Dart CLI tool for intelligent coverage analysis with AI-powered insights for Flutter/Dart projects.

## 🚀 Features

- **Intelligent Coverage Analysis**: Analyzes test coverage with focus on modified files using git integration
- **AI-Powered Insights**: Generate automated code reviews and coverage insights using AI services
- **Git Integration**: Automatically detects modified files by comparing against base branches
- **Multiple Output Formats**: Supports HTML, JSON, console, and LCOV report formats
- **Shell Completion**: Tab-completion support for commands and options
- **Configurable**: Flexible configuration via YAML files or command-line arguments

## 📦 Installation

```sh
# Install globally
dart pub global activate smart_coverage

# Verify installation
smart_coverage --version

# Enable shell tab-completion (recommended)
smart_coverage completion-setup
```

## 🚀 Quick Start

```sh
# 1. Generate configuration file
smart_coverage init

# 2. Run analysis
smart_coverage analyze
```

## 📖 Commands

| Command | Description |
|---------|-------------|
| `analyze` | Analyze test coverage with optional AI insights |
| `init` | Generate a configuration file |
| `setup` | Interactive setup wizard |
| `update` | Update the CLI to latest version |
| `completion-setup` | Set up shell tab-completion |

## 🔍 Analyze Command

```sh
# Basic usage
smart_coverage analyze --base-branch origin/main

# With HTML report
smart_coverage analyze --base-branch main --output-formats html

# Include dependent files (files that import modified files)
smart_coverage analyze --base-branch main --include-dependents

# With AI insights
smart_coverage analyze --base-branch main --test-insights --code-review

# Skip tests (use existing coverage)
smart_coverage analyze --skip-tests --lcov-file coverage/lcov.info

# Custom test command
smart_coverage analyze --test-command "flutter test --coverage"
smart_coverage analyze --test-command "very_good test --coverage --recursive"
```

### Key Options

| Option | Description |
|--------|-------------|
| `-b, --base-branch` | Base branch to compare against (e.g., `origin/main`) |
| `-p, --package-path` | Path to the package to analyze (default: `.`) |
| `-o, --output-dir` | Output directory for reports (default: `coverage/smart_coverage`) |
| `-t, --test-command` | Custom test command to run |
| `--skip-tests` | Skip running tests, use existing coverage data |
| `--include-dependents` | Include files that depend on modified files |
| `--test-insights` | Enable AI-powered test insights |
| `--code-review` | Generate AI-powered code review |
| `--output-formats` | Output formats: `console`, `html`, `json`, `lcov` |
| `--profile` | Enable performance profiling |

## 🛠️ Configuration

Create a `smart_coverage.yaml` file:

```yaml
package_path: "."
base_branch: "origin/main"
output_dir: "coverage/smart_coverage"
skip_tests: false
dark_mode: true
output_formats:
  - console
  - html

# Include files that depend on modified files
# include_dependents: true

# Custom test command
# test_command: "flutter test --coverage"

# AI features
# test_insights: true
# code_review: true
# ai_config:
#   provider: "gemini"
#   api_key_env: "GEMINI_API_KEY"
```

## 🤖 AI Configuration

To use AI-powered features (`--test-insights`, `--code-review`):

```sh
# Set your API key
export GEMINI_API_KEY="your-api-key-here"

# Run with AI features
smart_coverage analyze --base-branch main --test-insights --code-review
```

Or configure in `smart_coverage.yaml`:

```yaml
ai_config:
  provider: "gemini"
  api_key_env: "GEMINI_API_KEY"
```

## 🚨 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Unknown revision 'main'" | Use `origin/main` instead of `main` |
| "No coverage data found" | Run without `--skip-tests` or generate coverage first |
| AI features not working | Check `echo $GEMINI_API_KEY` is set |
| Tab completion not working | Run `smart_coverage completion-setup` |

For detailed debugging:

```sh
smart_coverage analyze --base-branch main --verbose
```

## 🔧 Development

```sh
# Clone and setup
git clone https://github.com/Dammyololade/smart_coverage.git
cd smart_coverage
dart pub get

# Run from source
dart run bin/smart_coverage.dart analyze --help

# Run tests
dart test
```

## 📄 License

MIT License - see the [LICENSE](LICENSE) file for details.

---

[coverage_badge]: coverage_badge.svg
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
