import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';

/// {@template config_validation_error}
/// Represents a configuration validation error with helpful suggestions
/// {@endtemplate}
class ConfigValidationError {
  /// {@macro config_validation_error}
  const ConfigValidationError({
    required this.field,
    required this.message,
    required this.severity,
    this.suggestion,
    this.example,
    this.documentation,
  });

  /// The configuration field that has the error
  final String field;

  /// The error message
  final String message;

  /// The severity of the error
  final ConfigValidationSeverity severity;

  /// Helpful suggestion to fix the error
  final String? suggestion;

  /// Example of correct configuration
  final String? example;

  /// Link to documentation
  final String? documentation;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('${severity.emoji} ${severity.name.toUpperCase()}: $message');

    if (suggestion != null) {
      buffer.write('\n  💡 Suggestion: $suggestion');
    }

    if (example != null) {
      buffer.write('\n  📝 Example: $example');
    }

    if (documentation != null) {
      buffer.write('\n  📚 Documentation: $documentation');
    }

    return buffer.toString();
  }
}

/// {@template config_validation_severity}
/// Severity levels for configuration validation
/// {@endtemplate}
enum ConfigValidationSeverity {
  /// Critical error that prevents execution
  error('❌', 'error'),

  /// Warning that might cause issues
  warning('⚠️', 'warning'),

  /// Information or suggestion for improvement
  info('ℹ️', 'info');

  const ConfigValidationSeverity(this.emoji, this.name);

  /// Emoji representation
  final String emoji;

  /// String name
  final String name;
}

/// {@template config_validation_result}
/// Result of configuration validation
/// {@endtemplate}
class ConfigValidationResult {
  /// {@macro config_validation_result}
  const ConfigValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.suggestions,
  });

  /// Whether the configuration is valid
  final bool isValid;

  /// Critical errors that prevent execution
  final List<ConfigValidationError> errors;

  /// Warnings that might cause issues
  final List<ConfigValidationError> warnings;

  /// Suggestions for improvement
  final List<ConfigValidationError> suggestions;

  /// All validation issues combined
  List<ConfigValidationError> get allIssues => [
    ...errors,
    ...warnings,
    ...suggestions,
  ];

  /// Whether there are any issues
  bool get hasIssues => allIssues.isNotEmpty;
}

/// {@template config_validator}
/// Enhanced configuration validator with helpful error messages and suggestions
/// {@endtemplate}
abstract class ConfigValidator {
  /// Validate configuration with detailed feedback
  Future<ConfigValidationResult> validateConfig(SmartCoverageConfig config);

  /// Validate and display results with colored output
  Future<bool> validateAndDisplay(SmartCoverageConfig config, Logger logger);

  /// Generate configuration template with examples
  String generateConfigTemplate();

  /// Suggest fixes for common configuration issues
  List<String> suggestFixes(ConfigValidationResult result);
}

/// {@template config_validator_impl}
/// Implementation of enhanced configuration validator
/// {@endtemplate}
class ConfigValidatorImpl implements ConfigValidator {
  /// {@macro config_validator_impl}
  const ConfigValidatorImpl();

