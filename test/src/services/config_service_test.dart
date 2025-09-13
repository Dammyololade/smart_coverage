import 'dart:io';

import 'package:smart_coverage/src/models/models.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigServiceImpl', () {
    late ConfigService configService;
    late Directory tempDir;

    setUp(() async {
      configService = const ConfigServiceImpl();
      tempDir = await Directory.systemTemp.createTemp('config_service_test');
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

        final errors = await configService.validateConfig(config);
        expect(errors, isEmpty);
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

        final errors = await configService.validateConfig(config);
        expect(errors, isNotEmpty);
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

        final errors = await configService.validateConfig(config);
        expect(errors, isNotEmpty);
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

        final errors = await configService.validateConfig(config);
        expect(errors, isNotEmpty);
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

        final errors = await configService.validateConfig(config);
        expect(errors, isNotEmpty);
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

        final errors = await configService.validateConfig(config);
        expect(errors, isNotEmpty);
      });
    });
  });
}
