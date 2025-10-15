import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:smart_coverage/src/services/config_validator.dart';

/// {@template setup_command}
/// `smart_coverage setup` command for interactive configuration setup
/// {@endtemplate}
class SetupCommand extends Command<int> {
  /// {@macro setup_command}
  SetupCommand({
    required Logger logger,
    ConfigService? configService,
    ConfigValidator? validator,
  }) : _logger = logger,
       _configService = configService ?? const ConfigServiceImpl(),
       _validator = validator ?? const ConfigValidatorImpl() {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing configuration file.',
        negatable: false,
      )
      ..addFlag(
        'template-only',
        help: 'Generate template without interactive setup',
        negatable: false,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output path for configuration file.',
        defaultsTo: 'smart_coverage.yaml',
      )
      ..addFlag(
        'ai-setup',
        help: 'Include AI configuration setup',
        defaultsTo: true,
      );
  }

  @override
  String get description =>
      'Interactive setup wizard for smart_coverage configuration.';

  @override
  String get name => 'setup';

  final Logger _logger;
  final ConfigService _configService;
  final ConfigValidator _validator;

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final templateOnly = argResults!['template-only'] as bool;
    final outputPath = argResults!['output'] as String;
    final includeAi = argResults!['ai-setup'] as bool;

    _logger.info('🚀 Smart Coverage Setup');
    _logger.info(
      'This will help you configure Smart Coverage for your project.\n',
    );

    // Check if config file already exists
    final configFile = File(outputPath);
    if (await configFile.exists() && !force) {
      final overwrite = _logger.confirm(
        '⚠️  Configuration file already exists at $outputPath. Overwrite?',
      );
      if (!overwrite) {
        _logger.info('Setup cancelled.');
        return ExitCode.success.code;
      }
    }

    if (templateOnly) {
      return await _generateTemplate(outputPath);
    }

    try {
      // Detect project type
      final projectInfo = await _detectProjectInfo();
      _logger.info('📁 Detected project: ${projectInfo['type']}\n');

      // Interactive configuration
      final config = await _interactiveSetup(projectInfo, includeAi);

      // Validate configuration with enhanced validator
      final isValid = await _validator.validateAndDisplay(config, _logger);
      if (!isValid) {
        _logger.err('❌ Configuration validation failed.');
        final retry = _logger.confirm('Would you like to retry setup?');
        if (retry) {
          return await run(); // Restart setup
        }
        return ExitCode.config.code;
      }

      // Save configuration
      await _configService.saveConfig(config, outputPath);

      _logger.success('✅ Configuration saved to $outputPath');
      _logger.info('\n🎉 Setup complete! Next steps:');
      _logger.info('  • Run: smart_coverage analyze');
      _logger.info('  • View help: smart_coverage analyze --help');
      _logger.info(
        '  • Enable verbose output: smart_coverage analyze --verbose',
      );

      return ExitCode.success.code;
    } catch (error) {
      _logger.err('❌ Setup failed: $error');
      return ExitCode.software.code;
    }
  }

  /// Detect project information
  Future<Map<String, dynamic>> _detectProjectInfo() async {
    final currentDir = Directory.current;
    final pubspecFile = File(path.join(currentDir.path, 'pubspec.yaml'));

    if (pubspecFile.existsSync()) {
      final content = await pubspecFile.readAsString();
      final isFlutter = content.contains('flutter:');

      return {
        'type': isFlutter ? 'Flutter' : 'Dart',
        'hasTests': Directory(path.join(currentDir.path, 'test')).existsSync(),
        'hasCoverage': File(
          path.join(currentDir.path, 'coverage', 'lcov.info'),
        ).existsSync(),
      };
    }

    return {
      'type': 'Unknown',
      'hasTests': false,
      'hasCoverage': false,
    };
  }

  /// Interactive setup process
  Future<SmartCoverageConfig> _interactiveSetup(
    Map<String, dynamic> projectInfo,
    bool includeAi,
  ) async {
    _logger.info('📝 Let\'s configure smart_coverage for your project:');
    _logger.info('');

    // Package path
    final packagePath = _logger.prompt(
      '📦 Package path (current directory):',
      defaultValue: '.',
    );

    // Base branch
    final defaultBranch = await _detectDefaultBranch();
    final baseBranch = _logger.prompt(
      '🌿 Base branch for comparison:',
      defaultValue: defaultBranch,
    );

    // Output directory
    final outputDir = _logger.prompt(
      '📁 Output directory for reports:',
      defaultValue: 'coverage/smart_coverage',
    );

    // Output formats
    final outputFormats = _selectOutputFormats();

    // AI configuration
    final aiConfig = includeAi ? await _configureAi() : null;

    // Advanced options
    final advancedOptions = _configureAdvancedOptions();

    return SmartCoverageConfig(
      packagePath: packagePath,
      baseBranch: baseBranch,
      outputDir: outputDir,
      skipTests: advancedOptions['skipTests'] as bool,
      testInsights: aiConfig != null,
      codeReview: aiConfig != null,
      darkMode: advancedOptions['darkMode'] as bool,
      outputFormats: outputFormats,
      aiConfig: aiConfig ?? const AiConfig(provider: 'gemini'),
    );
  }

  /// Detect default branch
  Future<String> _detectDefaultBranch() async {
    try {
      final result = await Process.run('git', [
        'symbolic-ref',
        'refs/remotes/origin/HEAD',
      ]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        return output.split('/').last;
      }
    } catch (_) {}

    // Fallback to common branch names
    for (final branch in ['main', 'master', 'develop']) {
      try {
        final result = await Process.run('git', [
          'rev-parse',
          '--verify',
          'origin/$branch',
        ]);
        if (result.exitCode == 0) {
          return 'origin/$branch';
        }
      } catch (_) {}
    }

    return 'main';
  }

  /// Select output formats
  List<String> _selectOutputFormats() {
    _logger.info('');
    _logger.info('📊 Select output formats (space-separated):');
    _logger.info('   1. console - Terminal output');
    _logger.info('   2. html - Interactive HTML reports');
    _logger.info('   3. json - Machine-readable JSON');
    _logger.info('   4. lcov - LCOV format for CI/CD');

    final input = _logger.prompt(
      'Output formats:',
      defaultValue: 'console html',
    );

    return input.split(' ').where((s) => s.isNotEmpty).toList();
  }

  /// Configure AI settings
  Future<AiConfig?> _configureAi() async {
    _logger.info('');
    final enableAi = _logger.confirm(
      '🤖 Enable AI-powered insights and code review?',
    );

    if (!enableAi) return null;

    _logger.info('');
    _logger.info('🔧 AI Configuration:');

    final provider = _logger.chooseOne(
      'Select AI provider:',
      choices: ['gemini', 'openai', 'claude'],
      defaultValue: 'gemini',
    );

    final providerType = _logger.chooseOne(
      'Provider type:',
      choices: ['auto', 'api', 'local'],
      defaultValue: 'auto',
    );

    String? apiKeyEnv;
    if (providerType == 'api' || providerType == 'auto') {
      final defaultEnvVar = '${provider.toUpperCase()}_API_KEY';
      apiKeyEnv = _logger.prompt(
        'Environment variable for API key:',
        defaultValue: defaultEnvVar,
      );

      // Check if API key is set
      if (Platform.environment[apiKeyEnv] == null) {
        _logger.warn('⚠️  Environment variable $apiKeyEnv is not set.');
        _logger.info('   Set it with: export $apiKeyEnv="your-api-key"');
      }
    }

    return AiConfig(
      provider: provider,
      providerType: providerType,
      apiKeyEnv: apiKeyEnv,
      cliCommand: provider,
      timeout: 30,
      cliTimeout: 60,
      fallbackEnabled: true,
      fallbackOrder: ['local', 'api'],
    );
  }

  /// Generate configuration template
  Future<int> _generateTemplate(String outputPath) async {
    try {
      final template = _validator.generateConfigTemplate();
      await File(outputPath).writeAsString(template);

      _logger.success('✅ Configuration template generated at $outputPath');
      _logger.info('\n📝 Next steps:');
      _logger.info('  1. Edit $outputPath to customize your settings');
      _logger.info(
        '  2. Run "smart_coverage analyze" to test your configuration',
      );
      _logger.info(
        '  3. Run "smart_coverage setup" for interactive configuration',
      );

      return ExitCode.success.code;
    } catch (e) {
      _logger.err('❌ Failed to generate template: $e');
      return ExitCode.ioError.code;
    }
  }

  /// Configure advanced options
  Map<String, dynamic> _configureAdvancedOptions() {
    _logger.info('');
    final configureAdvanced = _logger.confirm(
      '⚙️  Configure advanced options?',
      defaultValue: false,
    );

    if (!configureAdvanced) {
      return {
        'skipTests': false,
        'darkMode': true,
      };
    }

    final skipTests = _logger.confirm(
      'Skip running tests (use existing coverage)?',
      defaultValue: false,
    );

    final darkMode = _logger.confirm(
      'Use dark mode for HTML reports?',
      defaultValue: true,
    );

    return {
      'skipTests': skipTests,
      'darkMode': darkMode,
    };
  }
}