  @override
  Future<ConfigValidationResult> validateConfig(
    SmartCoverageConfig config,
  ) async {
    final errors = <ConfigValidationError>[];
    final warnings = <ConfigValidationError>[];
    final suggestions = <ConfigValidationError>[];

    // Validate package path
    await _validatePackagePath(
      config.packagePath,
      errors,
      warnings,
      suggestions,
    );

    // Validate base branch
    await _validateBaseBranch(config.baseBranch, errors, warnings, suggestions);

    // Validate output directory
    await _validateOutputDirectory(
      config.outputDir,
      errors,
      warnings,
      suggestions,
    );

    // Validate output formats
    _validateOutputFormats(config.outputFormats, errors, warnings, suggestions);

    // Validate AI configuration
    if (config.testInsights || config.codeReview) {
      await _validateAiConfig(config.aiConfig, errors, warnings, suggestions);
    }

    // Validate configuration consistency
    _validateConfigConsistency(config, errors, warnings, suggestions);

    return ConfigValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  @override
  Future<bool> validateAndDisplay(
    SmartCoverageConfig config,
    Logger logger,
  ) async {
    final result = await validateConfig(config);

    if (!result.hasIssues) {
      logger.success('✅ Configuration is valid!');
      return true;
    }

    logger.err('\n🔍 Configuration Validation Results:\n');

    // Display errors
    if (result.errors.isNotEmpty) {
      logger.err('❌ ERRORS (${result.errors.length}):');
      for (final error in result.errors) {
        logger.err('  ${error.toString()}\n');
      }
    }

    // Display warnings
    if (result.warnings.isNotEmpty) {
      logger.warn('⚠️  WARNINGS (${result.warnings.length}):');
      for (final warning in result.warnings) {
        logger.warn('  ${warning.toString()}\n');
      }
    }

    // Display suggestions
    if (result.suggestions.isNotEmpty) {
      logger.info('💡 SUGGESTIONS (${result.suggestions.length}):');
      for (final suggestion in result.suggestions) {
        logger.info('  ${suggestion.toString()}\n');
      }
    }

    // Display quick fixes
    final fixes = suggestFixes(result);
    if (fixes.isNotEmpty) {
      logger.info('🔧 QUICK FIXES:');
      for (final fix in fixes) {
        logger.info('  • $fix');
      }
    }

    return result.isValid;
  }

  @override
  String generateConfigTemplate() {
    return '''
# Smart Coverage Configuration
# This file configures how Smart Coverage analyzes your project

# Package settings
packagePath: .                    # Path to your Dart/Flutter project
baseBranch: main                  # Git branch to compare against for modified files

# Output settings
outputDir: coverage_reports       # Directory for generated reports
outputFormats:                    # Report formats to generate
  - console                       # Console output (always recommended)
  - html                          # Interactive HTML report
  - json                          # JSON data for CI/CD integration
  # - lcov                        # LCOV format for external tools

# Test settings
skipTests: false                  # Skip running tests (use existing coverage)

# AI-powered features
testInsights: false               # Generate AI insights for test improvements
codeReview: false                 # Generate AI code review suggestions

# UI settings
darkMode: false                   # Use dark theme for HTML reports

# AI Configuration (required if testInsights or codeReview is enabled)
aiConfig:
  provider: gemini                # AI provider: gemini, openai, claude, local
  providerType: auto              # Provider type: api, local, auto
  # apiKeyEnv: GEMINI_API_KEY     # Environment variable for API key
  # model: gemini-pro             # Specific model to use
  timeout: 30                     # API timeout in seconds
  cliCommand: gemini              # CLI command for local providers
  cliTimeout: 60                  # CLI timeout in seconds
  fallbackEnabled: true           # Enable fallback to other providers
  fallbackOrder:                  # Fallback order
    - local
    - api
''';
  }

  @override
  List<String> suggestFixes(ConfigValidationResult result) {
    final fixes = <String>[];

    // Suggest creating missing directories
    if (result.errors.any(
      (e) => e.field == 'packagePath' && e.message.contains('does not exist'),
    )) {
      fixes.add(
        'Create the package directory or update packagePath to point to an existing directory',
      );
    }

    // Suggest creating pubspec.yaml
    if (result.errors.any(
      (e) => e.field == 'packagePath' && e.message.contains('pubspec.yaml'),
    )) {
      fixes.add(
        'Run "dart create ." or "flutter create ." to initialize a new project',
      );
    }

    // Suggest AI configuration
    if (result.errors.any((e) => e.field.startsWith('aiConfig'))) {
      fixes.add(
        'Run "smart_coverage setup" to configure AI providers interactively',
      );
    }

    // Suggest configuration file creation
    if (result.suggestions.any(
      (s) => s.message.contains('configuration file'),
    )) {
      fixes.add(
        'Run "smart_coverage setup" to create a configuration file with recommended settings',
      );
    }

    return fixes;
  }

  Future<void> _validatePackagePath(
    String packagePath,
    List<ConfigValidationError> errors,
    List<ConfigValidationError> warnings,
    List<ConfigValidationError> suggestions,
  ) async {
    if (packagePath.isEmpty) {
      errors.add(
        ConfigValidationError(
          field: 'packagePath',
          message: 'Package path cannot be empty',
          severity: ConfigValidationSeverity.error,
          suggestion:
              'Set packagePath to "." for current directory or specify the path to your Dart/Flutter project',
          example: 'packagePath: .',
        ),
      );
      return;
    }

    final packageDir = Directory(packagePath);
    if (!await packageDir.exists()) {
      errors.add(
        ConfigValidationError(
          field: 'packagePath',
          message: 'Package directory does not exist: $packagePath',
          severity: ConfigValidationSeverity.error,
          suggestion:
              'Create the directory or update packagePath to point to an existing Dart/Flutter project',
          example: 'packagePath: ./my_project',
        ),
      );
      return;
    }

    // Check for pubspec.yaml
    final pubspecFile = File('$packagePath/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      errors.add(
        ConfigValidationError(
          field: 'packagePath',
          message: 'No pubspec.yaml found in package directory: $packagePath',
          severity: ConfigValidationSeverity.error,
          suggestion: 'Initialize a Dart/Flutter project in this directory',
          example: 'dart create . or flutter create .',
        ),
      );
      return;
    }

    // Check for lib directory
    final libDir = Directory('$packagePath/lib');
    if (!await libDir.exists()) {
      warnings.add(
        ConfigValidationError(
          field: 'packagePath',
          message: 'No lib directory found in package: $packagePath',
          severity: ConfigValidationSeverity.warning,
          suggestion: 'Create a lib directory and add your Dart source files',
          example: 'mkdir lib && echo "void main() {}" > lib/main.dart',
        ),
      );
    }

    // Check for test directory
    final testDir = Directory('$packagePath/test');
    if (!await testDir.exists()) {
      suggestions.add(
        ConfigValidationError(
          field: 'packagePath',
          message: 'No test directory found in package: $packagePath',
          severity: ConfigValidationSeverity.info,
          suggestion:
              'Create a test directory to enable test coverage analysis',
          example:
              'mkdir test && echo "import \'package:test/test.dart\';\nvoid main() { test(\'example\', () {}); }" > test/example_test.dart',
        ),
      );
    }
  }

