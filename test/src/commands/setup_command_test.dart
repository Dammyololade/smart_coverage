import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_coverage/src/commands/setup_command.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:smart_coverage/src/services/config_validator.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockConfigService extends Mock implements ConfigService {}

class _MockConfigValidator extends Mock implements ConfigValidator {}

class _FakeLogger extends Fake implements Logger {}

class _TestCommandRunner extends CommandRunner<int> {
  _TestCommandRunner(SetupCommand command)
      : super('test', 'Test runner') {
    addCommand(command);
  }
}

void main() {
  group('SetupCommand', () {
    late Logger logger;
    late ConfigService configService;
    late ConfigValidator validator;
    late Directory tempDir;

    setUpAll(() {
      registerFallbackValue(_FakeLogger());
      registerFallbackValue(
        const SmartCoverageConfig(
          packagePath: '.',
          baseBranch: 'main',
          outputDir: 'coverage',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: ['console'], // CONSOLE ONLY - no HTML!
          aiConfig: AiConfig(provider: 'gemini'),
        ),
      );
    });

    setUp(() {
      logger = _MockLogger();
      configService = _MockConfigService();
      validator = _MockConfigValidator();
      tempDir = Directory.systemTemp.createTempSync('setup_command_test_');

      // Setup default mock behaviors - prevent any actual I/O
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.detail(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.warn(any())).thenReturn(null);
      when(() => logger.success(any())).thenReturn(null);
      when(() => logger.confirm(any())).thenReturn(true);
      when(() => logger.confirm(any(), defaultValue: any(named: 'defaultValue')))
          .thenReturn(false);
      when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
          .thenAnswer((invocation) {
        final defaultValue = invocation.namedArguments[#defaultValue];
        return defaultValue?.toString() ?? '';
      });
      when(() => logger.chooseOne<String>(
            any(),
            choices: any(named: 'choices'),
            defaultValue: any(named: 'defaultValue'),
          )).thenAnswer((invocation) {
        final defaultValue = invocation.namedArguments[#defaultValue];
        return defaultValue?.toString() ?? 'gemini';
      });

      // Mock to prevent actual file writes
      when(() => configService.saveConfig(any(), any()))
          .thenAnswer((_) async {
            // Do nothing - prevent actual file writes
          });
      when(() => validator.validateAndDisplay(any(), any()))
          .thenAnswer((_) async => true);
      when(() => validator.generateConfigTemplate())
          .thenReturn('# Generated template\noutputFormats: [console]\n');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('has correct name and description', () {
      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      expect(command.name, equals('setup'));
      expect(
        command.description,
        contains('Interactive setup wizard'),
      );
    });

    test('generates template when --template-only flag is used', () async {
      final configPath = '${tempDir.path}/smart_coverage.yaml';

      when(() => validator.generateConfigTemplate())
          .thenReturn('# Template content\noutputFormats: [console]\n');

      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run([
        'setup',
        '--template-only',
        '--output',
        configPath,
      ]);

      expect(result, equals(ExitCode.success.code));
      expect(File(configPath).existsSync(), isTrue);

      final content = await File(configPath).readAsString();
      expect(content, contains('Template content'));
      expect(content, contains('console')); // Verify console output
    });

    test('prompts for overwrite when config file exists', () async {
      final configPath = '${tempDir.path}/smart_coverage.yaml';
      await File(configPath).writeAsString('existing config');

      when(() => logger.confirm(any())).thenReturn(false);

      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run([
        'setup',
        '--template-only',
        '--output',
        configPath,
      ]);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.confirm(any())).called(1);
      verify(() => logger.info('Setup cancelled.')).called(1);
    });

    test('overwrites config file when --force flag is used', () async {
      final configPath = '${tempDir.path}/smart_coverage.yaml';
      await File(configPath).writeAsString('existing config');

      when(() => validator.generateConfigTemplate())
          .thenReturn('# New template\noutputFormats: [console]\n');

      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run([
        'setup',
        '--template-only',
        '--force',
        '--output',
        configPath,
      ]);

      expect(result, equals(ExitCode.success.code));
      // The --force flag bypasses the confirm prompt, so it should never be called
      verifyNever(() => logger.confirm(any()));

      final content = await File(configPath).readAsString();
      expect(content, contains('New template'));
    });

    test('validates configuration is saved with console output only', () async {
      final configPath = '${tempDir.path}/smart_coverage.yaml';

      when(() => validator.generateConfigTemplate())
          .thenReturn('# Config\noutputFormats: [console]\n');

      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      final runner = _TestCommandRunner(command);
      await runner.run([
        'setup',
        '--template-only',
        '--output',
        configPath,
      ]);

      final content = await File(configPath).readAsString();
      // Verify it's console only, not HTML
      expect(content, contains('console'));
      expect(content, isNot(contains('html')));
    });

    test('handles errors during setup gracefully', () async {
      final configPath = '${tempDir.path}/smart_coverage.yaml';

      when(() => validator.generateConfigTemplate())
          .thenThrow(Exception('Template generation failed'));

      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run([
        'setup',
        '--template-only',
        '--output',
        configPath,
      ]);

      expect(result, equals(ExitCode.ioError.code));
      verify(() => logger.err(any())).called(greaterThan(0));
    });

    test('uses custom output path when --output is specified', () async {
      final customPath = '${tempDir.path}/custom/config.yaml';
      final customDir = Directory('${tempDir.path}/custom');
      await customDir.create();

      when(() => validator.generateConfigTemplate())
          .thenReturn('# Custom template\noutputFormats: [console]\n');

      final command = SetupCommand(
        logger: logger,
        configService: configService,
        validator: validator,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run([
        'setup',
        '--template-only',
        '--output',
        customPath,
      ]);

      expect(result, equals(ExitCode.success.code));
      expect(File(customPath).existsSync(), isTrue);

      final content = await File(customPath).readAsString();
      expect(content, contains('console'));
    });

    group('Interactive Setup', () {
      test('performs full interactive setup with AI configuration', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        // Mock user inputs
        when(() => logger.confirm(any())).thenReturn(false); // Don't overwrite initially
        when(() => logger.confirm('🤖 Enable AI-powered insights and code review?'))
            .thenReturn(true);
        when(() => logger.confirm('⚙️  Configure advanced options?', defaultValue: false))
            .thenReturn(false);
        when(() => logger.prompt('📦 Package path (current directory):', defaultValue: '.'))
            .thenReturn('.');
        when(() => logger.prompt('🌿 Base branch for comparison:', defaultValue: any(named: 'defaultValue')))
            .thenReturn('main');
        when(() => logger.prompt('📁 Output directory for reports:', defaultValue: 'coverage/smart_coverage'))
            .thenReturn('coverage/smart_coverage');
        when(() => logger.prompt('Output formats:', defaultValue: 'console html'))
            .thenReturn('console html');
        when(() => logger.chooseOne<String>(
              'Select AI provider:',
              choices: any(named: 'choices'),
              defaultValue: 'gemini',
            )).thenReturn('gemini');
        when(() => logger.chooseOne<String>(
              'Provider type:',
              choices: any(named: 'choices'),
              defaultValue: 'auto',
            )).thenReturn('api');
        when(() => logger.prompt('Environment variable for API key:', defaultValue: 'GEMINI_API_KEY'))
            .thenReturn('GEMINI_API_KEY');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => configService.saveConfig(any(), configPath)).called(1);
        verify(() => logger.success(any())).called(greaterThan(0));
      });

      test('skips AI configuration when user declines', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.confirm('🤖 Enable AI-powered insights and code review?'))
            .thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => configService.saveConfig(any(), configPath)).called(1);
      });

      test('uses --no-ai-setup flag to skip AI configuration', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--no-ai-setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        // Should not prompt for AI configuration
        verifyNever(() => logger.confirm('🤖 Enable AI-powered insights and code review?'));
      });

      test('configures advanced options when requested', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.confirm('⚙️  Configure advanced options?', defaultValue: false))
            .thenReturn(true);
        when(() => logger.confirm('Skip running tests (use existing coverage)?', defaultValue: false))
            .thenReturn(true);
        when(() => logger.confirm('Use dark mode for HTML reports?', defaultValue: true))
            .thenReturn(false);
        when(() => logger.confirm('🤖 Enable AI-powered insights and code review?'))
            .thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.confirm('Skip running tests (use existing coverage)?', defaultValue: false)).called(1);
        verify(() => logger.confirm('Use dark mode for HTML reports?', defaultValue: true)).called(1);
      });

      test('handles validation failure with retry option', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.confirm('Would you like to retry setup?')).thenReturn(false);
        when(() => validator.validateAndDisplay(any(), any()))
            .thenAnswer((_) async => false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.config.code));
        verify(() => logger.err('❌ Configuration validation failed.')).called(1);
        verify(() => logger.confirm('Would you like to retry setup?')).called(1);
      });

      test('selects multiple output formats correctly', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.confirm('🤖 Enable AI-powered insights and code review?'))
            .thenReturn(false);
        when(() => logger.prompt('Output formats:', defaultValue: 'console html'))
            .thenReturn('console html json lcov');
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
      });

      test('warns when API key environment variable is not set', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.confirm('🤖 Enable AI-powered insights and code review?'))
            .thenReturn(true);
        when(() => logger.chooseOne<String>(
              'Select AI provider:',
              choices: any(named: 'choices'),
              defaultValue: 'gemini',
            )).thenReturn('openai');
        when(() => logger.chooseOne<String>(
              'Provider type:',
              choices: any(named: 'choices'),
              defaultValue: 'auto',
            )).thenReturn('api');
        when(() => logger.prompt('Environment variable for API key:', defaultValue: 'OPENAI_API_KEY'))
            .thenReturn('OPENAI_API_KEY');
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.warn(any(that: contains('OPENAI_API_KEY is not set')))).called(1);
        verify(() => logger.info(any(that: contains('export OPENAI_API_KEY')))).called(1);
      });

      test('detects Flutter project correctly', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';
        final pubspecFile = File('${tempDir.path}/pubspec.yaml');
        await pubspecFile.writeAsString('''
name: test_project
version: 1.0.0
flutter:
  sdk: flutter
''');

        // Change to temp directory
        final originalDir = Directory.current;
        Directory.current = tempDir;

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(any(that: contains('Flutter')))).called(greaterThan(0));

        // Restore original directory
        Directory.current = originalDir;
      });

      test('detects Dart project correctly', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';
        final pubspecFile = File('${tempDir.path}/pubspec.yaml');
        await pubspecFile.writeAsString('''
name: test_project
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
''');

        final originalDir = Directory.current;
        Directory.current = tempDir;

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(any(that: contains('Dart')))).called(greaterThan(0));

        Directory.current = originalDir;
      });

      test('handles setup errors gracefully', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenThrow(Exception('User input error'));

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.software.code));
        verify(() => logger.err(any(that: contains('Setup failed')))).called(1);
      });

      test('configures AI with local provider type', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.confirm('🤖 Enable AI-powered insights and code review?'))
            .thenReturn(true);
        when(() => logger.chooseOne<String>(
              'Select AI provider:',
              choices: any(named: 'choices'),
              defaultValue: 'gemini',
            )).thenReturn('claude');
        when(() => logger.chooseOne<String>(
              'Provider type:',
              choices: any(named: 'choices'),
              defaultValue: 'auto',
            )).thenReturn('local');
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        // Should not prompt for API key when using local provider
        verifyNever(() => logger.prompt('Environment variable for API key:', defaultValue: any(named: 'defaultValue')));
      });

      test('displays next steps after successful setup', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run([
          'setup',
          '--output',
          configPath,
        ]);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(any(that: contains('Next steps')))).called(1);
        verify(() => logger.info(any(that: contains('smart_coverage analyze')))).called(greaterThan(0));
      });
    });

    group('Project Detection', () {
      test('detects when tests directory exists', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';
        final pubspecFile = File('${tempDir.path}/pubspec.yaml');
        await pubspecFile.writeAsString('name: test_project\n');

        final testDir = Directory('${tempDir.path}/test');
        await testDir.create();

        final originalDir = Directory.current;
        Directory.current = tempDir;

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        await runner.run(['setup', '--output', configPath]);

        Directory.current = originalDir;
      });

      test('detects when coverage file exists', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';
        final pubspecFile = File('${tempDir.path}/pubspec.yaml');
        await pubspecFile.writeAsString('name: test_project\n');

        final coverageDir = Directory('${tempDir.path}/coverage');
        await coverageDir.create();
        final lcovFile = File('${tempDir.path}/coverage/lcov.info');
        await lcovFile.writeAsString('coverage data');

        final originalDir = Directory.current;
        Directory.current = tempDir;

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        await runner.run(['setup', '--output', configPath]);

        Directory.current = originalDir;
      });

      test('handles unknown project type gracefully', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        final originalDir = Directory.current;
        Directory.current = tempDir;

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run(['setup', '--output', configPath]);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(any(that: contains('Unknown')))).called(greaterThan(0));

        Directory.current = originalDir;
      });
    });

    group('Edge Cases', () {
      test('handles empty output formats gracefully', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt('Output formats:', defaultValue: 'console html'))
            .thenReturn('   '); // Empty with spaces
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run(['setup', '--output', configPath]);

        expect(result, equals(ExitCode.success.code));
      });

      test('handles very long package paths', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';
        final longPath = '/very/long/path/${'directory/' * 20}package';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt('📦 Package path (current directory):', defaultValue: '.'))
            .thenReturn(longPath);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run(['setup', '--output', configPath]);

        expect(result, equals(ExitCode.success.code));
      });

      test('handles save config errors', () async {
        final configPath = '${tempDir.path}/smart_coverage.yaml';

        when(() => logger.confirm(any())).thenReturn(false);
        when(() => logger.prompt(any(), defaultValue: any(named: 'defaultValue')))
            .thenAnswer((inv) => inv.namedArguments[#defaultValue]?.toString() ?? '.');
        when(() => configService.saveConfig(any(), any()))
            .thenThrow(Exception('Failed to write file'));

        final command = SetupCommand(
          logger: logger,
          configService: configService,
          validator: validator,
        );

        final runner = _TestCommandRunner(command);
        final result = await runner.run(['setup', '--output', configPath]);

        expect(result, equals(ExitCode.software.code));
        verify(() => logger.err(any(that: contains('Setup failed')))).called(1);
      });
    });
  });
}
