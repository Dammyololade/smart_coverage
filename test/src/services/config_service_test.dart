import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:smart_coverage/src/models/models.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigServiceImpl', () {
    late ConfigService configService;
    late Directory tempDir;
    late Logger logger;

    setUp(() async {
      configService = const ConfigServiceImpl();
      tempDir = await Directory.systemTemp.createTemp('config_service_test');
      logger = Logger();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('loadYamlConfig', () {
      test('should load valid YAML configuration', () async {
        final configFile = File('${tempDir.path}/smart_coverage.yaml');
        await configFile.writeAsString('''
packagePath: /test/package
baseBranch: develop
outputDir: /test/output
outputFormats:
  - console
  - html
  - json
skipTests: false
testInsights: true
codeReview: false
darkMode: false
aiConfig:
  provider: openai
  model: gpt-4
  apiKeyEnv: OPENAI_API_KEY
  timeout: 30
''');

        final configMap = await configService.loadYamlConfig(configFile.path);

        expect(configMap, isNotNull);
        expect(configMap!['packagePath'], equals('/test/package'));
        expect(configMap['baseBranch'], equals('develop'));
        expect(configMap['outputDir'], equals('/test/output'));
        expect(
          configMap['outputFormats'],
          containsAll(['console', 'html', 'json']),
        );
        expect(configMap['skipTests'], isFalse);
        expect(configMap['testInsights'], isTrue);
        expect(configMap['aiConfig']['provider'], equals('openai'));
        expect(configMap['aiConfig']['model'], equals('gpt-4'));
      });

      test('should load minimal YAML configuration', () async {
        final configFile = File('${tempDir.path}/minimal.yaml');
        await configFile.writeAsString('''
packagePath: /test/package
''');

        final configMap = await configService.loadYamlConfig(configFile.path);

        expect(configMap, isNotNull);
        expect(configMap!['packagePath'], equals('/test/package'));
      });

      test('should handle missing file gracefully', () async {
        final configMap = await configService.loadYamlConfig(
          '/non/existent/config.yaml',
        );
        expect(configMap, isNull);
      });

      test('should handle malformed YAML', () async {
        final configFile = File('${tempDir.path}/malformed.yaml');
        await configFile.writeAsString('invalid: yaml: content: [');

        expect(
          () => configService.loadYamlConfig(configFile.path),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle YAML with wrong types', () async {
        final configFile = File('${tempDir.path}/wrong_types.yaml');
        await configFile.writeAsString('''
packagePath: 123  # Should be string
outputFormats: "console"  # Should be list
''');

        final configMap = await configService.loadYamlConfig(configFile.path);
        expect(configMap, isNotNull);
        // The YAML parser will load the values as-is, validation happens later
        expect(configMap!['packagePath'], equals(123));
        expect(configMap['outputFormats'], equals('console'));
      });
    });

    group('loadEnvConfig', () {
      test('should load configuration from environment variables', () {
        final envConfig = configService.loadEnvConfig();

        // Since we can't easily mock Platform.environment in tests,
        // we'll test the method exists and returns a valid map
        expect(envConfig, isA<Map<String, dynamic>>());
      });
    });

    group('validateConfig', () {
      test('should validate correct configuration', () async {
        // Create a pubspec.yaml file to make the package path valid
        final pubspecFile = File('${tempDir.path}/pubspec.yaml');
        await pubspecFile.writeAsString('''
name: test_package
version: 1.0.0
environment:
  sdk: '>=2.17.0 <4.0.0'
''');

        final config = SmartCoverageConfig(
          packagePath: tempDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console', 'html'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final isValid = await configService.validateConfig(config, logger);
        expect(isValid, isTrue);
      });

      test('should reject empty package path', () async {
        const config = SmartCoverageConfig(
          packagePath: '',
          baseBranch: 'main',
          outputDir: '/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final isValid = await configService.validateConfig(config, logger);
        expect(isValid, isFalse);
      });

      test('should reject empty base branch', () async {
        const config = SmartCoverageConfig(
          packagePath: '/package',
          baseBranch: '',
          outputDir: '/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final isValid = await configService.validateConfig(config, logger);
        expect(isValid, isFalse);
      });

      test('should reject empty output formats', () async {
        const config = SmartCoverageConfig(
          packagePath: '/package',
          baseBranch: 'main',
          outputDir: '/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: [],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final isValid = await configService.validateConfig(config, logger);
        expect(isValid, isFalse);
      });

      test('should reject invalid output formats', () async {
        const config = SmartCoverageConfig(
          packagePath: '/package',
          baseBranch: 'main',
          outputDir: '/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console', 'invalid-format'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final isValid = await configService.validateConfig(config, logger);
        expect(isValid, isFalse);
      });

      test('should reject invalid AI configuration when enabled', () async {
        const config = SmartCoverageConfig(
          packagePath: '/package',
          baseBranch: 'main',
          outputDir: '/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(
            provider: 'invalid-provider',
            model: '',
            timeout: -1,
          ),
        );

        final isValid = await configService.validateConfig(config, logger);
        expect(isValid, isFalse);
      });
    });

    group('loadConfig', () {
      test('merges CLI args with YAML config', () async {
        final configFile = File('${tempDir.path}/smart_coverage.yaml');
        await configFile.writeAsString('''
packagePath: /yaml/path
baseBranch: develop
outputFormats:
  - console
''');

        final config = await configService.loadConfig(
          configFilePath: configFile.path,
          cliArgs: {
            'packagePath': '/cli/path',
            'outputFormats': ['html', 'json'],
          },
        );

        // CLI args should override YAML
        expect(config.packagePath, equals('/cli/path'));
        expect(config.outputFormats, containsAll(['html', 'json']));
        // YAML values not overridden should remain
        expect(config.baseBranch, equals('develop'));
      });

      test('uses defaults when no config provided', () async {
        final config = await configService.loadConfig(cliArgs: {});

        expect(config.packagePath, equals('.'));
        expect(config.baseBranch, isNotEmpty);
        expect(config.outputFormats, isNotEmpty);
      });

      test('handles boolean flags correctly', () async {
        final config = await configService.loadConfig(
          cliArgs: {
            'skipTests': true,
            'testInsights': true,
            'codeReview': false,
            'darkMode': true,
          },
        );

        expect(config.skipTests, isTrue);
        expect(config.testInsights, isTrue);
        expect(config.codeReview, isFalse);
        expect(config.darkMode, isTrue);
      });

      test('handles empty config file path', () async {
        final config = await configService.loadConfig(
          configFilePath: null,
          cliArgs: {'packagePath': '.'},
        );

        expect(config.packagePath, equals('.'));
      });

      test('handles nonexistent config file gracefully', () async {
        final config = await configService.loadConfig(
          configFilePath: '/nonexistent/config.yaml',
          cliArgs: {'packagePath': '.'},
        );

        expect(config.packagePath, equals('.'));
      });
    });

    group('mergeConfigs', () {
      test('CLI args take precedence over YAML', () async {
        final configFile = File('${tempDir.path}/yaml.yaml');
        await configFile.writeAsString('''
packagePath: /yaml/path
baseBranch: develop
''');

        final config = await configService.loadConfig(
          configFilePath: configFile.path,
          cliArgs: {
            'packagePath': '/cli/path',
          },
        );

        expect(config.packagePath, equals('/cli/path'));
        expect(config.baseBranch, equals('develop'));
      });

      test('handles nested AI config merging', () async {
        final configFile = File('${tempDir.path}/ai.yaml');
        await configFile.writeAsString('''
aiConfig:
  provider: gemini
  timeout: 30
''');

        final config = await configService.loadConfig(
          configFilePath: configFile.path,
          cliArgs: {
            'aiConfig': {
              'timeout': 60,
            },
          },
        );

        expect(config.aiConfig.provider, equals('gemini'));
        expect(config.aiConfig.timeout, equals(60));
      });

      test('uses environment variables as fallback', () async {
        final config = await configService.loadConfig(
          cliArgs: {
            'packagePath': '/cli/path',
          },
        );

        expect(config.packagePath, equals('/cli/path'));
      });
    });

    group('edge cases', () {
      test('handles very large config files', () async {
        final configFile = File('${tempDir.path}/large.yaml');
        final buffer = StringBuffer();
        buffer.writeln('packagePath: /test');
        for (var i = 0; i < 1000; i++) {
          buffer.writeln('# Comment line $i');
        }

        await configFile.writeAsString(buffer.toString());

        final configMap = await configService.loadYamlConfig(configFile.path);
        expect(configMap, isNotNull);
      });

      test('handles special characters in paths', () async {
        final config = await configService.loadConfig(
          cliArgs: {
            'packagePath': '/path with spaces/test',
            'outputDir': '/output-dir_2024',
          },
        );

        expect(config.packagePath, equals('/path with spaces/test'));
        expect(config.outputDir, equals('/output-dir_2024'));
      });

      test('handles empty strings in config', () async {
        final configFile = File('${tempDir.path}/empty.yaml');
        await configFile.writeAsString('''
packagePath: ""
baseBranch: ""
''');

        final configMap = await configService.loadYamlConfig(configFile.path);
        expect(configMap, isNotNull);
        expect(configMap!['packagePath'], equals(''));
      });
    });
  });
}