  Future<void> _validateBaseBranch(
    String baseBranch,
    List<ConfigValidationError> errors,
    List<ConfigValidationError> warnings,
    List<ConfigValidationError> suggestions,
  ) async {
    if (baseBranch.isEmpty) {
      warnings.add(
        ConfigValidationError(
          field: 'baseBranch',
          message: 'Base branch is empty',
          severity: ConfigValidationSeverity.warning,
          suggestion:
              'Set baseBranch to compare against a specific Git branch for modified file detection',
          example: 'baseBranch: main',
        ),
      );
      return;
    }

    // Check if we're in a Git repository
    final gitDir = Directory('.git');
    if (!await gitDir.exists()) {
      suggestions.add(
        ConfigValidationError(
          field: 'baseBranch',
          message: 'Not in a Git repository, baseBranch will be ignored',
          severity: ConfigValidationSeverity.info,
          suggestion:
              'Initialize Git repository to enable modified file detection',
          example: 'git init && git add . && git commit -m "Initial commit"',
        ),
      );
      return;
    }

    // Check if branch exists (basic check)
    try {
      final result = await Process.run('git', [
        'rev-parse',
        '--verify',
        baseBranch,
      ]);
      if (result.exitCode != 0) {
        warnings.add(
          ConfigValidationError(
            field: 'baseBranch',
            message:
                'Base branch "$baseBranch" does not exist in Git repository',
            severity: ConfigValidationSeverity.warning,
            suggestion: 'Use an existing branch name or create the branch',
            example: 'git checkout -b $baseBranch',
          ),
        );
      }
    } catch (e) {
      // Git command failed, but this is not critical
      suggestions.add(
        ConfigValidationError(
          field: 'baseBranch',
          message: 'Could not verify base branch existence',
          severity: ConfigValidationSeverity.info,
          suggestion:
              'Ensure Git is installed and the repository is properly initialized',
        ),
      );
    }
  }

  Future<void> _validateOutputDirectory(
    String outputDir,
    List<ConfigValidationError> errors,
    List<ConfigValidationError> warnings,
    List<ConfigValidationError> suggestions,
  ) async {
    if (outputDir.isEmpty) {
      errors.add(
        ConfigValidationError(
          field: 'outputDir',
          message: 'Output directory cannot be empty',
          severity: ConfigValidationSeverity.error,
          suggestion: 'Set outputDir to a valid directory path',
          example: 'outputDir: coverage_reports',
        ),
      );
      return;
    }

    final outputDirectory = Directory(outputDir);
    final parentDir = outputDirectory.parent;

    if (!await parentDir.exists()) {
      errors.add(
        ConfigValidationError(
          field: 'outputDir',
          message: 'Output directory parent does not exist: ${parentDir.path}',
          severity: ConfigValidationSeverity.error,
          suggestion:
              'Create the parent directory or choose a different output directory',
          example: 'mkdir -p ${parentDir.path}',
        ),
      );
      return;
    }

    // Check if output directory exists and is writable
    if (await outputDirectory.exists()) {
      try {
        final testFile = File('${outputDirectory.path}/.write_test');
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        errors.add(
          ConfigValidationError(
            field: 'outputDir',
            message: 'Output directory is not writable: $outputDir',
            severity: ConfigValidationSeverity.error,
            suggestion:
                'Check directory permissions or choose a different output directory',
            example: 'chmod 755 $outputDir',
          ),
        );
      }
    }
  }

