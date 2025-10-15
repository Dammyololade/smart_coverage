import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/config_validator.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('ConfigValidatorImpl', () {
    late ConfigValidatorImpl validator;
    late Directory tempDir;
    late Logger logger;

    setUp(() {
      validator = const ConfigValidatorImpl();
      logger = _MockLogger();
      tempDir = Directory.systemTemp.createTempSync('config_validator_test_');

      // Setup logger mocks
      when(() => logger.success(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.warn(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('validateConfig', () {
      test('validates valid configuration successfully', () async {
        // Create a valid project structure
        final projectDir = Directory('${tempDir.path}/valid_project');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();
        await Directory('${projectDir.path}/test').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console', 'html'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('detects empty package path', () async {
        final config = SmartCoverageConfig(
          packagePath: '',
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(result.errors.length, greaterThan(0));
        expect(
          result.errors.any((e) => e.field == 'packagePath' && e.message.contains('cannot be empty')),
          isTrue,
        );
      });

      test('detects non-existent package directory', () async {
        final config = SmartCoverageConfig(
          packagePath: '${tempDir.path}/nonexistent',
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'packagePath' && e.message.contains('does not exist')),
          isTrue,
        );
      });

      test('detects missing pubspec.yaml', () async {
        final projectDir = Directory('${tempDir.path}/no_pubspec');
        await projectDir.create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'packagePath' && e.message.contains('pubspec.yaml')),
          isTrue,
        );
      });

      test('warns about missing lib directory', () async {
        final projectDir = Directory('${tempDir.path}/no_lib');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.warnings.any((w) => w.field == 'packagePath' && w.message.contains('lib directory')),
          isTrue,
        );
      });

      test('suggests creating test directory', () async {
        final projectDir = Directory('${tempDir.path}/no_test');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.suggestions.any((s) => s.field == 'packagePath' && s.message.contains('test directory')),
          isTrue,
        );
      });

      test('warns about empty base branch', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: '',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.warnings.any((w) => w.field == 'baseBranch' && w.message.contains('empty')),
          isTrue,
        );
      });

      test('detects empty output directory', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'outputDir' && e.message.contains('cannot be empty')),
          isTrue,
        );
      });

      test('warns about empty output formats', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const [],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.warnings.any((w) => w.field == 'outputFormats' && w.message.contains('No output formats')),
          isTrue,
        );
      });

      test('detects invalid output format', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['invalid_format'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'outputFormats' && e.message.contains('Invalid output format')),
          isTrue,
        );
      });

      test('suggests adding console format', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['html'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.suggestions.any((s) => s.field == 'outputFormats' && s.message.contains('Console output format not included')),
          isTrue,
        );
      });

      test('suggests adding HTML format when only console is specified', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.suggestions.any((s) => s.field == 'outputFormats' && s.message.contains('Only console output')),
          isTrue,
        );
      });

      test('detects invalid AI provider', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'invalid_provider'),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'aiConfig.provider' && e.message.contains('Invalid AI provider')),
          isTrue,
        );
      });

      test('detects invalid AI provider type', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(
            provider: 'gemini',
            providerType: 'invalid_type',
          ),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'aiConfig.providerType'),
          isTrue,
        );
      });

      test('warns about missing API key environment variable', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(
            provider: 'gemini',
            providerType: 'api',
          ),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.warnings.any((w) => w.field == 'aiConfig.apiKeyEnv'),
          isTrue,
        );
      });

      test('detects negative timeout', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(
            provider: 'gemini',
            timeout: -1,
          ),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'aiConfig.timeout' && e.message.contains('must be positive')),
          isTrue,
        );
      });

      test('warns about very low timeout', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(
            provider: 'gemini',
            timeout: 5,
          ),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.warnings.any((w) => w.field == 'aiConfig.timeout' && w.message.contains('very low')),
          isTrue,
        );
      });

      test('detects negative CLI timeout', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(
            provider: 'gemini',
            cliTimeout: -1,
          ),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'aiConfig.cliTimeout'),
          isTrue,
        );
      });

      test('detects invalid fallback order', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(
            provider: 'gemini',
            fallbackOrder: ['invalid'],
          ),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'aiConfig.fallbackOrder'),
          isTrue,
        );
      });

      test('detects AI features enabled without provider', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: ''),
        );

        final result = await validator.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.field == 'aiConfig' && e.message.contains('AI features enabled')),
          isTrue,
        );
      });

      test('suggests enabling AI features when provider is configured', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);

        expect(
          result.suggestions.any((s) => s.message.contains('AI provider configured but AI features disabled')),
          isTrue,
        );
      });
    });

    group('validateAndDisplay', () {

      test('displays errors for invalid config', () async {
        final config = SmartCoverageConfig(
          packagePath: '',
          baseBranch: 'main',
          outputDir: '',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['invalid'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final isValid = await validator.validateAndDisplay(config, logger);

        expect(isValid, isFalse);
        verify(() => logger.err(any(that: contains('Configuration Validation')))).called(greaterThan(0));
      });

      test('displays warnings', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        await validator.validateAndDisplay(config, logger);

        verify(() => logger.warn(any())).called(greaterThan(0));
      });

      test('displays suggestions', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        await validator.validateAndDisplay(config, logger);

        verify(() => logger.info(any())).called(greaterThan(0));
      });
    });

    group('generateConfigTemplate', () {
      test('generates valid config template', () {
        final template = validator.generateConfigTemplate();

        expect(template, contains('Smart Coverage Configuration'));
        expect(template, contains('packagePath:'));
        expect(template, contains('baseBranch:'));
        expect(template, contains('outputDir:'));
        expect(template, contains('outputFormats:'));
        expect(template, contains('aiConfig:'));
      });
    });

    group('suggestFixes', () {
      test('suggests creating missing directory', () async {
        final config = SmartCoverageConfig(
          packagePath: '${tempDir.path}/nonexistent',
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);
        final fixes = validator.suggestFixes(result);

        expect(fixes, isNotEmpty);
        expect(
          fixes.any((f) => f.contains('Create the package directory')),
          isTrue,
        );
      });

      test('suggests creating pubspec.yaml', () async {
        final projectDir = Directory('${tempDir.path}/no_pubspec');
        await projectDir.create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'gemini'),
        );

        final result = await validator.validateConfig(config);
        final fixes = validator.suggestFixes(result);

        expect(
          fixes.any((f) => f.contains('dart create') || f.contains('flutter create')),
          isTrue,
        );
      });

      test('suggests AI configuration setup', () async {
        final projectDir = Directory('${tempDir.path}/valid');
        await projectDir.create();
        await File('${projectDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${projectDir.path}/lib').create();

        final config = SmartCoverageConfig(
          packagePath: projectDir.path,
          baseBranch: 'main',
          outputDir: '${tempDir.path}/output',
          skipTests: false,
          testInsights: true,
          codeReview: false,
          darkMode: true,
          outputFormats: const ['console'],
          aiConfig: const AiConfig(provider: 'invalid'),
        );

        final result = await validator.validateConfig(config);
        final fixes = validator.suggestFixes(result);

        expect(
          fixes.any((f) => f.contains('smart_coverage setup')),
          isTrue,
        );
      });
    });

    group('ConfigValidationError', () {
      test('toString includes all fields', () {
        const error = ConfigValidationError(
          field: 'test',
          message: 'Test error',
          severity: ConfigValidationSeverity.error,
          suggestion: 'Fix it',
          example: 'example: value',
          documentation: 'https://docs.example.com',
        );

        final str = error.toString();
        expect(str, contains('ERROR'));
        expect(str, contains('Test error'));
        expect(str, contains('Suggestion: Fix it'));
        expect(str, contains('Example: example: value'));
        expect(str, contains('Documentation: https://docs.example.com'));
      });

      test('toString without optional fields', () {
        const error = ConfigValidationError(
          field: 'test',
          message: 'Test error',
          severity: ConfigValidationSeverity.warning,
        );

        final str = error.toString();
        expect(str, contains('WARNING'));
        expect(str, contains('Test error'));
        expect(str, isNot(contains('Suggestion')));
        expect(str, isNot(contains('Example')));
      });
    });

    group('ConfigValidationResult', () {
      test('allIssues combines all lists', () {
        const result = ConfigValidationResult(
          isValid: false,
          errors: [
            ConfigValidationError(
              field: 'f1',
              message: 'error',
              severity: ConfigValidationSeverity.error,
            ),
          ],
          warnings: [
            ConfigValidationError(
              field: 'f2',
              message: 'warning',
              severity: ConfigValidationSeverity.warning,
            ),
          ],
          suggestions: [
            ConfigValidationError(
              field: 'f3',
              message: 'info',
              severity: ConfigValidationSeverity.info,
            ),
          ],
        );

        expect(result.allIssues.length, equals(3));
        expect(result.hasIssues, isTrue);
      });

      test('hasIssues returns false when empty', () {
        const result = ConfigValidationResult(
          isValid: true,
          errors: [],
          warnings: [],
          suggestions: [],
        );

        expect(result.hasIssues, isFalse);
      });
    });
  });
}

