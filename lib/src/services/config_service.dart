import 'dart:io';

import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:yaml/yaml.dart';

/// {@template config_service}
/// Service for loading and validating configuration from multiple sources
/// {@endtemplate}
abstract class ConfigService {
  /// Load configuration from multiple sources with priority:
  /// 1. CLI arguments (highest priority)
  /// 2. Environment variables
  /// 3. YAML configuration file
  /// 4. Default values (lowest priority)
  Future<SmartCoverageConfig> loadConfig({
    Map<String, dynamic>? cliArgs,
    String? configFilePath,
  });

  /// Validate configuration values
  Future<List<String>> validateConfig(SmartCoverageConfig config);

  /// Save configuration to YAML file
  Future<void> saveConfig(SmartCoverageConfig config, String filePath);

  /// Load configuration from YAML file
  Future<Map<String, dynamic>?> loadYamlConfig(String filePath);

  /// Load configuration from environment variables
  Map<String, dynamic> loadEnvConfig();
}

/// {@template config_service_impl}
/// Implementation of configuration service
/// {@endtemplate}
class ConfigServiceImpl implements ConfigService {
  /// {@macro config_service_impl}
  const ConfigServiceImpl();

  /// Default configuration file name
  static const String defaultConfigFile = 'smart_coverage.yaml';

  /// Environment variable prefix
  static const String envPrefix = 'SMART_COVERAGE_';

  @override
  Future<SmartCoverageConfig> loadConfig({
    Map<String, dynamic>? cliArgs,
    String? configFilePath,
  }) async {
    // Start with default configuration
    var config = _getDefaultConfig();

    // Load from YAML file (if exists)
    final yamlConfig = await loadYamlConfig(
      configFilePath ?? defaultConfigFile,
    );
    if (yamlConfig != null) {
      config = _mergeConfigs(config, yamlConfig);
    }

    // Load from environment variables
    final envConfig = loadEnvConfig();
    config = _mergeConfigs(config, envConfig);

    // Apply CLI arguments (highest priority)
    if (cliArgs != null) {
      config = _mergeConfigs(config, cliArgs);
    }

    // Convert to SmartCoverageConfig object
    return _mapToConfig(config);
  }

  @override
  Future<List<String>> validateConfig(SmartCoverageConfig config) async {
    final errors = <String>[];

    // Validate package path
    if (config.packagePath.isEmpty) {
      errors.add('Package path cannot be empty');
    } else {
      final packageDir = Directory(config.packagePath);
      if (!await packageDir.exists()) {
        errors.add('Package path does not exist: ${config.packagePath}');
      } else {
        // Check for pubspec.yaml
        final pubspecFile = File('${config.packagePath}/pubspec.yaml');
        if (!await pubspecFile.exists()) {
          errors.add(
            'No pubspec.yaml found in package path: ${config.packagePath}',
          );
        }
      }
    }

    // Validate base branch (if provided)
    if (config.baseBranch.isEmpty) {
      errors.add('Base branch cannot be empty when specified');
    }

    // Validate output directory
    if (config.outputDir.isEmpty) {
      errors.add('Output directory cannot be empty');
    } else {
      final outputDir = Directory(config.outputDir);
      final parentDir = outputDir.parent;
      if (!await parentDir.exists()) {
        errors.add('Output directory parent does not exist: ${parentDir.path}');
      }
    }

    // Validate output formats
    const validFormats = ['console', 'html', 'json', 'lcov'];
    for (final format in config.outputFormats) {
      if (!validFormats.contains(format)) {
        errors.add(
          'Invalid output format: $format. Valid formats: ${validFormats.join(', ')}',
        );
      }
    }

    // Validate AI configuration
    if (config.aiInsights || config.codeReview) {
      final aiErrors = _validateAiConfig(config.aiConfig);
      errors.addAll(aiErrors);
    }

    return errors;
  }

  @override
  Future<void> saveConfig(SmartCoverageConfig config, String filePath) async {
    final configMap = _configToMap(config);
    final yamlString = _mapToYamlString(configMap);

    final file = File(filePath);
    await file.writeAsString(yamlString);
  }