  void _validateOutputFormats(
    List<String> outputFormats,
    List<ConfigValidationError> errors,
    List<ConfigValidationError> warnings,
    List<ConfigValidationError> suggestions,
  ) {
    const validFormats = ['console', 'html', 'json', 'lcov'];

    if (outputFormats.isEmpty) {
      warnings.add(
        ConfigValidationError(
          field: 'outputFormats',
          message: 'No output formats specified',
          severity: ConfigValidationSeverity.warning,
          suggestion: 'Add at least one output format',
          example: 'outputFormats: [console, html]',
        ),
      );
      return;
    }

    for (final format in outputFormats) {
      if (!validFormats.contains(format)) {
        errors.add(
          ConfigValidationError(
            field: 'outputFormats',
            message: 'Invalid output format: $format',
            severity: ConfigValidationSeverity.error,
            suggestion:
                'Use one of the valid formats: ${validFormats.join(', ')}',
            example: 'outputFormats: [console, html, json]',
          ),
        );
      }
    }

    // Suggest including console format
    if (!outputFormats.contains('console')) {
      suggestions.add(
        ConfigValidationError(
          field: 'outputFormats',
          message: 'Console output format not included',
          severity: ConfigValidationSeverity.info,
          suggestion: 'Include console format for immediate feedback',
          example: 'outputFormats: [console, html]',
        ),
      );
    }

    // Suggest HTML for interactive reports
    if (!outputFormats.contains('html') && outputFormats.length == 1) {
      suggestions.add(
        ConfigValidationError(
          field: 'outputFormats',
          message: 'Only console output specified',
          severity: ConfigValidationSeverity.info,
          suggestion: 'Add HTML format for interactive coverage reports',
          example: 'outputFormats: [console, html]',
        ),
      );
    }
  }

