import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// {@template init_command}
/// `smart_coverage init` command for quickly generating a configuration file
/// {@endtemplate}
class InitCommand extends Command<int> {
  /// {@macro init_command}
  InitCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing configuration file if it exists.',
        negatable: false,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output path for the configuration file.',
        defaultsTo: 'smart_coverage.yaml',
      )
      ..addOption(
        'base-branch',
        abbr: 'b',
        help: 'Default base branch for git comparisons.',
        defaultsTo: 'origin/main',
      )
      ..addFlag(
        'with-ai',
        help: 'Include AI configuration in the generated file.',
        defaultsTo: false,
      )
      ..addFlag(
        'minimal',
        abbr: 'm',
        help: 'Generate minimal configuration with only essential options.',
        negatable: false,
      );
  }

  @override
  String get description =>
      'Generate a smart_coverage.yaml configuration file for your project.';

  @override
  String get name => 'init';

  final Logger _logger;

  @override
  Future<int> run() async {
    final outputPath = argResults!['output'] as String;
    final baseBranch = argResults!['base-branch'] as String;
    final withAi = argResults!['with-ai'] as bool;
    final minimal = argResults!['minimal'] as bool;

    // Check if config file already exists and inform user
    final configFile = File(outputPath);
    final fileExists = await configFile.exists();

    if (fileExists) {
      _logger.info('📝 Overwriting existing configuration file at: $outputPath');
      _logger.info('');
    }

    // Generate configuration content
    final configContent = minimal
        ? _generateMinimalConfig(baseBranch)
        : _generateFullConfig(baseBranch, withAi);

    // Write to file
    try {
      await configFile.writeAsString(configContent);

      _logger.info('✅ Configuration file ${fileExists ? "updated" : "created"} successfully!');
      _logger.info('');
      _logger.info('📄 Location: ${lightCyan.wrap(outputPath)}');
      _logger.info('');

      if (minimal) {
        _logger.info('Generated a minimal configuration with essential options.');
      } else {
        _logger.info('Generated a full configuration with all available options.');
      }

      _logger.info('');
      _logger.info('📝 Next steps:');
      _logger.info('  1. Review and customize the configuration file');
      if (!withAi) {
        _logger.info('  2. Add AI configuration if needed (see comments in file)');
      }
      _logger.info('  ${withAi ? "2" : "3"}. Run: ${lightGreen.wrap("smart_coverage analyze")}');
      _logger.info('');
      _logger.info('💡 Tip: The configuration file supports environment variables.');
      _logger.info('   Example: base_branch: \${GIT_BASE_BRANCH:-origin/main}');

      return ExitCode.success.code;
    } catch (e) {
      _logger.err('❌ Failed to create configuration file: $e');
      return ExitCode.software.code;
    }
  }

  String _generateMinimalConfig(String baseBranch) {
    return '''# Smart Coverage Configuration
# Minimal configuration with essential options

# Base branch to compare against for detecting modified files
base_branch: "$baseBranch"

# Output directory for generated reports
output_dir: "coverage/smart_coverage"

# Output formats (console, html, json, lcov)
output_formats:
  - console
  - html

# Use dark theme for HTML reports
dark_mode: true

# Skip running tests (use existing coverage data)
skip_tests: false
''';
  }

  String _generateFullConfig(String baseBranch, bool withAi) {
    final aiSection = withAi ? '''
# AI Configuration (optional)
# Enables AI-powered code review and test insights
ai_config:
  # AI provider: "gemini", "openai", "claude"
  provider: "gemini"
  
  # Provider type: "api", "local", or "auto"
  provider_type: "auto"
  
  # Model to use (optional, uses provider default if not specified)
  # model: "gemini-pro"
  
  # Environment variable name for API key
  api_key_env: "GEMINI_API_KEY"
  
  # API endpoint (optional, uses provider default)
  # api_endpoint: "https://api.example.com/v1"
  
  # Request timeout in seconds
  timeout: 30
  
  # Local CLI configuration (for CLI-based providers)
  cli_command: "gemini"
  cli_args: []
  cli_timeout: 60
  
  # Fallback configuration
  fallback_enabled: true
  fallback_order:
    - local
    - api
  
  # Caching configuration
  cache_enabled: true
  cache_directory: ".cache"
  cache_expiration_hours: 24
  
  # Verbose AI service output
  verbose: false
''' : '''
# AI Configuration (optional)
# Uncomment and configure to enable AI-powered features
# ai_config:
#   provider: "gemini"
#   provider_type: "auto"
#   api_key_env: "GEMINI_API_KEY"
#   timeout: 30
#   fallback_enabled: true
#   cache_enabled: true
'''
    ;

    return '''# Smart Coverage Configuration
# Generated by: smart_coverage init
# Learn more: https://github.com/your-repo/smart_coverage

# ===========================
# Project Configuration
# ===========================

# Path to the Flutter/Dart package to analyze
package_path: "."

# Base branch to compare against for detecting modified files
# Examples: "main", "origin/main", "develop"
# Tip: Use "origin/main" to avoid "unknown revision" errors
base_branch: "$baseBranch"

# ===========================
# Output Configuration
# ===========================

# Output directory for generated reports
output_dir: "coverage/smart_coverage"

# Output formats to generate
# Available: console, html, json, lcov
output_formats:
  - console
  - html
  - json

# Use dark theme for HTML reports
dark_mode: true

# ===========================
# Execution Configuration
# ===========================

# Skip running tests and use existing coverage data
# Set to true if you've already generated coverage
skip_tests: false

# Path to LCOV coverage file (relative to package_path)
# lcov_file: "coverage/lcov.info"

# ===========================
# Feature Flags
# ===========================

# Enable AI-powered test insights generation
# Requires AI configuration (see below)
test_insights: false

# Generate AI-powered code review
# Requires AI configuration (see below)
code_review: false

# Enable performance profiling and optimization
# Useful for large codebases to identify bottlenecks
profile: false

# ===========================
# AI Configuration
# ===========================
$aiSection
# ===========================
# Environment Variable Support
# ===========================
# You can use environment variables in this config:
# base_branch: "\${GIT_BASE_BRANCH:-origin/main}"
# ai_config:
#   api_key_env: "\${AI_API_KEY_VAR:-GEMINI_API_KEY}"
''';
  }
}