  @override
  Future<Map<String, dynamic>?> loadYamlConfig(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final yamlDoc = loadYaml(content);

      if (yamlDoc is Map) {
        return Map<String, dynamic>.from(yamlDoc);
      }

      return null;
    } catch (e) {
      throw FormatException(
        'Invalid YAML configuration file: $filePath. Error: $e',
      );
    }
  }

  @override
  Map<String, dynamic> loadEnvConfig() {
    final config = <String, dynamic>{};
    final env = Platform.environment;

    // Map environment variables to configuration keys
    final envMappings = {
      '${envPrefix}PACKAGE_PATH': 'packagePath',
      '${envPrefix}BASE_BRANCH': 'baseBranch',
      '${envPrefix}OUTPUT_DIR': 'outputDir',
      '${envPrefix}SKIP_TESTS': 'skipTests',
      '${envPrefix}AI_INSIGHTS': 'aiInsights',
      '${envPrefix}CODE_REVIEW': 'codeReview',
      '${envPrefix}DARK_MODE': 'darkMode',
      '${envPrefix}OUTPUT_FORMATS': 'outputFormats',
      '${envPrefix}AI_PROVIDER': 'aiConfig.provider',
      '${envPrefix}AI_PROVIDER_TYPE': 'aiConfig.providerType',
      '${envPrefix}AI_API_KEY_ENV': 'aiConfig.apiKeyEnv',
      '${envPrefix}AI_MODEL': 'aiConfig.model',
      '${envPrefix}AI_API_ENDPOINT': 'aiConfig.apiEndpoint',
      '${envPrefix}AI_TIMEOUT': 'aiConfig.timeout',
      '${envPrefix}AI_CLI_COMMAND': 'aiConfig.cliCommand',
      '${envPrefix}AI_CLI_TIMEOUT': 'aiConfig.cliTimeout',
      '${envPrefix}AI_FALLBACK_ENABLED': 'aiConfig.fallbackEnabled',
    };

    for (final entry in envMappings.entries) {
      final envValue = env[entry.key];
      if (envValue != null) {
        _setNestedValue(config, entry.value, _parseEnvValue(envValue));
      }
    }

    return config;
  }

  /// Get default configuration
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'packagePath': '.',
      'baseBranch': null,
      'outputDir': 'coverage_reports',
      'skipTests': false,
      'aiInsights': false,
      'codeReview': false,
      'darkMode': false,
      'outputFormats': ['console'],
      'aiConfig': {
        'provider': 'gemini',
        'providerType': 'auto',
        'apiKeyEnv': null,
        'model': null,
        'apiEndpoint': null,
        'timeout': 30,
        'cliCommand': 'gemini',
        'cliArgs': <String>[],
        'cliTimeout': 60,
        'fallbackEnabled': true,
        'fallbackOrder': ['local', 'api'],
      },
    };
  }

  /// Merge two configuration maps with priority to the second map
  Map<String, dynamic> _mergeConfigs(
    Map<String, dynamic> base,
    Map<String, dynamic> override,
  ) {
    final result = Map<String, dynamic>.from(base);

    for (final entry in override.entries) {
      if (entry.value is Map && result[entry.key] is Map) {
        result[entry.key] = _mergeConfigs(
          Map<String, dynamic>.from(result[entry.key] as Map),
          Map<String, dynamic>.from(entry.value as Map),
        );
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Convert configuration map to SmartCoverageConfig object
  SmartCoverageConfig _mapToConfig(Map<String, dynamic> config) {
    final aiConfigMap = config['aiConfig'] as Map<String, dynamic>? ?? {};

    return SmartCoverageConfig(
      packagePath: config['packagePath'] as String? ?? '.',
      baseBranch: config['baseBranch'] as String? ?? 'main',
      outputDir: config['outputDir'] as String? ?? 'coverage_reports',
      skipTests: config['skipTests'] as bool? ?? false,
      aiInsights: config['aiInsights'] as bool? ?? false,
      codeReview: config['codeReview'] as bool? ?? false,
      darkMode: config['darkMode'] as bool? ?? false,
      outputFormats: _parseOutputFormats(config['outputFormats']),
      aiConfig: AiConfig(
        provider: aiConfigMap['provider'] as String? ?? 'gemini',
        providerType: aiConfigMap['providerType'] as String? ?? 'auto',
        apiKeyEnv: aiConfigMap['apiKeyEnv'] as String?,
        model: aiConfigMap['model'] as String?,
        apiEndpoint: aiConfigMap['apiEndpoint'] as String?,
        timeout: aiConfigMap['timeout'] as int? ?? 30,
        cliCommand: aiConfigMap['cliCommand'] as String? ?? 'gemini',
        cliArgs: _parseStringList(aiConfigMap['cliArgs']) ?? [],
        cliTimeout: aiConfigMap['cliTimeout'] as int? ?? 60,
        fallbackEnabled: aiConfigMap['fallbackEnabled'] as bool? ?? true,
        fallbackOrder:
            _parseStringList(aiConfigMap['fallbackOrder']) ?? ['local', 'api'],
      ),
    );
  }

  /// Convert SmartCoverageConfig to map
  Map<String, dynamic> _configToMap(SmartCoverageConfig config) {
    return {
      'packagePath': config.packagePath,
      'baseBranch': config.baseBranch,
      'outputDir': config.outputDir,
      'skipTests': config.skipTests,
      'aiInsights': config.aiInsights,
      'codeReview': config.codeReview,
      'darkMode': config.darkMode,
      'outputFormats': config.outputFormats,
      'aiConfig': {
        'provider': config.aiConfig.provider,
        'providerType': config.aiConfig.providerType,
        'apiKeyEnv': config.aiConfig.apiKeyEnv,
        'model': config.aiConfig.model,
        'apiEndpoint': config.aiConfig.apiEndpoint,
        'timeout': config.aiConfig.timeout,
        'cliCommand': config.aiConfig.cliCommand,
        'cliArgs': config.aiConfig.cliArgs,
        'cliTimeout': config.aiConfig.cliTimeout,
        'fallbackEnabled': config.aiConfig.fallbackEnabled,
        'fallbackOrder': config.aiConfig.fallbackOrder,
      },
    };
  }

  /// Parse output formats from various input types
  List<String> _parseOutputFormats(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    } else if (value is String) {
      return value.split(',').map((e) => e.trim()).toList();
    }
    return ['console'];
  }

  /// Parse string list from various input types
  List<String>? _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    } else if (value is String) {
      return value.split(',').map((e) => e.trim()).toList();
    }
    return null;
  }

  /// Parse environment variable value
  dynamic _parseEnvValue(String value) {
    // Try to parse as boolean
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;

    // Try to parse as integer
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    // Return as string
    return value;
  }

  /// Set nested value in map using dot notation
  void _setNestedValue(Map<String, dynamic> map, String key, dynamic value) {
    final keys = key.split('.');
    var current = map;

    for (var i = 0; i < keys.length - 1; i++) {
      current[keys[i]] ??= <String, dynamic>{};
      current = current[keys[i]] as Map<String, dynamic>;
    }

    current[keys.last] = value;
  }

  /// Convert map to YAML string
  String _mapToYamlString(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    _writeYamlMap(buffer, map, 0);
    return buffer.toString();
  }

  /// Write YAML map with proper indentation
  void _writeYamlMap(
    StringBuffer buffer,
    Map<String, dynamic> map,
    int indent,
  ) {
    for (final entry in map.entries) {
      buffer.write('  ' * indent);
      buffer.write('${entry.key}:');

      if (entry.value is Map) {
        buffer.writeln();
        _writeYamlMap(buffer, entry.value as Map<String, dynamic>, indent + 1);
      } else if (entry.value is List) {
        buffer.writeln();
        for (final item in entry.value as List) {
          buffer.write('  ' * (indent + 1));
          buffer.writeln('- $item');
        }
      } else {
        buffer.writeln(' ${entry.value}');
      }
    }
  }

  /// Validate AI configuration
  List<String> _validateAiConfig(AiConfig aiConfig) {
    final errors = <String>[];

    // Validate provider
    const validProviders = ['gemini', 'openai', 'claude', 'local'];
    if (!validProviders.contains(aiConfig.provider)) {
      errors.add(
        'Invalid AI provider: ${aiConfig.provider}. Valid providers: ${validProviders.join(', ')}',
      );
    }

    // Validate provider type
    const validProviderTypes = ['api', 'local', 'auto'];
    if (!validProviderTypes.contains(aiConfig.providerType)) {
      errors.add(
        'Invalid AI provider type: ${aiConfig.providerType}. Valid types: ${validProviderTypes.join(', ')}',
      );
    }

    // Validate timeout values
    if (aiConfig.timeout <= 0) {
      errors.add('AI timeout must be positive: ${aiConfig.timeout}');
    }

    if (aiConfig.cliTimeout <= 0) {
      errors.add('AI CLI timeout must be positive: ${aiConfig.cliTimeout}');
    }

    // Validate fallback order
    const validFallbackTypes = ['api', 'local'];
    for (final fallback in aiConfig.fallbackOrder) {
      if (!validFallbackTypes.contains(fallback)) {
        errors.add(
          'Invalid fallback type: $fallback. Valid types: ${validFallbackTypes.join(', ')}',
        );
      }
    }

    return errors;
  }
}