  Future<void> _validateAiConfig(
    AiConfig aiConfig,
    List<ConfigValidationError> errors,
    List<ConfigValidationError> warnings,
    List<ConfigValidationError> suggestions,
  ) async {
    // Validate provider
    const validProviders = ['gemini', 'openai', 'claude', 'local'];
    if (!validProviders.contains(aiConfig.provider)) {
      errors.add(
        ConfigValidationError(
          field: 'aiConfig.provider',
          message: 'Invalid AI provider: ${aiConfig.provider}',
          severity: ConfigValidationSeverity.error,
          suggestion:
              'Use one of the supported providers: ${validProviders.join(', ')}',
          example: 'provider: gemini',
        ),
      );
    }

    // Validate provider type
    const validProviderTypes = ['api', 'local', 'auto'];
    if (!validProviderTypes.contains(aiConfig.providerType)) {
      errors.add(
        ConfigValidationError(
          field: 'aiConfig.providerType',
          message: 'Invalid AI provider type: ${aiConfig.providerType}',
          severity: ConfigValidationSeverity.error,
          suggestion:
              'Use one of the valid types: ${validProviderTypes.join(', ')}',
          example: 'providerType: auto',
        ),
      );
    }

    // Validate API key for API providers
    if (aiConfig.providerType == 'api' || aiConfig.providerType == 'auto') {
      if (aiConfig.apiKeyEnv == null || aiConfig.apiKeyEnv!.isEmpty) {
        warnings.add(
          ConfigValidationError(
            field: 'aiConfig.apiKeyEnv',
            message:
                'No API key environment variable specified for API provider',
            severity: ConfigValidationSeverity.warning,
            suggestion:
                'Set apiKeyEnv to the environment variable containing your API key',
            example: 'apiKeyEnv: GEMINI_API_KEY',
          ),
        );
      } else {
        // Check if environment variable exists
        final apiKey = Platform.environment[aiConfig.apiKeyEnv!];
        if (apiKey == null || apiKey.isEmpty) {
          warnings.add(
            ConfigValidationError(
              field: 'aiConfig.apiKeyEnv',
              message:
                  'Environment variable ${aiConfig.apiKeyEnv} is not set or empty',
              severity: ConfigValidationSeverity.warning,
              suggestion: 'Set the environment variable with your API key',
              example: 'export ${aiConfig.apiKeyEnv}=your_api_key_here',
            ),
          );
        }
      }
    }

    // Validate timeout values
    if (aiConfig.timeout <= 0) {
      errors.add(
        ConfigValidationError(
          field: 'aiConfig.timeout',
          message: 'AI timeout must be positive: ${aiConfig.timeout}',
          severity: ConfigValidationSeverity.error,
          suggestion: 'Set timeout to a positive number of seconds',
          example: 'timeout: 30',
        ),
      );
    } else if (aiConfig.timeout < 10) {
      warnings.add(
        ConfigValidationError(
          field: 'aiConfig.timeout',
          message: 'AI timeout is very low: ${aiConfig.timeout}s',
          severity: ConfigValidationSeverity.warning,
          suggestion: 'Consider increasing timeout for better reliability',
          example: 'timeout: 30',
        ),
      );
    }

    if (aiConfig.cliTimeout <= 0) {
      errors.add(
        ConfigValidationError(
          field: 'aiConfig.cliTimeout',
          message: 'AI CLI timeout must be positive: ${aiConfig.cliTimeout}',
          severity: ConfigValidationSeverity.error,
          suggestion: 'Set cliTimeout to a positive number of seconds',
          example: 'cliTimeout: 60',
        ),
      );
    }

    // Validate CLI command for local providers
    if (aiConfig.providerType == 'local' || aiConfig.providerType == 'auto') {
      if (aiConfig.cliCommand.isEmpty) {
        warnings.add(
          ConfigValidationError(
            field: 'aiConfig.cliCommand',
            message: 'No CLI command specified for local provider',
            severity: ConfigValidationSeverity.warning,
            suggestion:
                'Set cliCommand to the command for your local AI provider',
            example: 'cliCommand: gemini',
          ),
        );
      } else {
        // Check if CLI command exists
        try {
          final result = await Process.run('which', [aiConfig.cliCommand]);
          if (result.exitCode != 0) {
            warnings.add(
              ConfigValidationError(
                field: 'aiConfig.cliCommand',
                message:
                    'CLI command "${aiConfig.cliCommand}" not found in PATH',
                severity: ConfigValidationSeverity.warning,
                suggestion: 'Install the CLI tool or update the command path',
                example: 'Install with: npm install -g @google/generative-ai',
              ),
            );
          }
        } catch (e) {
          // Command check failed, but this is not critical
        }
      }
    }

    // Validate fallback order
    const validFallbackTypes = ['api', 'local'];
    for (final fallback in aiConfig.fallbackOrder) {
      if (!validFallbackTypes.contains(fallback)) {
        errors.add(
          ConfigValidationError(
            field: 'aiConfig.fallbackOrder',
            message: 'Invalid fallback type: $fallback',
            severity: ConfigValidationSeverity.error,
            suggestion:
                'Use valid fallback types: ${validFallbackTypes.join(', ')}',
            example: 'fallbackOrder: [local, api]',
          ),
        );
      }
    }
  }

  void _validateConfigConsistency(
    SmartCoverageConfig config,
    List<ConfigValidationError> errors,
    List<ConfigValidationError> warnings,
    List<ConfigValidationError> suggestions,
  ) {
    // Check if AI features are enabled but no AI config
    if ((config.testInsights || config.codeReview) &&
        config.aiConfig.provider.isEmpty) {
      errors.add(
        ConfigValidationError(
          field: 'aiConfig',
          message: 'AI features enabled but no AI provider configured',
          severity: ConfigValidationSeverity.error,
          suggestion: 'Configure AI provider or disable AI features',
          example: 'testInsights: false\ncodeReview: false',
        ),
      );
    }

    // Suggest enabling AI features if configured
    if (!config.testInsights &&
        !config.codeReview &&
        config.aiConfig.provider.isNotEmpty) {
      suggestions.add(
        ConfigValidationError(
          field: 'testInsights',
          message: 'AI provider configured but AI features disabled',
          severity: ConfigValidationSeverity.info,
          suggestion: 'Enable AI features to get intelligent insights',
          example: 'testInsights: true\ncodeReview: true',
        ),
      );
    }

    // Suggest creating configuration file if using defaults
    if (config.packagePath == '.' &&
        config.baseBranch == 'main' &&
        config.outputDir == 'coverage_reports' &&
        !config.testInsights &&
        !config.codeReview) {
      suggestions.add(
        ConfigValidationError(
          field: 'configuration',
          message: 'Using default configuration',
          severity: ConfigValidationSeverity.info,
          suggestion: 'Create a smart_coverage.yaml file to customize settings',
          example: 'Run: smart_coverage setup',
        ),
      );
    }
  }
}
