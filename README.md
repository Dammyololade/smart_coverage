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
- **Configurable**: Flexible configuration options via YAML files or command-line arguments
- **Modern CLI**: Built with best practices using Mason Logger and CLI completion

## 📦 Installation

### Global Installation (Recommended)

```sh
dart pub global activate smart_coverage
```

### Local Installation

```sh
dart pub global activate --source=path <path to this package>
```

### Verify Installation

```sh
smart_coverage --version
```

## 📖 Commands Overview

### `analyze` - Coverage Analysis

Analyze test coverage for your Flutter/Dart project with intelligent file detection and optional AI insights.

```sh
smart_coverage analyze [options]
```

### `update` - CLI Updates

Update the smart_coverage CLI to the latest version.

```sh
smart_coverage update
```

### Global Options

- `--version, -v`: Show the current version
- `--verbose`: Enable verbose logging with detailed output
- `--help`: Show usage help

## 🔍 Analyze Command - Detailed Usage

The `analyze` command is the core functionality of smart_coverage, providing intelligent coverage analysis with git integration and AI insights.

### Basic Usage

```sh
# Analyze modified files compared to main branch
smart_coverage analyze --base-branch main

# Analyze specific package with custom output
smart_coverage analyze --package-path ./my_project --output-dir ./reports

# Quick analysis with existing coverage data
smart_coverage analyze --skip-tests --lcov-file coverage/lcov.info
```

### Command Options

#### Required Options

- `--base-branch, -b <branch>`: **Base branch to compare against for detecting modified files**
  - Example: `--base-branch main`, `--base-branch origin/develop`
  - **Tip**: Use `origin/main` for remote branches to avoid "unknown revision" errors

#### Path and File Options

- `--package-path, -p <path>`: **Path to the Flutter/Dart package to analyze** (default: `.`)
  - Example: `--package-path ./packages/core`
  - **Tip**: Use absolute paths for packages outside current directory

- `--output-dir, -o <directory>`: **Output directory for generated reports** (default: `coverage_reports`)
  - Example: `--output-dir ./build/coverage`
  - **Tip**: Directory will be created automatically if it doesn't exist

- `--config, -c <file>`: **Path to configuration file**
  - Example: `--config smart_coverage.yaml`
  - **Tip**: Use config files for consistent team settings

- `--lcov-file, -l <file>`: **Path to LCOV coverage file** (default: `coverage/lcov.info`)
  - Example: `--lcov-file build/coverage/lcov.info`
  - **Tip**: Ensure the file exists or use `--skip-tests` to generate it first

#### Execution Control

- `--skip-tests`: **Skip running tests and use existing coverage data**
  - **Use case**: When you already have fresh coverage data
  - **Tip**: Speeds up analysis significantly for large projects

#### AI-Powered Features

- `--ai`: **Enable AI-powered insights generation**
  - **Features**: Generates intelligent analysis of coverage patterns
  - **Tip**: Requires AI service configuration (see Configuration section)

- `--code-review`: **Generate AI-powered code review**
  - **Features**: Creates detailed code review based on coverage data
  - **Tip**: Best used with `--ai` flag for comprehensive analysis

#### Output and Formatting

- `--output-formats <formats>`: **Output formats to generate** (default: `console`)
  - **Available formats**: `console`, `html`, `json`, `lcov`
  - **Examples**: 
    - `--output-formats console,html` - Console + HTML reports
    - `--output-formats json` - JSON only for CI integration
    - `--output-formats html,json,lcov` - Multiple formats
  - **Tip**: Use `html` for detailed visual reports, `json` for CI/CD integration

- `--dark-mode`: **Use dark theme for HTML reports** (default: `true`)
  - **Tip**: Use `--no-dark-mode` to disable dark theme

### 🎯 Usage Examples

#### Basic Coverage Analysis

```sh
# Analyze changes against main branch
smart_coverage analyze --base-branch origin/main

# Analyze with HTML report
smart_coverage analyze --base-branch main --output-formats html
```

#### Advanced Analysis with AI

```sh
# Full AI-powered analysis
smart_coverage analyze \
  --base-branch origin/main \
  --ai \
  --code-review \
  --output-formats console,html,json

# Quick AI insights on existing coverage
smart_coverage analyze \
  --skip-tests \
  --ai \
  --lcov-file coverage/lcov.info
```

#### CI/CD Integration

```sh
# Optimized for CI pipelines
smart_coverage analyze \
  --base-branch origin/main \
  --output-formats json \
  --output-dir ./coverage-reports \
  --no-dark-mode
```

#### Multi-package Projects

```sh
# Analyze specific package
smart_coverage analyze \
  --package-path ./packages/core \
  --base-branch main \
  --output-dir ./reports/core

# Using configuration file
smart_coverage analyze \
  --config ./tools/smart_coverage.yaml \
  --base-branch origin/develop
```

### 🛠️ Configuration File

Create a `smart_coverage.yaml` file for consistent settings:

```yaml
package_path: "."
base_branch: "origin/main"
output_dir: "coverage_reports"
skip_tests: false
ai_insights: true
code_review: true
dark_mode: true
output_formats:
  - "console"
  - "html"
  - "json"
ai_config:
  provider: "gemini"
  model: "gemini-pro"
```

### 💡 Pro Tips

1. **Git Branch Issues**: Use `origin/main` instead of `main` if you get "unknown revision" errors
2. **Performance**: Use `--skip-tests` when you have fresh coverage data to speed up analysis
3. **CI Integration**: Use `--output-formats json` for machine-readable output in CI/CD
4. **Large Projects**: Consider analyzing specific packages with `--package-path`
5. **AI Features**: Ensure proper AI service configuration before using `--ai` or `--code-review`
6. **Report Viewing**: HTML reports provide the most detailed and visual coverage analysis

## 🧪 Generating Coverage Data

Before using smart_coverage, ensure you have coverage data:

```sh
# Generate coverage data
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info

# Then analyze with smart_coverage
smart_coverage analyze --base-branch main
```

### Alternative: Let smart_coverage handle it

```sh
# smart_coverage will run tests and generate coverage automatically
smart_coverage analyze --base-branch main
```

## 🤖 AI Configuration

To use AI-powered features, configure your AI service:

### Environment Variables

```sh
# For Gemini AI (Google)
export GEMINI_API_KEY="your-api-key-here"

# For OpenAI
export OPENAI_API_KEY="your-api-key-here"
```

### Configuration File

```yaml
ai_config:
  provider: "gemini"  # or "openai", "claude"
  model: "gemini-pro"
  api_key_env: "GEMINI_API_KEY"
  provider_type: "api"  # or "local"
```

## 🚨 Troubleshooting

### Common Issues

#### "Unknown revision 'main'"

**Problem**: Git can't find the specified branch.

**Solution**: Use the full remote branch name:
```sh
# Instead of
smart_coverage analyze --base-branch main

# Use
smart_coverage analyze --base-branch origin/main
```

#### "No coverage data found"

**Problem**: LCOV file doesn't exist or is empty.

**Solutions**:
1. Generate coverage data first:
   ```sh
   dart test --coverage=coverage
   dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
   ```

2. Or let smart_coverage handle it (don't use `--skip-tests`):
   ```sh
   smart_coverage analyze --base-branch main
   ```

#### "No modified files detected"

**Problem**: No files have changed compared to the base branch.

**Solutions**:
1. Check if you're on the right branch:
   ```sh
   git branch
   git status
   ```

2. Verify the base branch exists:
   ```sh
   git branch -a
   ```

3. Make some changes and commit them, or analyze all files by omitting `--base-branch`

#### AI Features Not Working

**Problem**: AI insights or code review not generating.

**Solutions**:
1. Check API key configuration:
   ```sh
   echo $GEMINI_API_KEY  # Should not be empty
   ```

2. Verify internet connection for API-based services

3. Check configuration file syntax if using config files

### Debug Mode

Use verbose logging for detailed troubleshooting:

```sh
smart_coverage analyze --base-branch main --verbose
```

## 🔧 Development

### Running from Source

```sh
# Clone the repository
git clone https://github.com/your-username/smart_coverage.git
cd smart_coverage

# Install dependencies
dart pub get

# Run from source
dart run bin/smart_coverage.dart analyze --help
```

### Running Tests

```sh
# Run all tests
dart test

# Run tests with coverage
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info

# View coverage report
genhtml coverage/lcov.info -o coverage/
open coverage/index.html
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for your changes
5. Ensure tests pass (`dart test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

This project follows [Very Good Analysis](https://pub.dev/packages/very_good_analysis) guidelines:

```sh
# Check code style
dart analyze

# Format code
dart format .
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Very Good CLI](https://github.com/VeryGoodOpenSource/very_good_cli)
- Powered by [Mason Logger](https://pub.dev/packages/mason_logger) for beautiful CLI output
- Uses [LCOV](https://github.com/linux-test-project/lcov) format for coverage data

---

[coverage_badge]: coverage_badge.svg
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_cli_link]: https://github.com/VeryGoodOpenSource/very_good_cli